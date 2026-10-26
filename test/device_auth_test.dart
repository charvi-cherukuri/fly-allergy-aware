import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
// local_auth's own platform interface, needed only to match the signature of
// the class this fake stands in for. Test-only, and always present with it.
// ignore: depend_on_referenced_packages
import 'package:local_auth_platform_interface/types/auth_messages.dart';
import 'package:flutter/services.dart';
import 'package:trace_allergy/services/app_lock.dart';

/// Stands in for the plugin, recording the options the app asks for.
class _FakeLocalAuth implements LocalAuthentication {
  _FakeLocalAuth({this.supported = true, this.result = true, this.throws});

  bool supported;
  bool result;
  PlatformException? throws;
  List<BiometricType> enrolled = <BiometricType>[BiometricType.face];

  AuthenticationOptions? lastOptions;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    lastOptions = options;
    final PlatformException? error = throws;
    if (error != null) throw error;
    return result;
  }

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => enrolled;

  @override
  Future<bool> get canCheckBiometrics async => enrolled.isNotEmpty;

  @override
  Future<bool> stopAuthentication() async => true;

}

/// The one that bit: with local_auth's default `useErrorDialogs: true`, its iOS
/// plugin catches `passcodeNotSet` itself, shows a "Go to Settings" alert and
/// reports a plain failure — the error code never reaches Dart. An app that
/// only watches for the code would hold its gate shut against a phone that
/// cannot open it, with no way back in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the app opts out of the plugin error dialogs', () async {
    final fake = _FakeLocalAuth();
    await SystemDeviceAuth(fake).authenticate('why');
    expect(
      fake.lastOptions?.useErrorDialogs,
      isFalse,
      reason: 'otherwise PasscodeNotSet never reaches Dart',
    );
    expect(fake.lastOptions?.biometricOnly, isFalse,
        reason: 'the system passcode sheet is the point');
  });

  test('a plain refusal is a refusal when the device could have asked',
      () async {
    final auth = SystemDeviceAuth(_FakeLocalAuth(result: false));
    expect(await auth.authenticate('why'), LockOutcome.failed);
  });

  test('a plain refusal from a device that cannot ask is unavailable, not a '
      'refusal — this is the case the plugin hides', () async {
    final auth =
        SystemDeviceAuth(_FakeLocalAuth(result: false, supported: false));
    expect(await auth.authenticate('why'), LockOutcome.unavailable);
  });

  test('the dead error codes are treated as unavailable', () async {
    for (final String code in <String>[
      'PasscodeNotSet',
      'NotEnrolled',
      'NotAvailable',
      'BiometricNotAvailable',
      'PermanentlyLockedOut',
    ]) {
      final auth = SystemDeviceAuth(
        _FakeLocalAuth(supported: false, throws: PlatformException(code: code)),
      );
      expect(await auth.authenticate('why'), LockOutcome.unavailable,
          reason: code);
    }
  });

  test('an unknown error on a working device is only a failure', () async {
    final auth = SystemDeviceAuth(
      _FakeLocalAuth(throws: PlatformException(code: 'SomethingElse')),
    );
    expect(await auth.authenticate('why'), LockOutcome.failed);
  });

  test('the label names what the device actually has', () async {
    final fake = _FakeLocalAuth();
    expect(await SystemDeviceAuth(fake).methodLabel(), 'Face ID');

    fake.enrolled = <BiometricType>[BiometricType.fingerprint];
    expect(await SystemDeviceAuth(fake).methodLabel(), 'Touch ID');

    fake.enrolled = <BiometricType>[];
    expect(await SystemDeviceAuth(fake).methodLabel(), 'your passcode',
        reason: 'nothing enrolled, but iOS will still ask for the passcode');
  });
}
