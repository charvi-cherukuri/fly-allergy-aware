import AVFoundation
import Flutter
import Speech

/// On-device speech recognition for voice input, bridged to Dart.
///
/// **Audio never leaves the phone.** Every request sets
/// `requiresOnDeviceRecognition`, and on a device or language that cannot
/// recognise on-device, availability says so and Dart hides the microphone
/// rather than falling back to Apple's servers. That keeps the app's
/// "nothing leaves the phone" promise, and means voice works in airplane mode.
///
/// Speech is delivered in *segments*: an utterance ends after a short pause,
/// is emitted whole, and recognition restarts for the next one. That suits
/// both uses — dictating a form, and listening for "epinephrine given" during
/// an emergency — and keeps each recognition task well under the system's
/// one-minute limit.
///
/// Events on the event channel, as maps:
///   {type: "partial", text}   the utterance so far, for live display
///   {type: "segment", text}   a finished utterance
///   {type: "stopped", reason} listening ended ("stopped", "interrupted", "failed")
final class SpeechBridge: NSObject, FlutterStreamHandler {

  static let methodChannelName = "fly_allergy_safe/speech"
  static let eventChannelName = "fly_allergy_safe/speech/events"
  static let shared = SpeechBridge()

  /// How long a pause ends an utterance.
  private static let pause: TimeInterval = 1.4

  private var sink: FlutterEventSink?
  private let engine = AVAudioEngine()
  private var recognizer: SFSpeechRecognizer?
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var taskToken = UUID()
  private var silenceTimer: Timer?
  private var latest = ""
  private var running = false
  private var failures = 0
  private var interruptionObserver: NSObjectProtocol?

  static func register(with messenger: FlutterBinaryMessenger) {
    let methods = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    methods.setMethodCallHandler { call, result in shared.handle(call, result) }
    let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    events.setStreamHandler(shared)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func emit(_ event: [String: Any]) {
    sink?(event)
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let localeId = (args?["locale"] as? String) ?? Locale.current.identifier
    switch call.method {
    case "availability":
      result(availability(localeId))
    case "requestPermission":
      requestPermission(result)
    case "start":
      start(localeId: localeId, result: result)
    case "stop":
      stop(reason: "stopped")
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - permissions and availability

  private func micGranted() -> Bool {
    if #available(iOS 17.0, *) {
      return AVAudioApplication.shared.recordPermission == .granted
    }
    return AVAudioSession.sharedInstance().recordPermission == .granted
  }

  private func micUndetermined() -> Bool {
    if #available(iOS 17.0, *) {
      return AVAudioApplication.shared.recordPermission == .undetermined
    }
    return AVAudioSession.sharedInstance().recordPermission == .undetermined
  }

  /// Shared with `SpeechAvailability` in lib/services/speech.dart.
  private func availability(_ localeId: String) -> String {
    guard let r = SFSpeechRecognizer(locale: Locale(identifier: localeId)) else {
      return "unsupported_locale"
    }
    if !r.supportsOnDeviceRecognition { return "no_on_device" }
    switch SFSpeechRecognizer.authorizationStatus() {
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "not_determined"
    case .authorized:
      if micGranted() { return "available" }
      return micUndetermined() ? "not_determined" : "denied"
    @unknown default:
      return "denied"
    }
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { status in
      guard status == .authorized else {
        DispatchQueue.main.async { result(false) }
        return
      }
      let done: (Bool) -> Void = { granted in DispatchQueue.main.async { result(granted) } }
      if #available(iOS 17.0, *) {
        AVAudioApplication.requestRecordPermission(completionHandler: done)
      } else {
        AVAudioSession.sharedInstance().requestRecordPermission(done)
      }
    }
  }

  // MARK: - listening

