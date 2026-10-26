import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

/// Closes native screens the app is presenting when it goes to the background
/// with the lock on.
///
/// The lock is drawn by Flutter, inside the Flutter view controller. Anything
/// that controller *presents* — the iOS share sheet, an in-app Safari page —
/// sits above it, and iOS leaves those open across a trip to the background.
/// Without this, someone could reopen the app, cancel Face ID, and use a share
/// sheet left open on top of the lock to copy or send the owner's reaction
/// history. Closed only while the lock is on: with it off there is nothing to
/// protect, and losing a half-finished share would just be an annoyance.
///
/// This listens for the background notification rather than overriding the
/// scene delegate's callback. FlutterSceneDelegate implements that callback
/// without declaring it, so a Swift override would silently replace Flutter's
/// own handling — the very handling that tells Dart the app went away, which is
/// what puts the lock back up.
enum PrivacyBridge {

  static let channelName = "fly_allergy_safe/privacy"

  /// Mirrors AppState.lockIsEnabled. Set from Dart whenever it may change, so
  /// it is already right when iOS sends the app to the background — by the
  /// time Dart hears about that, the snapshot may have been taken.
  private static var lockActive = false

  private static var observer: NSObjectProtocol?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setLockActive":
        lockActive = (call.arguments as? Bool) ?? false
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    guard observer == nil else { return }
    // queue: nil runs the block synchronously on the posting thread — the main
    // thread, for this notification. Passing .main would instead queue it for a
    // later turn of the run loop, possibly after iOS has taken the
    // app-switcher snapshot with the share sheet still in it.
    observer = NotificationCenter.default.addObserver(
      forName: UIScene.didEnterBackgroundNotification,
      object: nil,
      queue: nil
    ) { note in
      guard lockActive, let scene = note.object as? UIWindowScene else { return }
      for window in scene.windows {
        // Closes the presented screen and everything it presented in turn.
        window.rootViewController?.presentedViewController?.dismiss(animated: false)
      }
    }
  }
}
