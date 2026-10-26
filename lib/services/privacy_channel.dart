import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tells the iOS side whether the app lock is on, so it can close native
/// screens — the share sheet, an in-app Safari page — when the app goes to the
/// background. Those are drawn above Flutter, so the lock cannot cover them.
///
/// Pushed ahead of time rather than asked for at the moment the app leaves:
/// iOS sends the app to the background before Dart hears about it, and the
/// decision has to be made natively, immediately. See SceneDelegate.swift.
class PrivacyChannel {
  const PrivacyChannel._();

  static const MethodChannel _channel = MethodChannel('fly_allergy_safe/privacy');

  static bool? _sent;

  static Future<void> setLockActive(bool active) async {
    if (_sent == active) return;
    try {
      await _channel.invokeMethod<void>('setLockActive', active);
      _sent = active;
    } catch (e) {
      // No native side — a test, or a platform that is not iOS. Nothing to do.
      debugPrint('PrivacyChannel: not delivered ($e)');
    }
  }
}
