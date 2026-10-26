import AppIntents
import Flutter

/// "Hey Siri, Fly Allergy Aware emergency" — the one fully hands-free way into
/// emergency mode, for when both hands are busy with an auto-injector.
///
/// Apple requires an App Shortcut phrase to contain the app's name, so a bare
/// "allergy emergency" is not possible; the phrases below are the closest.
@available(iOS 16.0, *)
struct StartEmergencyModeIntent: AppIntent {
  static let title: LocalizedStringResource = "Allergy emergency"
  static let description = IntentDescription(
    "Opens emergency mode: the epinephrine timer, the local emergency number and the card to show the crew.")
  static let openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    IntentBridge.requestEmergency()
    return .result()
  }
}

@available(iOS 16.0, *)
struct FlyAllergyShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: StartEmergencyModeIntent(),
      phrases: [
        "\(.applicationName) emergency",
        "Allergy emergency in \(.applicationName)",
        "Start \(.applicationName) emergency mode",
      ],
      shortTitle: "Allergy emergency",
      systemImageName: "cross.case.fill"
    )
  }
}

/// Hands the intent to Dart.
///
/// One path for both cases: the request is held as pending, and Dart takes it
/// with `consumePending` — when told to while running, or at startup when
/// Siri launched the app cold. Taking it clears it, so emergency mode can
/// never open twice for one request.
enum IntentBridge {
  static let channelName = "fly_allergy_safe/intents"
  private static var channel: FlutterMethodChannel?
  private static var pending = false

  static func register(with messenger: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    c.setMethodCallHandler { call, result in
      switch call.method {
      case "consumePending":
        result(pending)
        pending = false
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    channel = c
  }

  static func requestEmergency() {
    pending = true
    channel?.invokeMethod("emergencyRequested", arguments: nil)
  }
}
