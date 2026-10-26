import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';

/// Hands off to the phone's own Phone or Messages app.
///
/// Every emergency action leaves this app, and those are the trips that run
/// long — a call with a dispatcher, a back-and-forth with a parent. Coming back
/// from one to a lock screen is the app failing at the one moment it exists
/// for, so a successful handoff starts a 30-minute window in which the lock
/// stays down, callbacks included.
///
/// The window starts only once the launch has actually succeeded, so a tapped
/// button with no number behind it, or a cancelled confirmation, starts
/// nothing.
Future<bool> handOffToPhone(BuildContext context, Uri uri) async {
  final AppState app = context.read<AppState>();
  bool launched = false;
  try {
    launched = await launchUrl(uri);
  } catch (e) {
    debugPrint('handOffToPhone: could not open $uri ($e)');
    launched = false;
  }
  if (launched) app.startEmergencyWindow();
  return launched;
}

/// A dialable string.
///
/// Extensions are cut rather than run together with the number: "x204" folded
/// onto the end dials a different phone entirely. `*` and `#` survive because
/// they are real DTMF, and some direct lines need them.
String dialableNumber(String raw) {
  return raw
      .split(RegExp(r'(?:ext|extension|x)\.?\s*\d+$', caseSensitive: false))
      .first
      .replaceAll(RegExp(r'[^0-9+*#]'), '');
}
