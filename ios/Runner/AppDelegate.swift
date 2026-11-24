import Flutter
import GoogleMaps
import UIKit
import Darwin
import AVFoundation
import AudioToolbox
import StoreKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var relayDiscovery: OrbitRelayDiscovery?
  private var billing: OrbitStoreBilling?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Key is injected from ignored ios/Flutter/GoogleMapsSecrets.xcconfig.
    if let key = Bundle.main.object(forInfoDictionaryKey: "OrbitGoogleMapsApiKey")
        as? String,
       !key.isEmpty, !key.contains("$("),
       key != "NO_GOOGLE_MAPS_IOS_KEY_CONFIGURED" {
      GMSServices.provideAPIKey(key)
    }
    WorkmanagerPlugin.registerLaunchHandlers()
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OrbitRelayDiscovery") {
      relayDiscovery = OrbitRelayDiscovery(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OrbitStoreBilling") {
      billing = OrbitStoreBilling(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OrbitCaptureInspection") {
      let channel = FlutterMethodChannel(name: "orbit/capture_inspection", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "inspect" else { result(FlutterMethodNotImplemented); return }
        guard let args = call.arguments as? [String:Any], let path = args["path"] as? String else {
          result(FlutterError(code: "invalid", message: "Capture unavailable", details: nil)); return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let metadata = inspectOrbitCapture(path)
          DispatchQueue.main.async {
            if let metadata = metadata { result(metadata) }
            else { result(FlutterError(code: "invalid", message: "Capture metadata unavailable", details: nil)) }
          }
        }
      }
    }
  }
}


// Foreground-only Bonjour. Random service name and TCP port only.
private final class OrbitRelayDiscovery: NSObject, NetServiceDelegate, NetServiceBrowserDelegate {
  private var channel: FlutterMethodChannel
  private var published: NetService?
  private var browser: NetServiceBrowser?
  private var resolving: [String: NetService] = [:]
  private var peers: [String: [String: Any]] = [:]
  private var ownName = ""
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "orbit/relay_discovery", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(FlutterError(code: "unavailable", message: nil, details: nil)); return }
      switch call.method {
      case "start":
        guard let args = call.arguments as? [String: Any],
              let name = args["name"] as? String,
              name.range(of: "^o-[a-f0-9]{24}$", options: .regularExpression) != nil,
              let port = args["port"] as? Int, (1024...65535).contains(port) else {
          result(FlutterError(code: "invalid", message: "Invalid Relay service", details: nil)); return
        }
        self.start(name: name, port: port); result(nil)
      case "peers": result(Array(self.peers.values.prefix(24)))
      case "stop": self.stop(); result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
    NotificationCenter.default.addObserver(self, selector: #selector(didBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
  }
  deinit { NotificationCenter.default.removeObserver(self); stop(); channel.setMethodCallHandler(nil) }
  private func start(name: String, port: Int) {
    stop()
    ownName = name
    let service = NetService(domain: "local.", type: "_orbitrelay._tcp.", name: name, port: Int32(port))
    service.delegate = self; published = service; service.publish()
    let scan = NetServiceBrowser()
    scan.delegate = self; browser = scan
    scan.searchForServices(ofType: "_orbitrelay._tcp.", inDomain: "local.")
  }
  @objc private func didBackground(_ notification: Notification) { stop() }
  private func stop() {
    published?.stop(); published = nil
    browser?.stop(); browser = nil
    for service in resolving.values { service.stop() }
    resolving.removeAll(); peers.removeAll(); ownName = ""
  }
  func netServiceDidPublish(_ sender: NetService) { if sender === published { ownName = sender.name } }
  func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) { if sender === published { stop() } }
  func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
    guard browser === self.browser, service.name != ownName, service.name.hasPrefix("o-"),
          resolving.count < 24, resolving[service.name] == nil else { return }
    resolving[service.name] = service; service.delegate = self; service.resolve(withTimeout: 4)
  }
  func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
    guard browser === self.browser else { return }
    resolving.removeValue(forKey: service.name)?.stop(); peers.removeValue(forKey: service.name)
  }
  func netServiceDidResolveAddress(_ sender: NetService) {
    guard resolving[sender.name] === sender, sender.name != ownName, sender.port > 0 else { return }
    for address in sender.addresses ?? [] {
      let host: String? = address.withUnsafeBytes { raw in
        guard let ptr = raw.baseAddress?.assumingMemoryBound(to: sockaddr.self),
              address.count >= MemoryLayout<sockaddr>.size else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let bufferSize = socklen_t(buffer.count)
        let code = getnameinfo(ptr, socklen_t(address.count), &buffer, bufferSize, nil, 0, NI_NUMERICHOST)
        return code == 0 ? String(cString: buffer) : nil
      }
      if let host = host, !host.contains(":") {
        peers[sender.name] = ["host": host, "port": sender.port]; break
      }
    }
    resolving.removeValue(forKey: sender.name)
  }
  func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) { resolving.removeValue(forKey: sender.name) }
}

