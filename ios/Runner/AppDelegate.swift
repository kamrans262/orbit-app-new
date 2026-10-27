import Flutter
import GoogleMaps
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
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
  }
}
