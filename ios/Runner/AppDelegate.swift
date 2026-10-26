import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FoundationModelsBridge.register(with: engineBridge.applicationRegistrar.messenger())
    PrivacyBridge.register(with: engineBridge.applicationRegistrar.messenger())
    SpeechBridge.register(with: engineBridge.applicationRegistrar.messenger())
    IntentBridge.register(with: engineBridge.applicationRegistrar.messenger())
  }
}
