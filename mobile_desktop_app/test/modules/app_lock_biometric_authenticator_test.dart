import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:p2p_chat_app/modules/app_lock/data/local_auth_app_lock_biometric_authenticator.dart';
import 'package:p2p_chat_app/modules/app_lock/domain/app_lock_biometric_authenticator.dart';

void main() {
  late LocalAuthPlatform originalPlatform;
  late _FakeLocalAuthPlatform platform;

  setUp(() {
    originalPlatform = LocalAuthPlatform.instance;
    platform = _FakeLocalAuthPlatform();
    LocalAuthPlatform.instance = platform;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    LocalAuthPlatform.instance = originalPlatform;
    debugDefaultTargetPlatformOverride = null;
  });

  test('reports Android biometric hardware availability', () async {
    final authenticator = LocalAuthAppLockBiometricAuthenticator();

    expect(await authenticator.isAvailable(), isTrue);
    platform.supportsBiometrics = false;
    expect(await authenticator.isAvailable(), isFalse);
  });

  test('requires biometric-only sticky authentication', () async {
    final authenticator = LocalAuthAppLockBiometricAuthenticator();

    expect(
      await authenticator.authenticate(reason: 'Unlock messenger'),
      AppLockBiometricResult.success,
    );
    expect(platform.reason, 'Unlock messenger');
    expect(platform.options?.biometricOnly, isTrue);
    expect(platform.options?.stickyAuth, isTrue);
    expect(platform.options?.useErrorDialogs, isFalse);
  });

  test('maps cancellation results without unlocking', () async {
    final authenticator = LocalAuthAppLockBiometricAuthenticator();
    platform.authenticated = false;
    expect(
      await authenticator.authenticate(reason: 'Unlock'),
      AppLockBiometricResult.cancelled,
    );

    platform.error = const LocalAuthException(
      code: LocalAuthExceptionCode.userCanceled,
    );
    expect(
      await authenticator.authenticate(reason: 'Unlock'),
      AppLockBiometricResult.cancelled,
    );
  });

  test('maps structured local authentication errors', () async {
    final authenticator = LocalAuthAppLockBiometricAuthenticator();

    platform.error = const LocalAuthException(
      code: LocalAuthExceptionCode.noBiometricsEnrolled,
    );
    expect(
      await authenticator.authenticate(reason: 'Unlock'),
      AppLockBiometricResult.notEnrolled,
    );

    platform.error = const LocalAuthException(
      code: LocalAuthExceptionCode.temporaryLockout,
    );
    expect(
      await authenticator.authenticate(reason: 'Unlock'),
      AppLockBiometricResult.lockedOut,
    );

    platform.error = const LocalAuthException(
      code: LocalAuthExceptionCode.noBiometricHardware,
    );
    expect(
      await authenticator.authenticate(reason: 'Unlock'),
      AppLockBiometricResult.unavailable,
    );

    platform.error = const LocalAuthException(
      code: LocalAuthExceptionCode.deviceError,
    );
    expect(
      await authenticator.authenticate(reason: 'Unlock'),
      AppLockBiometricResult.failed,
    );
  });
}

class _FakeLocalAuthPlatform extends LocalAuthPlatform {
  bool supportsBiometrics = true;
  bool authenticated = true;
  LocalAuthException? error;
  String? reason;
  AuthenticationOptions? options;

  @override
  Future<bool> deviceSupportsBiometrics() async => supportsBiometrics;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    final error = this.error;
    if (error != null) throw error;
    reason = localizedReason;
    this.options = options;
    return authenticated;
  }
}
