import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/emergency_mode_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/app_state.dart';
import 'services/notifications.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final state = AppState();
  await state.init();

  // Notifications back the auto-injector expiry reminders. A failure here must
  // never block the app from opening — someone may be opening it in a hurry.
  await NotificationService.init();

  runApp(TraceApp(state: state));
}

class TraceApp extends StatefulWidget {
  const TraceApp({super.key, required this.state});

  final AppState state;

  @override
  State<TraceApp> createState() => _TraceAppState();
}

class _TraceAppState extends State<TraceApp> with WidgetsBindingObserver {
  /// True once the app has gone to the background since it was last in front.
  ///
  /// The lock goes back up on every return — there is no grace period. An
  /// earlier version allowed a minute away, timed on the wall clock, and anyone
  /// holding the phone could skip the lock by setting the date back in
  /// Settings. Not timing it at all is the only version that cannot be gamed;
  /// with Face ID it costs a glance. The one exception is the 30 minutes after
  /// an emergency call or text — see [AppState.startEmergencyWindow].
  bool _wentAway = false;

  /// Hides the UI while the app is in the background, because iOS snapshots
  /// the screen on the way out and shows that snapshot in the app switcher.
  bool _obscured = false;

  /// Clears any snack bar on the way out, so nothing from the screen
  /// underneath can surface over the lock.
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// For opening emergency mode from the Siri shortcut, which arrives from
  /// outside any screen.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  static const MethodChannel _intents = MethodChannel(
    'fly_allergy_safe/intents',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _intents.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'emergencyRequested') await _openEmergencyIfAsked();
    });
    // Siri may have launched the app cold, before anything was listening.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openEmergencyIfAsked(),
    );
  }

  /// Takes a pending Siri request, if there is one, and opens emergency mode.
  ///
  /// With the app lock on, it opens underneath the lock: the person unlocks
  /// and is already in emergency mode. The lock does not stand aside for
  /// Siri — anyone can talk to a phone.
  Future<void> _openEmergencyIfAsked() async {
    bool pending = false;
    try {
      pending = await _intents.invokeMethod<bool>('consumePending') ?? false;
    } catch (_) {
      return;
    }
    final app = widget.state;
    if (!pending || !app.onboardingComplete) return;
    final trip = app.activeTrip();
    _navigatorKey.currentState?.push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => EmergencyModeScreen(
          tripId: trip != null && trip.isUnderway(DateTime.now())
              ? trip.id
              : null,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final app = widget.state;
    switch (state) {
      case AppLifecycleState.inactive:
        // The cover has to be up before iOS takes its app-switcher snapshot,
        // and by `paused` that has already happened. `inactive` is the last
        // moment that is reliably early enough.
        //
        // The exception is the system's own authentication sheet, which also
        // drives the app inactive: covering the screen underneath it would
        // make every unlock look like the app had crashed.
        if (app.lockIsEnabled && !app.authInFlight && !_obscured) {
          _messengerKey.currentState?.clearSnackBars();
          setState(() => _obscured = true);
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _wentAway = true;
        if (app.lockIsEnabled && !_obscured) {
          _messengerKey.currentState?.clearSnackBars();
          setState(() => _obscured = true);
        }
      case AppLifecycleState.resumed:
        // lockNow() leaves the gate down inside the emergency window.
        if (_wentAway) app.lockNow();
        _wentAway = false;
        if (_obscured) setState(() => _obscured = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: widget.state,
      child: Consumer<AppState>(
        builder: (context, app, _) {
          return MaterialApp(
            title: 'Fly Allergy Aware',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: app.themeMode,
            // The lock is an overlay above the navigator, not a route and not a
            // swap of `home:`. Screens in this app are pushed on top of `home:`,
            // and swapping `home:` leaves those pushed routes on screen — the
            // lock would be built underneath whatever the user had open, which
            // is not a lock at all. As an overlay it covers everything, and
            // nothing the user was in the middle of is torn down.
            scaffoldMessengerKey: _messengerKey,
            navigatorKey: _navigatorKey,
            builder: (BuildContext context, Widget? child) {
              final bool covered = app.isLocked || _obscured;
              return Stack(
                children: <Widget>[
                  // Covering the screen is not enough on its own. VoiceOver
                  // would still read the profile underneath, a hardware or
                  // software keyboard would still type into whatever field had
                  // focus, and animations would keep running. Excluded from
                  // semantics, cut out of the focus tree, and held still.
                  ExcludeSemantics(
                    excluding: covered,
                    child: ExcludeFocus(
                      excluding: covered,
                      child: TickerMode(
                        enabled: !covered,
                        child: AbsorbPointer(
                          absorbing: covered,
                          child: Column(
                            children: [
                              if (app.hasUnsavedChanges)
                                Material(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                  child: SafeArea(
                                    bottom: false,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'Changes are not saved to this phone. Keep the app open and retry.',
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                app.retryPendingStorage(),
                                            child: const Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              Expanded(child: child ?? const SizedBox.shrink()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (app.isLocked)
                    const LockScreen()
                  else if (_obscured)
                    const PrivacyCover(),
                ],
              );
            },
            // Where you land is a function of state, not of imperative
            // navigation scattered through screens. There is no account and no
            // sign-in: the app has to open on a plane with no signal, and a
            // medical profile does not need to live on someone else's computer.
            home: app.loading
                ? const _SplashScreen()
                : (app.onboardingComplete
                      ? const HomeScreen()
                      : const OnboardingScreen()),
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The app icon itself, so the splash and the home screen are the
            // same mark. Corner radius matches iOS's own icon mask closely
            // enough that it reads as continuous with the launch.
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/logo.png',
                width: 88,
                height: 88,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Fly Allergy Aware',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
