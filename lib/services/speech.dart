import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether voice input can be offered. Mirrors `SpeechBridge.swift`.
enum SpeechAvailability {
  /// Ready to listen.
  available,

  /// Supported, but the user has not been asked yet. The first tap asks.
  needsPermission,

  /// The user said no, or a device policy forbids it. Settings can change it.
  denied,

  /// This phone cannot recognise speech *on the device* in this language.
  /// Voice is hidden rather than sending audio to a server.
  unavailable,
}

/// One event from the recogniser.
class SpeechEvent {
  const SpeechEvent._(this.type, this.text);

  /// "partial", "segment" or "stopped".
  final String type;

  /// The words, for partial and segment; the reason, for stopped.
  final String text;

  bool get isPartial => type == 'partial';
  bool get isSegment => type == 'segment';
  bool get isStopped => type == 'stopped';
}

/// On-device speech recognition. Audio never leaves the phone: the native
/// side refuses to recognise anywhere but on the device.
class SpeechService {
  SpeechService._();

  static final SpeechService instance = SpeechService._();

  static const MethodChannel _methods = MethodChannel('fly_allergy_safe/speech');
  static const EventChannel _events = EventChannel('fly_allergy_safe/speech/events');

  Stream<SpeechEvent>? _stream;

  /// The phone's language, as the recogniser wants it ("en-US").
  String get locale => PlatformDispatcher.instance.locale.toLanguageTag();

  Stream<SpeechEvent> get events => _stream ??= _events
      .receiveBroadcastStream()
      .map((dynamic e) {
        final Map<dynamic, dynamic> m = e as Map<dynamic, dynamic>;
        final String type = (m['type'] as String?) ?? '';
        final String text = (m['text'] as String?) ?? (m['reason'] as String?) ?? '';
        return SpeechEvent._(type, text);
      })
      .asBroadcastStream();

  Future<SpeechAvailability> availability() async {
    try {
      final String? s =
          await _methods.invokeMethod<String>('availability', {'locale': locale});
      switch (s) {
        case 'available':
          return SpeechAvailability.available;
        case 'not_determined':
          return SpeechAvailability.needsPermission;
        case 'denied':
        case 'restricted':
          return SpeechAvailability.denied;
        default:
          return SpeechAvailability.unavailable;
      }
    } catch (e) {
      debugPrint('SpeechService.availability: $e');
      return SpeechAvailability.unavailable;
    }
  }

  /// Asks for speech recognition and the microphone. True when both granted.
  Future<bool> requestPermission() async {
    try {
      return await _methods.invokeMethod<bool>('requestPermission') ?? false;
    } catch (e) {
      debugPrint('SpeechService.requestPermission: $e');
      return false;
    }
  }

  /// Starts listening. Returns false when it could not start.
  Future<bool> start() async {
    try {
      await _methods.invokeMethod<void>('start', {'locale': locale});
      return true;
    } catch (e) {
      debugPrint('SpeechService.start: $e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _methods.invokeMethod<void>('stop');
    } catch (e) {
      debugPrint('SpeechService.stop: $e');
    }
  }

  /// Makes sure voice can be used, asking for permission when it has not
  /// been asked yet. True when ready.
  Future<bool> ensureReady() async {
    final SpeechAvailability a = await availability();
    if (a == SpeechAvailability.available) return true;
    if (a == SpeechAvailability.needsPermission) return requestPermission();
    return false;
  }
}
