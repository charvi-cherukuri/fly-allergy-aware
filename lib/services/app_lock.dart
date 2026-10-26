import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What came of asking the device to check who is holding it.
enum LockOutcome {
  /// Face ID, Touch ID or the device passcode was accepted.
  unlocked,

  /// The user cancelled, or failed the check. The gate stays up.
  failed,

  /// The device cannot answer the question at all — no passcode set on the
  /// iPhone, or biometrics permanently locked out. The gate must come down:
  /// see [AppLock.unlock].
  unavailable,
}

/// The device's own authentication, behind an interface so tests do not need a
/// phone and a face.
abstract class DeviceAuth {
  /// True when the device can identify its owner — Face ID, Touch ID, or an
  /// iPhone passcode. False on a phone with no passcode set at all.
  Future<bool> isAvailable();

  /// What to call it in the UI: "Face ID", "Touch ID", or "your passcode".
  Future<String> methodLabel();

  Future<LockOutcome> authenticate(String reason);
}

/// The real one: iOS's own sheet, nothing of ours.
class SystemDeviceAuth implements DeviceAuth {
  SystemDeviceAuth([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      // isDeviceSupported maps to canEvaluatePolicy(.deviceOwnerAuthentication),
      // which is true when the phone has a passcode — with or without a face.
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('AppLock: could not query device support ($e)');
      return false;
    }
  }

  @override
  Future<String> methodLabel() async {
    try {
      final enrolled = await _auth.getAvailableBiometrics();
      if (enrolled.contains(BiometricType.face)) return 'Face ID';
      if (enrolled.contains(BiometricType.fingerprint)) return 'Touch ID';
    } catch (e) {
      debugPrint('AppLock: could not read biometric types ($e)');
    }
    // Nothing enrolled, but the phone still has a passcode, which iOS will ask
    // for. Naming that is better than naming a sensor the user has not set up.
    return 'your passcode';
  }

  @override
  Future<LockOutcome> authenticate(String reason) async {
    try {
      // biometricOnly: false is the whole point — it resolves to
      // LAPolicy.deviceOwnerAuthentication, so Face ID is tried first and the
      // iPhone's own passcode sheet is the fallback. The app never sees either.
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          // MUST stay false. With the package default of true, local_auth's
          // iOS plugin catches `passcodeNotSet` itself, shows its own
          // "Go to Settings" alert and reports a plain failure — so the code
          // never reaches Dart and [LockOutcome.unavailable] becomes
          // unreachable for the exact case it exists for. The app would then
          // hold its own gate shut against a device that cannot open it.
          // Verified in local_auth_darwin/LocalAuthPlugin.swift, handleError.
          useErrorDialogs: false,
        ),
      );
      return ok ? LockOutcome.unlocked : await _classifyFailure();
    } on PlatformException catch (e) {
      // These mean the device cannot answer, not that the person failed.
      // 'PermanentlyLockedOut' is Android-only; iOS reports a biometry lockout
      // as a plain failure, which _classifyFailure catches instead.
      const dead = <String>{
        'PasscodeNotSet',
        'NotEnrolled',
        'NotAvailable',
        'BiometricNotAvailable',
        'PermanentlyLockedOut',
      };
      if (dead.contains(e.code)) {
        debugPrint('AppLock: device cannot authenticate (${e.code})');
        return LockOutcome.unavailable;
      }
      debugPrint('AppLock: authentication failed (${e.code})');
      return await _classifyFailure();
    } catch (e) {
      debugPrint('AppLock: authentication error ($e)');
      return await _classifyFailure();
    }
  }

  /// A refusal and a device that cannot ask look identical from Dart on iOS —
  /// biometry lockout comes back as a plain `false`, and so does a cancel. Ask
  /// the device whether it could authenticate at all: if it could not, this was
  /// never a refusal, and holding the gate shut would strand the user.
  Future<LockOutcome> _classifyFailure() async {
    final canAsk = await isAvailable();
    return canAsk ? LockOutcome.failed : LockOutcome.unavailable;
  }
}

