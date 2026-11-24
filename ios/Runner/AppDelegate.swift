import Flutter
import GoogleMaps
import UIKit
import Darwin
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var relayDiscovery: OrbitRelayDiscovery?
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