private func inspectOrbitCapture(_ path: String) -> [String:Any]? {
  let url = URL(fileURLWithPath:path).resolvingSymlinksInPath()
  let roots = [NSTemporaryDirectory(),NSHomeDirectory()+"/Library/Caches",NSHomeDirectory()+"/Library/Application Support",NSHomeDirectory()+"/Documents"]
    .map { URL(fileURLWithPath:$0).resolvingSymlinksInPath().path }
  guard roots.contains(where:{ url.path.hasPrefix($0.hasSuffix("/") ? $0 : $0+"/") }),
        let size = try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize,
        size > 0, size <= 524288000 else { return nil }
  let asset = AVURLAsset(url:url)
  let seconds = CMTimeGetSeconds(asset.duration)
  guard seconds.isFinite, seconds > 0, seconds <= 60 else { return nil }
  let audio = asset.tracks(withMediaType:.audio)
  let video = asset.tracks(withMediaType:.video)
  let metadata = asset.commonMetadata + asset.metadata + asset.availableMetadataFormats.flatMap { asset.metadata(forFormat:$0) }
  let hasLocation = metadata.contains { item in
    let key = ((item.identifier?.rawValue ?? "")+" "+(item.commonKey?.rawValue ?? "")+" "+String(describing:item.key)).lowercased()
    return key.contains("location") || key.contains("iso6709") || key.contains("gps")
  }
  var out:[String:Any] = ["duration_ms":Int((seconds*1000).rounded(.up)),
    "location_metadata":hasLocation,"audio_tracks":audio.count,"video_tracks":video.count]
  if let track=audio.first, let raw=track.formatDescriptions.first {
    let desc = raw as! CMAudioFormatDescription
    if let asbd=CMAudioFormatDescriptionGetStreamBasicDescription(desc) {
      out["audio_aac_lc"] = asbd.pointee.mFormatID == kAudioFormatMPEG4AAC
      out["audio_channels"] = Int(asbd.pointee.mChannelsPerFrame)
      out["audio_bps"] = Double(track.estimatedDataRate)
    }
  }
  if let track=video.first, let raw=track.formatDescriptions.first {
    let desc=raw as! CMVideoFormatDescription
    let dimensions=CMVideoFormatDescriptionGetDimensions(desc)
    out["video_h264"] = CMFormatDescriptionGetMediaSubType(desc) == kCMVideoCodecType_H264
    out["width"]=Int(dimensions.width);out["height"]=Int(dimensions.height)
    out["fps"]=Double(track.nominalFrameRate);out["video_bps"]=Double(track.estimatedDataRate)
  }
  return out
}