/// The lock on the front door.
///
/// It is the iPhone's own lock, not one of ours: Face ID, and the system
/// passcode sheet behind it. The app stores one thing — the user's on/off
/// choice — and never sees, holds or hashes a secret. That removes
/// the whole class of problems a home-grown passcode has: nothing to forget
/// with no way to reset, nothing to brute-force in a four-digit space, nothing
/// to half-write and brick the app with.
///
/// **This is not a security boundary for the data and must not be described as
/// one.** The allergen profiles sit in a SQLite file that anyone with the
/// device and file access can read whether or not they can unlock the app. What
/// this does is keep the app shut in the ordinary case — a phone handed to a
/// child, a phone left on a tray table — which is the case that actually
/// happens.
///
/// There is no account, no email, no server. A medical profile does not need to
/// sit on someone else's computer to be useful on a plane, and the app has to
/// open with no signal regardless.
class AppLock {
  AppLock({
    SharedPreferences? prefs,
    DeviceAuth? device,
    DateTime Function()? clock,
    Duration Function()? monotonic,
  })  : _prefs = prefs,
        _device = device ?? SystemDeviceAuth(),
        _now = clock ?? DateTime.now,
        _monotonic = monotonic ?? _sinceLaunch;

  SharedPreferences? _prefs;
  final DeviceAuth _device;

  /// The wall clock. Anyone holding the phone can change it in Settings, so it
  /// is never trusted on its own for anything that opens the gate.
  final DateTime Function() _now;

  /// Time that only moves forward and that Settings cannot touch.
  final Duration Function() _monotonic;

  static final Stopwatch _appClock = Stopwatch()..start();
  static Duration _sinceLaunch() => _appClock.elapsed;

  /// The user's choice, and only ever their choice: true (on), false (off), or
  /// absent (never touched — the default, which is on). Nothing the lock does
  /// to itself is ever written here.
  static const String _kEnabled = 'appLockEnabled';



  /// How long after an emergency call or text the lock stays down: long enough
  /// for a call with a dispatcher, a callback, and waiting for help.
  ///
  /// Held in memory only, and timed on two clocks that must both agree. It is
  /// deliberately not saved. A saved window has to be checked against the wall
  /// clock on the next launch, and anyone holding the phone can set the wall
  /// clock — two earlier versions that saved it could be reopened that way. The
  /// cost is honest and small: if iOS closes the app during a long call, the
  /// owner gets one Face ID prompt on the way back. Nothing about an emergency
  /// is ever written to the phone.
  static const Duration emergencyWindow = Duration(minutes: 30);

  /// Keys written by the previous, home-grown passcode. Cleared on first run of
  /// this version: the app no longer holds a secret, and a leftover digest of
  /// one is exactly the thing this design exists to not have lying around.
  static const List<String> _retiredKeys = <String>[
    'lockHash',
    'lockSalt',
    'lockIterations',
    'lockBiometrics',
    // Two earlier versions of the emergency window saved a time, which a clock
    // set in Settings could reopen. Neither shipped; cleared regardless.
    'appLockEmergencyUntil',
    'appLockEmergencyStart',
  ];

  bool _enabled = false;
  bool _locked = false;

  DateTime? _emergencyWallStart;
  Duration? _emergencyMonoStart;

  /// True when the lock is in force: the user wants it (or never said
  /// otherwise) and this phone can authenticate right now.
  bool get isEnabled => _enabled;

  /// True when the app is currently gated. Always false when the lock is off —
  /// a gate nobody asked for must never strand anyone outside the app.
  bool get isLocked => _enabled && _locked;

  Future<void> init([SharedPreferences? prefs]) async {
    try {
      _prefs = prefs ?? _prefs ?? await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('AppLock: preferences unavailable ($e)');
      return;
    }
    final store = _prefs;
    if (store == null) return;

    // What the user wants: their stored choice, or on by default. A device
    // that had the old home-grown passcode wanted a lock, so it is recorded as
    // a choice of on.
    final hadOldPasscode = store.getString('lockHash') != null;
    final bool? chosen = store.getBool(_kEnabled);
    if (chosen == null && hadOldPasscode) await _write(true);
    final bool wanted = chosen ?? true;

    // What the phone can do, asked fresh on every launch rather than inferred
    // from anything saved. An iPhone with no passcode has nothing to lock with,
    // so the lock stands down for as long as that is true — and comes back by
    // itself once a passcode is set, whether it was on by choice or default.
    _enabled = wanted && await _device.isAvailable();

    // Every cold start is locked. Nothing saved can say otherwise.
    _locked = _enabled;

    // Cleared whenever any of them is present, not only alongside a surviving
    // digest — a half-written old lock would otherwise leave a salt behind for
    // good, which is precisely what this design exists not to have lying about.
    for (final String key in _retiredKeys) {
      if (!store.containsKey(key)) continue;
      try {
        await store.remove(key);
      } catch (e) {
        debugPrint('AppLock: could not clear $key ($e)');
      }
    }
  }

