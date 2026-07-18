import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

import '../domain/app_lock_biometric_authenticator.dart';

class LocalAuthAppLockBiometricAuthenticator
    implements AppLockBiometricAuthenticator {
  LocalAuthAppLockBiometricAuthenticator({LocalAuthentication? authentication})
      : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> isAvailable() async {
    if (!_isSupportedPlatform) return false;
    try {
      if (!await _authentication.canCheckBiometrics) return false;
      // Android API < 29 cannot reliably enumerate non-fingerprint sensors.
      if (defaultTargetPlatform == TargetPlatform.android) return true;
      return (await _authentication.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<AppLockBiometricResult> authenticate({required String reason}) async {
    if (!_isSupportedPlatform) return AppLockBiometricResult.unavailable;
    try {
      final authenticated = await _authentication.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: false,
        ),
      );
      return authenticated
          ? AppLockBiometricResult.success
          : AppLockBiometricResult.cancelled;
    } on PlatformException catch (error) {
      return switch (error.code) {
        auth_error.notAvailable ||
        auth_error.otherOperatingSystem ||
        auth_error.biometricOnlyNotSupported =>
          AppLockBiometricResult.unavailable,
        auth_error.notEnrolled ||
        auth_error.passcodeNotSet =>
          AppLockBiometricResult.notEnrolled,
        auth_error.lockedOut ||
        auth_error.permanentlyLockedOut =>
          AppLockBiometricResult.lockedOut,
        _ => AppLockBiometricResult.failed,
      };
    }
  }
}
