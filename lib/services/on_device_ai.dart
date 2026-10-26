import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether Apple's on-device language model can be used on this device.
///
/// Mirrors the status strings returned by
/// `ios/Runner/FoundationModelsBridge.swift`.
enum AiAvailability {
  available,
  unavailableDevice,
  notEnabled,
  modelNotReady,
  unsupportedOs,
  error;

  bool get isAvailable => this == AiAvailability.available;
}

/// Apple's on-device model (Apple Intelligence). Voice input uses it to fill
/// forms from what was said; see `VoiceFill`. Everything runs on the device.
class OnDeviceAi {
  OnDeviceAi._();

  static const MethodChannel _channel =
      MethodChannel('fly_allergy_safe/on_device_ai');

  static AiAvailability? _availabilityCache;

  /// Cached after the first settled answer — the OS state does not change
  /// mid-session in any way that matters.
  static Future<AiAvailability> availability() async {
    final cached = _availabilityCache;
    if (cached != null) return cached;

    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return _availabilityCache = AiAvailability.unsupportedOs;
    }

    try {
      final raw = await _channel
          .invokeMethod<String>('availability')
          .timeout(const Duration(seconds: 2));
      final parsed = _parse(raw);
      // A transient error is not cached; a settled answer is.
      if (parsed != AiAvailability.error) _availabilityCache = parsed;
      return parsed;
    } on MissingPluginException {
      return _availabilityCache = AiAvailability.unsupportedOs;
    } catch (_) {
      return AiAvailability.error;
    }
  }

  static AiAvailability _parse(String? raw) {
    switch (raw) {
      case 'available':
        return AiAvailability.available;
      case 'unavailable_device':
        return AiAvailability.unavailableDevice;
      case 'unavailable_not_enabled':
        return AiAvailability.notEnabled;
      case 'unavailable_model_not_ready':
        return AiAvailability.modelNotReady;
      case 'unsupported_os':
        return AiAvailability.unsupportedOs;
      default:
        return AiAvailability.error;
    }
  }
}