  Future<bool> isAvailable() => _device.isAvailable();

  Future<String> methodLabel() => _device.methodLabel();

  /// Turning the lock on asks the device first — both to prove it can ask at
  /// all, and so the person enabling it is the person who can open it.
  Future<LockOutcome> enable() async {
    final outcome = await _device.authenticate(
      'Turn on the lock for Fly Allergy Aware',
    );
    if (outcome != LockOutcome.unlocked) return outcome;
    _enabled = true;
    _locked = false;
    await _write(true);
    return LockOutcome.unlocked;
  }

  /// Turning it off asks too, so a phone handed over while open cannot have its
  /// lock quietly removed.
  Future<LockOutcome> disable() async {
    final outcome = await _device.authenticate(
      'Turn off the lock for Fly Allergy Aware',
    );
    if (outcome == LockOutcome.failed) return outcome;
    // An `unavailable` is corroborated first, as in [unlock]: iOS maps errors
    // it does not recognise to NotAvailable, and a phone handed over while the
    // app was open must not be able to switch the lock off on the strength of
    // one. If the device really cannot authenticate, the user asked for off.
    if (outcome == LockOutcome.unavailable && await _device.isAvailable()) {
      return LockOutcome.failed;
    }
    _enabled = false;
    _locked = false;
    await _write(false);
    return LockOutcome.unlocked;
  }

  /// Asks the device to open the gate.
  ///
  /// If the device cannot authenticate at all any more — the owner removed
  /// their iPhone passcode after turning this on — the lock disables itself and
  /// the app opens. A lock whose key has ceased to exist is not security, it is
  /// a locked-out user standing between someone and their action plan.
  Future<LockOutcome> unlock() async {
    final outcome = await _device.authenticate('Unlock Fly Allergy Aware');
    switch (outcome) {
      case LockOutcome.unlocked:
        _locked = false;
      case LockOutcome.unavailable:
        // Corroborate before discarding the user's setting: a transient error
        // should not silently throw away a lock they asked for.
        if (await _device.isAvailable()) {
          debugPrint('AppLock: transient failure, keeping the lock on');
          return LockOutcome.failed;
        }
        // Stood down for now, and nothing written. The phone losing its
        // passcode is not the user turning the lock off, whether they had
        // switched it on or left the default; init() asks the device again on
        // the next launch and the lock returns once a passcode does.
        _enabled = false;
        _locked = false;
      case LockOutcome.failed:
        break;
    }
    return outcome;
  }

  /// Puts the gate back up — on a cold start, and when the app has been away
  /// long enough that someone else could be holding the phone.
  void lock() {
    if (!inEmergencyWindow) _emergencyWallStart = _emergencyMonoStart = null;
    if (_enabled && !inEmergencyWindow) _locked = true;
  }

  /// True for [emergencyWindow] after an emergency call or text left the app.
  ///
  /// Both clocks must agree. The wall clock alone can be set back in Settings
  /// to reopen an old window; the monotonic clock alone may not count time the
  /// phone spent asleep, which would hold the window open for hours. Requiring
  /// both to read between zero and thirty minutes closes both: a clock set
  /// backwards reads negative, a clock set into an old window is contradicted
  /// by the monotonic one, and an honest sleep is caught by the wall clock.
  bool get inEmergencyWindow {
    final DateTime? wallStart = _emergencyWallStart;
    final Duration? monoStart = _emergencyMonoStart;
    if (wallStart == null || monoStart == null) return false;
    final Duration wall = _now().difference(wallStart);
    final Duration mono = _monotonic() - monoStart;
    bool inside(Duration d) => !d.isNegative && d < emergencyWindow;
    return inside(wall) && inside(mono);
  }

  /// Starts the emergency window. Called only once a call or text to the
  /// phone's own apps has actually launched, so a tap that went nowhere cannot
  /// exempt anything.
  void startEmergencyWindow() {
    _emergencyWallStart = _now();
    _emergencyMonoStart = _monotonic();
  }

  /// Lifts the gate without asking, for the one case where there is nothing
  /// behind it: a first launch that has not finished onboarding. Asking a new
  /// user for Face ID before the app has shown them a single screen protects
  /// nothing, because no profile exists yet. Never call this for any other
  /// reason — every other way through the gate goes through the device.
  void openForSetup() {
    _locked = false;
  }

  Future<void> _write(bool value) async {
    try {
      await _prefs?.setBool(_kEnabled, value);
    } catch (e) {
      debugPrint('AppLock: could not persist the lock setting ($e)');
    }
  }
}