  private func start(localeId: String, result: @escaping FlutterResult) {
    if running { stop(reason: "restarted") }
    guard let r = SFSpeechRecognizer(locale: Locale(identifier: localeId)),
      r.supportsOnDeviceRecognition
    else {
      result(FlutterError(code: "unavailable",
                          message: "On-device speech recognition is not available.",
                          details: nil))
      return
    }
    guard SFSpeechRecognizer.authorizationStatus() == .authorized, micGranted() else {
      result(FlutterError(code: "not_authorized",
                          message: "Speech recognition or the microphone is not allowed.",
                          details: nil))
      return
    }
    recognizer = r

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
      try session.setActive(true, options: .notifyOthersOnDeactivation)
      let input = engine.inputNode
      let format = input.outputFormat(forBus: 0)
      input.removeTap(onBus: 0)
      input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
        self?.request?.append(buffer)
      }
      engine.prepare()
      try engine.start()
    } catch {
      teardownAudio()
      result(FlutterError(code: "audio", message: error.localizedDescription, details: nil))
      return
    }

    running = true
    failures = 0
    observeInterruptions()
    beginTask()
    result(nil)
  }

  private func beginTask() {
    guard running, let r = recognizer else { return }
    let req = SFSpeechAudioBufferRecognitionRequest()
    req.shouldReportPartialResults = true
    req.requiresOnDeviceRecognition = true
    if #available(iOS 16.0, *) { req.addsPunctuation = true }
    request = req
    latest = ""
    let token = UUID()
    taskToken = token
    task = r.recognitionTask(with: req) { [weak self] res, err in
      DispatchQueue.main.async {
        // Ignore callbacks from a task already replaced: cancelling the old
        // one reports an error, and acting on it would end the new one.
        guard let self = self, self.taskToken == token else { return }
        self.onResult(res, err)
      }
    }
  }

  private func onResult(_ res: SFSpeechRecognitionResult?, _ err: Error?) {
    guard running else { return }
    if let res = res {
      let text = res.bestTranscription.formattedString
      if text != latest {
        latest = text
        failures = 0
        emit(["type": "partial", "text": text])
        armSilenceTimer()
      }
      if res.isFinal {
        endSegment()
        return
      }
    }
    if err != nil {
      // Silence and timeouts end a task with an error. Restart quietly — but
      // not forever: a recogniser that fails straight away every time is not
      // going to recover, and a tight restart loop would burn the battery.
      if latest.isEmpty { failures += 1 }
      if failures > 8 {
        stop(reason: "failed")
        return
      }
      endSegment()
    }
  }

  private func armSilenceTimer() {
    silenceTimer?.invalidate()
    silenceTimer = Timer.scheduledTimer(withTimeInterval: Self.pause, repeats: false) {
      [weak self] _ in self?.endSegment()
    }
  }

  /// Emits the utterance so far and starts listening for the next one.
  private func endSegment() {
    silenceTimer?.invalidate()
    silenceTimer = nil
    let text = latest.trimmingCharacters(in: .whitespacesAndNewlines)
    latest = ""
    taskToken = UUID()
    task?.cancel()
    task = nil
    request?.endAudio()
    request = nil
    if !text.isEmpty { emit(["type": "segment", "text": text]) }
    if running { beginTask() }
  }

  private func stop(reason: String) {
    guard running else { return }
    running = false
    silenceTimer?.invalidate()
    silenceTimer = nil
    // Whatever was said before stopping still counts.
    let text = latest.trimmingCharacters(in: .whitespacesAndNewlines)
    latest = ""
    if !text.isEmpty { emit(["type": "segment", "text": text]) }
    taskToken = UUID()
    task?.cancel()
    task = nil
    request?.endAudio()
    request = nil
    teardownAudio()
    emit(["type": "stopped", "reason": reason])
  }

  private func teardownAudio() {
    if engine.isRunning { engine.stop() }
    engine.inputNode.removeTap(onBus: 0)
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    if let o = interruptionObserver {
      NotificationCenter.default.removeObserver(o)
      interruptionObserver = nil
    }
  }

  /// A phone call — including one placed from emergency mode — takes the
  /// microphone. Stop cleanly and tell Dart, which offers to resume.
  private func observeInterruptions() {
    guard interruptionObserver == nil else { return }
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] note in
      guard
        let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
        AVAudioSession.InterruptionType(rawValue: raw) == .began
      else { return }
      self?.stop(reason: "interrupted")
    }
  }
}
