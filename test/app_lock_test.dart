import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trace_allergy/services/app_lock.dart';

/// A stand-in for the iPhone, so these tests need neither a device nor a face.
class _FakeDevice implements DeviceAuth {
  _FakeDevice({this.available = true, this.outcome = LockOutcome.unlocked});

  bool available;
  LockOutcome outcome;
  String label = 'Face ID';

  /// Every reason string the app has put in front of the user, in order.
  final List<String> prompts = <String>[];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String> methodLabel() async => label;

  @override
  Future<LockOutcome> authenticate(String reason) async {
    prompts.add(reason);
    return outcome;
  }
}

/// The lock holds no secret of its own — it asks the device. So what is worth
/// testing is the gate's state machine and, above all, that it can never strand
/// someone outside their own emergency information.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AppLock, _FakeDevice, SharedPreferences)> freshLock({
    Map<String, Object> seed = const <String, Object>{},
    LockOutcome outcome = LockOutcome.unlocked,
    bool available = true,
  }) async {
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(seed));
    final prefs = await SharedPreferences.getInstance();
    final device = _FakeDevice(outcome: outcome, available: available);
    final lock = AppLock(prefs: prefs, device: device);
    await lock.init();
    return (lock, device, prefs);
  }

  group('on by default', () {
    test('a device that can authenticate gets the lock without asking',
        () async {
      final (lock, device, _) = await freshLock();
      expect(lock.isEnabled, isTrue);
      expect(lock.isLocked, isTrue);
      expect(device.prompts, isEmpty,
          reason: 'defaulting on is not a reason to put up a prompt');
    });

    test('a phone with no passcode does not get a lock it cannot open',
        () async {
      final (lock, _, _) = await freshLock(available: false);
      expect(lock.isEnabled, isFalse);
      expect(lock.isLocked, isFalse);
    });

    test('an explicit off is kept, launch after launch', () async {
      final (lock, _, prefs) = await freshLock(seed: {'appLockEnabled': false});
      expect(lock.isEnabled, isFalse);

      final again = AppLock(prefs: prefs, device: _FakeDevice());
      await again.init();
      expect(again.isEnabled, isFalse,
          reason: 'a user who turned it off must not have it turned back on');
    });

    test('the default is not written down, so it is never mistaken for a '
        'choice', () async {
      final (_, _, prefs) = await freshLock();
      expect(prefs.getKeys(), isEmpty);
    });

    test('setup can lift the gate without asking the device', () async {
      final (lock, device, _) = await freshLock();
      expect(lock.isLocked, isTrue);
      lock.openForSetup();
      expect(lock.isLocked, isFalse);
      expect(lock.isEnabled, isTrue, reason: 'lifted for now, still on');
      expect(device.prompts, isEmpty);

      lock.lock();
      expect(lock.isLocked, isTrue, reason: 'and it comes back next time');
    });
  });

  test('enabling asks the device first and leaves the app open', () async {
    final (lock, device, prefs) =
        await freshLock(seed: {'appLockEnabled': false});
    expect(await lock.enable(), LockOutcome.unlocked);
    expect(lock.isEnabled, isTrue);
    expect(lock.isLocked, isFalse);
    expect(device.prompts, hasLength(1));
    expect(prefs.getBool('appLockEnabled'), isTrue);
  });

  test('a refused confirmation does not turn the lock on', () async {
    final (lock, device, prefs) = await freshLock(
      seed: {'appLockEnabled': false},
      outcome: LockOutcome.failed,
    );
    expect(await lock.enable(), LockOutcome.failed);
    expect(lock.isEnabled, isFalse);
    expect(prefs.getBool('appLockEnabled'), isFalse);
    expect(device.prompts, hasLength(1));
  });

  test('the lock survives a restart and comes back gated', () async {
    final (_, _, prefs) = await freshLock(seed: {'appLockEnabled': true});
    final lock = AppLock(prefs: prefs, device: _FakeDevice());
    await lock.init();
    expect(lock.isEnabled, isTrue);
    expect(lock.isLocked, isTrue);
  });

  test('the device opening the gate unlocks it', () async {
    final (lock, device, _) = await freshLock(seed: {'appLockEnabled': true});
    expect(lock.isLocked, isTrue);
    expect(await lock.unlock(), LockOutcome.unlocked);
    expect(lock.isLocked, isFalse);
    expect(device.prompts.single, contains('Unlock'));
  });

  test('a failed unlock leaves the gate up', () async {
    final (lock, device, _) = await freshLock(seed: {'appLockEnabled': true});
    device.outcome = LockOutcome.failed;
    expect(await lock.unlock(), LockOutcome.failed);
    expect(lock.isLocked, isTrue, reason: 'a refusal must not open the app');
  });

  test('turning the lock off asks the device, so a phone handed over while '
      'open cannot have its lock quietly removed', () async {
    final (lock, device, prefs) = await freshLock(seed: {'appLockEnabled': true});
    await lock.unlock();
    device.prompts.clear();
    device.outcome = LockOutcome.failed;

    expect(await lock.disable(), LockOutcome.failed);
    expect(lock.isEnabled, isTrue, reason: 'refused, so nothing changed');
    expect(prefs.getBool('appLockEnabled'), isTrue);
    expect(device.prompts, hasLength(1));

    device.outcome = LockOutcome.unlocked;
    expect(await lock.disable(), LockOutcome.unlocked);
    expect(lock.isEnabled, isFalse);
    expect(lock.isLocked, isFalse);
    expect(prefs.getBool('appLockEnabled'), isFalse);
  });

  group('it can never strand the user', () {
    test('a device that can no longer authenticate drops the lock rather '
        'than holding the app shut', () async {
      final (lock, device, prefs) =
          await freshLock(seed: {'appLockEnabled': true});
      // The owner removed their iPhone passcode after turning this on, so the
      // key to this door has ceased to exist.
      device.outcome = LockOutcome.unavailable;
      device.available = false;

      expect(await lock.unlock(), LockOutcome.unavailable);
      expect(lock.isLocked, isFalse, reason: 'the app must open');
      expect(lock.isEnabled, isFalse);
      expect(prefs.getBool('appLockEnabled'), isTrue,
          reason: 'the user\'s choice is not rewritten by the phone');

      // Next launch, still no passcode: open, because the phone is asked.
      final next = AppLock(prefs: prefs, device: device);
      await next.init();
      expect(next.isLocked, isFalse, reason: 'and it stays open next launch');
    });

    test('but a transient error does not throw the lock away', () async {
      final (lock, device, prefs) =
          await freshLock(seed: {'appLockEnabled': true});
      // Reported unavailable, yet the device still says it can authenticate.
      // That is a blip, not a phone with its passcode removed — discarding a
      // lock the user asked for on the strength of it would be wrong.
      device.outcome = LockOutcome.unavailable;
      device.available = true;

      expect(await lock.unlock(), LockOutcome.failed);
      expect(lock.isLocked, isTrue);
      expect(lock.isEnabled, isTrue);
      expect(prefs.getBool('appLockEnabled'), isTrue);
    });

    test('an unavailable device still lets the lock be turned off', () async {
      final (lock, device, _) = await freshLock(seed: {'appLockEnabled': true});
      device.outcome = LockOutcome.unavailable;
      device.available = false;
      expect(await lock.disable(), LockOutcome.unlocked);
      expect(lock.isEnabled, isFalse);
    });

    test('lock() does nothing when the lock is off', () async {
      final (lock, _, _) = await freshLock(seed: {'appLockEnabled': false});
      lock.lock();
      expect(lock.isLocked, isFalse);
    });

    test('preferences failing to load leaves the app open', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final lock = AppLock(device: _FakeDevice());
      // init() is never called, standing in for a store that never loaded.
      expect(lock.isEnabled, isFalse);
      expect(lock.isLocked, isFalse);
    });
  });

  test('the app never holds a secret of its own', () async {
    final (lock, _, prefs) = await freshLock(seed: {'appLockEnabled': false});
    await lock.enable();
    // One boolean, and nothing that could be a passcode, hash or salt.
    expect(prefs.getKeys(), <String>{'appLockEnabled'});
    expect(prefs.get('appLockEnabled'), isA<bool>());
  });

  group('upgrading from the passcode this version replaced', () {
    test('a device that had the old lock keeps it, now on the system one',
        () async {
      final (lock, _, prefs) = await freshLock(seed: <String, Object>{
        'lockHash': 'ZGVhZGJlZWY=',
        'lockSalt': 'c2FsdA==',
        'lockIterations': 120000,
        'lockBiometrics': true,
      });
      expect(lock.isEnabled, isTrue, reason: 'they had asked for a lock');
      expect(lock.isLocked, isTrue);
      expect(prefs.getBool('appLockEnabled'), isTrue);
    });

    test('the old digest is wiped, because the app holds no secret now',
        () async {
      final (_, _, prefs) = await freshLock(seed: <String, Object>{
        'lockHash': 'ZGVhZGJlZWY=',
        'lockSalt': 'c2FsdA==',
        'lockIterations': 120000,
        'lockBiometrics': true,
      });
      for (final String key in <String>[
        'lockHash',
        'lockSalt',
        'lockIterations',
        'lockBiometrics',
      ]) {
        expect(prefs.get(key), isNull, reason: key);
      }
    });

    test('a device that never had the old lock just gets the default',
        () async {
      final (lock, _, prefs) = await freshLock();
      expect(lock.isEnabled, isTrue);
      expect(prefs.getKeys(), isEmpty, reason: 'nothing migrated, nothing written');
    });
  });

  test('the method label is whatever the device says it is', () async {
    final (lock, device, _) = await freshLock();
    device.label = 'Touch ID';
    expect(await lock.methodLabel(), 'Touch ID');
  });


  group('turning itself off is not the user turning it off', () {
    test('a default lock that drops itself is not saved as a choice', () async {
      final (lock, device, prefs) = await freshLock();
      expect(lock.isEnabled, isTrue);

      // The owner removes their iPhone passcode.
      device.outcome = LockOutcome.unavailable;
      device.available = false;
      expect(await lock.unlock(), LockOutcome.unavailable);
      expect(lock.isEnabled, isFalse);
      expect(prefs.getKeys(), isEmpty,
          reason: 'saving false here would make it permanent');

      // They set a passcode again: the default comes back on its own.
      device.available = true;
      final again = AppLock(prefs: prefs, device: device);
      await again.init();
      expect(again.isEnabled, isTrue);
    });

    test('a lock the user switched on comes back once a passcode does',
        () async {
      // The phone losing its passcode is not the user turning the lock off.
      // Saving false here once made a deliberate "on" permanently off, while
      // an untouched default came back — the user who asked for more
      // protection ended up with less.
      final (lock, device, prefs) =
          await freshLock(seed: {'appLockEnabled': true});
      device.outcome = LockOutcome.unavailable;
      device.available = false;
      await lock.unlock();
      expect(lock.isEnabled, isFalse, reason: 'stood down for now');
      expect(prefs.getBool('appLockEnabled'), isTrue,
          reason: 'their choice is untouched');

      device.available = true;
      final again = AppLock(prefs: prefs, device: device);
      await again.init();
      expect(again.isEnabled, isTrue);
    });
  });


  group('the emergency window', () {
    // Two independent clocks, both controllable here. `wall` is what Settings
    // can change; `mono` is time that only moves forward.
    late DateTime wall;
    late Duration mono;

    Future<AppLock> unlockedLock() async {
      wall = DateTime(2026, 10, 4, 12);
      mono = const Duration(hours: 5);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'appLockEnabled': true,
      });
      final lock = AppLock(
        prefs: await SharedPreferences.getInstance(),
        device: _FakeDevice(),
        clock: () => wall,
        monotonic: () => mono,
      );
      await lock.init();
      await lock.unlock();
      return lock;
    }

    void advance(Duration d) {
      wall = wall.add(d);
      mono += d;
    }

    test('after an emergency call the lock stays down, callbacks included',
        () async {
      final lock = await unlockedLock();
      lock.startEmergencyWindow();
      advance(const Duration(minutes: 29));
      lock.lock();
      expect(lock.isLocked, isFalse, reason: 'dispatch calling back at 29 min');

      advance(const Duration(minutes: 2));
      lock.lock();
      expect(lock.isLocked, isTrue, reason: 'back to normal at 31 min');
    });

    test('setting the clock back to before the call opens nothing', () async {
      final lock = await unlockedLock();
      lock.startEmergencyWindow();
      advance(const Duration(hours: 3));
      lock.lock();
      expect(lock.isLocked, isTrue);

      for (final DateTime rolledBack in <DateTime>[
        DateTime(2026, 10, 4, 11, 59),
        DateTime(2020, 1, 1),
      ]) {
        wall = rolledBack;
        lock.lock();
        expect(lock.isLocked, isTrue, reason: 'clock set to $rolledBack');
      }
    });

    test('setting the clock to inside the old window opens nothing', () async {
      // The second attack: read the call time from Recents, set the clock to
      // a few minutes after it. The monotonic clock knows hours have passed.
      final lock = await unlockedLock();
      lock.startEmergencyWindow();
      advance(const Duration(hours: 6));
      wall = DateTime(2026, 10, 4, 12, 5);
      lock.lock();
      expect(lock.isLocked, isTrue);
    });

    test('an honest sleep still ends it, even if the monotonic clock paused',
        () async {
      final lock = await unlockedLock();
      lock.startEmergencyWindow();
      wall = wall.add(const Duration(hours: 2)); // phone asleep: mono stays put
      lock.lock();
      expect(lock.isLocked, isTrue);
    });

    test('nothing about the emergency is written to the phone', () async {
      final lock = await unlockedLock();
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getKeys();
      lock.startEmergencyWindow();
      expect(prefs.getKeys(), before);
    });

    test('a cold start is always locked', () async {
      final lock = await unlockedLock();
      lock.startEmergencyWindow();
      final prefs = await SharedPreferences.getInstance();
      final relaunched = AppLock(prefs: prefs, device: _FakeDevice());
      await relaunched.init();
      expect(relaunched.isLocked, isTrue,
          reason: 'nothing saved can open the gate');
    });

    test('keys from the earlier saved-window versions are cleared', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'appLockEnabled': true,
        'appLockEmergencyUntil': 1,
        'appLockEmergencyStart': 1,
      });
      final prefs = await SharedPreferences.getInstance();
      final lock = AppLock(prefs: prefs, device: _FakeDevice());
      await lock.init();
      expect(prefs.getKeys(), <String>{'appLockEnabled'});
      expect(lock.isLocked, isTrue);
    });
  });

  test('turning the lock off on a spurious "unavailable" does nothing',
      () async {
    // iOS maps errors it does not recognise to NotAvailable. If the phone can
    // still authenticate, that was not the phone losing its passcode.
    final (lock, device, prefs) = await freshLock(seed: {'appLockEnabled': true});
    device.outcome = LockOutcome.unavailable;
    device.available = true;
    expect(await lock.disable(), LockOutcome.failed);
    expect(lock.isEnabled, isTrue);
    expect(prefs.getBool('appLockEnabled'), isTrue);
  });
}