// StoreKit2 returns signed JWS to Laravel. No local entitlement or receipt
// persistence. Unfinished transactions remain recoverable across restarts.
@available(iOS 15.0, *)
private final class OrbitStoreBilling {
  private let channel: FlutterMethodChannel
  private var busy = false
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name:"orbit/billing",binaryMessenger:messenger)
    channel.setMethodCallHandler { [weak self] call,result in
      #if DEBUG
      guard let self = self else { result(FlutterError(code:"unavailable",message:"Store unavailable",details:nil)); return }
      Task { @MainActor in await self.handle(call,result) }
      #else
      result(FlutterError(code:"disabled",message:"Sandbox billing disabled",details:nil))
      #endif
    }
  }
  @MainActor private func handle(_ call:FlutterMethodCall,_ result:@escaping FlutterResult) async {
    guard !busy else {result(FlutterError(code:"busy",message:"Store busy",details:nil));return}
    busy=true;defer{busy=false}
    let args=call.arguments as? [String:Any] ?? [:]
    do {
      switch call.method {
      case "products":
        let mappings=args["mappings"] as? [[String:Any]] ?? []
        guard mappings.count<=16 else {throw BillingError.invalid}
        let ids=mappings.compactMap{$0["product_id"] as? String}
        let products=try await Product.products(for:ids)
        let rows:[[String:Any]]=mappings.compactMap { mapping in
          guard let id=mapping["product_id"] as? String, let product=products.first(where:{$0.id==id}),self.monthly(product) else{return nil}
          return ["id":mapping["id"] ?? NSNull(),"product_id":id,"base_plan_id":NSNull(),"price":product.displayPrice]
        }
        result(rows)
      case "purchase":
        guard args["environment"] as? String=="sandbox",let id=args["product_id"] as? String,
              let binding=args["account_binding"] as? String,let token=UUID(uuidString:binding) else {throw BillingError.invalid}
        // Never launch against a currently active store subscription.
        for await value in StoreKit.Transaction.currentEntitlements {
          if case .verified(let tx)=value,tx.productType == .autoRenewable {throw BillingError.invalid}
        }
        guard let product=try await Product.products(for:[id]).first,monthly(product) else {throw BillingError.invalid}
        switch try await product.purchase(options:[.appAccountToken(token)]) {
        case .success(let verification):
          guard case .verified(let tx)=verification,tx.appAccountToken==token else {throw BillingError.invalid}
          if #available(iOS 16.0, *) {guard tx.environment == .sandbox else {throw BillingError.invalid}}
          else {throw BillingError.invalid}
          result("purchased")
        case .pending: result("pending")
        case .userCancelled: result("cancelled")
        @unknown default: throw BillingError.invalid
        }
      case "recover":
        if args["restore"] as? Bool==true {try await AppStore.sync()}
        var rows:[[String:Any]]=[]
        var seen=Set<UInt64>()
        for await item in StoreKit.Transaction.unfinished {
          if let row=record(item,&seen){rows.append(row)}
          if rows.count>64{throw BillingError.invalid}
        }
        for await item in StoreKit.Transaction.currentEntitlements {
          if let row=record(item,&seen){rows.append(row)}
          if rows.count>64{throw BillingError.invalid}
        }
        result(rows)
      case "finish":
        guard let proof=args["proof"] as? String else {throw BillingError.invalid}
        for await item in StoreKit.Transaction.unfinished {
          if item.jwsRepresentation==proof,case .verified(let tx)=item {
            if #available(iOS 16.0, *),tx.environment == .sandbox {await tx.finish()}
            else {throw BillingError.invalid}
            break
          }
        }
        result(nil)
      case "manage":
        guard let scene=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).first(where:{$0.activationState == .foregroundActive}) else {throw BillingError.invalid}
        try await AppStore.showManageSubscriptions(in:scene);result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }catch{result(FlutterError(code:"unavailable",message:"Store operation unavailable; restore purchases to retry",details:nil))}
  }
  private enum BillingError:Error{case invalid}
  private func monthly(_ product:Product)->Bool{
    guard product.type == .autoRenewable,let period=product.subscription?.subscriptionPeriod else{return false}
    return period.unit == .month && period.value==1
  }
  private func record(_ value:VerificationResult<StoreKit.Transaction>,_ seen:inout Set<UInt64>)->[String:Any]?{
    guard case .verified(let tx)=value,tx.productType == .autoRenewable,let binding=tx.appAccountToken else{return nil}
    guard #available(iOS 16.0, *),tx.environment == .sandbox else{return nil}
    guard seen.insert(tx.id).inserted else{return nil}
    return ["proof":value.jwsRepresentation,"product_id":tx.productID,"binding":binding.uuidString.lowercased(),"state":"purchased"]
  }
}
