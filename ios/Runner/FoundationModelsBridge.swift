import Flutter
import UIKit

#if canImport(FoundationModels)
  import FoundationModels
#endif

/// Bridges Apple's on-device `SystemLanguageModel` (FoundationModels, iOS 26+)
/// to Dart over a `FlutterMethodChannel`: whether it is available, and
/// `extract`, which turns what a traveler said into form fields for voice
/// input. Dart validates every returned value before using it.
///
/// Nothing here traps. Every failure returns a status string or a `FlutterError`.
enum FoundationModelsBridge {

  static let channelName = "fly_allergy_safe/on_device_ai"

  /// Status strings shared with `AiAvailability` in lib/services/on_device_ai.dart.
  private enum Status {
    static let available = "available"
    static let unavailableDevice = "unavailable_device"
    static let notEnabled = "unavailable_not_enabled"
    static let modelNotReady = "unavailable_model_not_ready"
    static let unsupportedOs = "unsupported_os"
  }

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "availability":
        result(currentAvailability())
      case "extract":
        handleExtract(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - availability

  private static func currentAvailability() -> String {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        switch SystemLanguageModel.default.availability {
        case .available:
          return Status.available
        case .unavailable(let reason):
          switch reason {
          case .deviceNotEligible:
            return Status.unavailableDevice
          case .appleIntelligenceNotEnabled:
            return Status.notEnabled
          case .modelNotReady:
            return Status.modelNotReady
          @unknown default:
            // A reason this build does not know about is treated as not ready
            // rather than as available. Voice input then uses its built-in rules.
            return Status.modelNotReady
          }
        }
      }
      return Status.unsupportedOs
    #else
      return Status.unsupportedOs
    #endif
  }
}

// MARK: - extract

extension FoundationModelsBridge {

  /// Turns what someone said into form fields — voice input for the travel
  /// journal. Returns a map of fields; Dart validates every value against what
  /// the form allows before using any of it, and the user reviews the form
  /// before anything is saved.
  static func handleExtract(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let kind = args["kind"] as? String,
      let text = args["text"] as? String,
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(FlutterError(code: "bad_arguments",
                          message: "extract requires 'kind' and non-empty 'text'.",
                          details: nil))
      return
    }
    let today = (args["today"] as? String) ?? ""

    #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        guard case .available = SystemLanguageModel.default.availability else {
          result(FlutterError(code: "unavailable",
                              message: "The on-device language model is not available.",
                              details: nil))
          return
        }
        Task {
          let outcome = await Extractor.run(kind: kind, text: text, today: today)
          DispatchQueue.main.async {
            switch outcome {
            case .success(let fields): result(fields)
            case .failure(let message):
              result(FlutterError(code: "extract_failed", message: message, details: nil))
            }
          }
        }
        return
      }
    #endif
    result(FlutterError(code: "unsupported_os",
                        message: "Extraction needs iOS 26 and Apple Intelligence.",
                        details: nil))
  }
}

#if canImport(FoundationModels)

  @available(iOS 26.0, *)
  @Generable
  struct TripFields {
    @Guide(description: "Destination country as an ISO 3166-1 alpha-2 code such as JP or GB. Empty if no destination was said.")
    var countryCode: String
    @Guide(description: "First day of the trip as YYYY-MM-DD. Empty if not said.")
    var startDate: String
    @Guide(description: "Last day of the trip as YYYY-MM-DD. Empty if not said.")
    var endDate: String
    @Guide(description: "First names of the people travelling, exactly as said. 'me' or 'I' as the word me.")
    var travelers: [String]
  }

  @available(iOS 26.0, *)
  @Generable
  struct ExposureFields {
    @Guide(description: "First name of the person exposed, exactly as said. Empty if not said.")
    var person: String
    @Guide(description: "Foods or allergens involved, as said, such as peanut or sesame.")
    var allergens: [String]
    @Guide(description: "How the allergen reached the person.",
           .anyOf(["ingested", "skin", "surface", "airborne", "crossContact", "observedNearby", ""]))
    var route: String
    @Guide(description: "What it came from, in a few words. Empty if not said.")
    var source: String
    @Guide(description: "Where it happened.",
           .anyOf(["flight", "airport", "hotel", "restaurant", "transport", "other", ""]))
    var place: String
    @Guide(description: "Name of the restaurant, hotel or other place. Empty if not said.")
    var placeName: String
    @Guide(description: "Aircraft row number as digits. Empty if not said.")
    var row: String
    @Guide(description: "Things done afterwards, as said, such as washed hands or took an antihistamine.")
    var actions: [String]
    @Guide(description: "Whether symptoms followed.", .anyOf(["noSymptoms", "symptoms", ""]))
    var outcome: String
  }

  @available(iOS 26.0, *)
  @Generable
  struct ReactionFields {
    @Guide(description: "Symptoms described, each in a few words, such as hives or throat tightness.")
    var symptoms: [String]
    @Guide(description: "True only if epinephrine or an auto-injector was said to have been given.")
    var epinephrineGiven: Bool
    @Guide(description: "True only if an ambulance, paramedics, a hospital or a doctor was said to have been involved.")
    var soughtCare: Bool
    @Guide(description: "The food suspected of causing it, as said. Empty if not said.")
    var suspectedFood: String
  }

  @available(iOS 26.0, *)
  @Generable
  struct IncidentFields {
    @Guide(description: "What kind of incident it was.",
           .anyOf(["accommodationFailure", "allergicReaction", "refusedBoarding", "crewConduct", "venueFailure", "other"]))
    var kind: String
  }

  @available(iOS 26.0, *)
  private enum Extractor {

    enum Outcome {
      case success([String: Any])
      case failure(String)
    }

    private static let instructions = """
      You fill in form fields from what a traveler with a food allergy said. \
      Use only what was actually said. Never guess, never add medical facts, \
      and leave a field empty when it was not mentioned.
      """

    static func run(kind: String, text: String, today: String) async -> Outcome {
      let session = LanguageModelSession(instructions: instructions)
      let options = GenerationOptions(sampling: .greedy)
      let prompt = "Today is \(today). The traveler said: \"\(text)\""
      do {
        switch kind {
        case "trip":
          let f = try await session.respond(to: prompt, generating: TripFields.self, options: options).content
          return .success(["countryCode": f.countryCode, "startDate": f.startDate,
                           "endDate": f.endDate, "travelers": f.travelers])
        case "exposure":
          let f = try await session.respond(to: prompt, generating: ExposureFields.self, options: options).content
          return .success(["person": f.person, "allergens": f.allergens, "route": f.route,
                           "source": f.source, "place": f.place, "placeName": f.placeName,
                           "row": f.row, "actions": f.actions, "outcome": f.outcome])
        case "reaction":
          let f = try await session.respond(to: prompt, generating: ReactionFields.self, options: options).content
          return .success(["symptoms": f.symptoms, "epinephrineGiven": f.epinephrineGiven,
                           "soughtCare": f.soughtCare, "suspectedFood": f.suspectedFood])
        case "incident":
          let f = try await session.respond(to: prompt, generating: IncidentFields.self, options: options).content
          return .success(["kind": f.kind])
        default:
          return .failure("Unknown kind \(kind).")
        }
      } catch {
        return .failure(error.localizedDescription)
      }
    }
  }

#endif
