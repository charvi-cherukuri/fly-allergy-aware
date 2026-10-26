import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_lock.dart';
import '../services/app_state.dart';

/// The gate at the front of the app.
///
/// It holds no secret and asks for nothing itself — it calls the device, and
/// iOS puts up its own Face ID prompt with the iPhone passcode sheet behind it.
/// The app never sees either.
///
/// It exists because a phone gets handed around — to a child, to a flight
/// attendant, to whoever picks it up off the seat — and a medical profile is
/// nobody else's reading. It is not a claim about the data on disk, which is
/// still an ordinary file on the device.
///
/// This is rendered as an overlay above the whole navigator, not as a route, so
/// it covers whatever screen was open when the app went away.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _asking = false;
  bool _refused = false;
  // Neutral until the device says which it is.
  String _method = 'Face ID or your passcode';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMethod();
      _ask();
    });
  }

  Future<void> _loadMethod() async {
    final label = await context.read<AppState>().lockMethodLabel();
    if (!mounted) return;
    setState(() => _method = label);
  }

  Future<void> _ask() async {
    if (_asking) return;
    setState(() {
      _asking = true;
      _refused = false;
    });
    final outcome = await context.read<AppState>().unlock();
    if (!mounted) return;
    setState(() {
      _asking = false;
      // `unlocked` and `unavailable` both open the app — the second by turning
      // the lock off, because a lock whose key no longer exists is just a
      // locked-out user. Either way this overlay is about to disappear.
      _refused = outcome == LockOutcome.failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          // Scrolls, because the helper note makes this taller than an iPhone
          // SE's screen once Dynamic Type is turned up — and an overflow here
          // would hide the very lines a helper needs.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 84,
                      height: 84,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Fly Allergy Aware',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Neutral, never red, and no "try again". Whoever is holding
                  // the phone may not be its owner, and every failed Face ID
                  // attempt counts toward iOS locking Face ID for the whole phone.
                  Text(
                    _refused
                        ? 'Not unlocked.'
                        : 'Locked. Unlock with $_method to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 240,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _asking ? null : _ask,
                      icon: _asking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock_open_rounded, size: 20),
                      label: Text(_asking ? 'Waiting' : 'Unlock'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _HelperNote(method: _method),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the app switcher sees while the app is in the background.
///
/// iOS snapshots the screen on the way out, and that snapshot is visible to
/// anyone who double-taps home. Without this, the lock would be pointless for
/// the one thing it is for: someone picking up a phone that is already out.
class PrivacyCover extends StatelessWidget {
  const PrivacyCover({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/logo.png',
            width: 84,
            height: 84,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

/// For whoever is holding the phone when it is not its owner.
///
/// With the lock on by default, the person reading this screen during a
/// reaction is as likely to be a seatmate or a flight attendant as the owner.
/// It leads with the one action that matters most and works anywhere — their
/// own auto-injector — then what works on a plane, since "call your local
/// emergency number" reaches no one at cruising altitude.
class _HelperNote extends StatelessWidget {
  const _HelperNote({required this.method});

  /// What the device unlocks with, from [AppState.lockMethodLabel], so the
  /// passcode route below names the buttons this phone will actually show.
  final String method;

  static String _passcodeRoute(String method) {
    if (method == 'Touch ID') {
      return 'Know this iPhone’s passcode? Tap Unlock, touch the Home button '
          'once, then tap Enter Passcode. Otherwise, do not keep trying.';
    }
    if (method == 'your passcode') {
      return 'Know this iPhone’s passcode? Tap Unlock and enter it. '
          'Otherwise, do not keep trying.';
    }
    return 'Know this iPhone’s passcode? Tap Unlock, then Try Face ID Again, '
        'then Enter Passcode. Otherwise, do not keep trying.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final TextStyle body = TextStyle(
      fontSize: 14.5,
      height: 1.4,
      color: scheme.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Helping someone?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          // Their own auto-injector first: it is step one in the app's own
          // clinical guidance, and it is likely in their bag right now.
          Text(
            'If they are having a severe reaction and carry an epinephrine '
            'auto-injector (EpiPen), use it in their outer thigh now.',
            style: body.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          // Positioning, matching step 3 of clinical_guidance_screen.dart in
          // full — including both of its exceptions. An earlier version kept
          // "lying down" and dropped "sitting up is acceptable if breathing is
          // hard", which told a stranger to hold flat someone whose airway was
          // closing.
          Text(
            'Lay them flat with legs raised, or let them sit up if breathing is '
            'hard. If they are vomiting or unresponsive, turn them on their side.',
            style: body,
          ),
          const SizedBox(height: 8),
          // On a plane the instinct is to walk someone to the galley or the
          // lavatory, and sudden upright posture is linked to collapse.
          Text('Do not stand them up or walk them.', style: body),
          const SizedBox(height: 8),
          // Hedged on purpose. Only US carriers are required to carry
          // epinephrine; the app's own airline data lists nine of its twenty
          // that do not. A stranger reading this must not be promised a kit.
          Text(
            'On a plane: tell the cabin crew now. The plane’s medical kit may '
            'have epinephrine, often as a vial and syringe, not an auto-injector.',
            style: body,
          ),
          const SizedBox(height: 8),
          Text(
            'On the ground: call the local emergency number.',
            style: body,
          ),
          const SizedBox(height: 8),
          Text(
            'No better after 5 to 15 minutes: use a second injector if there '
            'is one.',
            style: body,
          ),
          const SizedBox(height: 8),
          // The route iOS actually shows for deviceOwnerAuthentication, which
          // differs by sensor (LAContext.h). Face ID: the first failure offers
          // only Try Face ID Again, and Enter Passcode follows the second.
          // Touch ID: Enter Passcode appears after one unrecognized touch.
          Text(_passcodeRoute(method), style: body),
          const SizedBox(height: 8),
          // The Health app, not the lock screen: whoever reads this is holding
          // an unlocked phone, and locking it to reach Emergency would cost a
          // helper without the passcode everything else on it.
          Text(
            'Their Medical ID may list allergies: in the Health app, tap their '
            'picture, then Medical ID.',
            style: body,
          ),
        ],
      ),
    );
  }
}
