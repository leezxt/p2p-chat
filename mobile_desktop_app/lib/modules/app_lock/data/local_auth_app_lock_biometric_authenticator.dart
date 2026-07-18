import 'package:flutter/foundation.dart';
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
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<AppLockBiometricResult> authenticate({required String reason}) async {
    if (!_isSupportedPlatform) return AppLockBiometricResult.unavailable;
    try {
      final authenticated = await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? AppLockBiometricResult.success
          : AppLockBiometricResult.cancelled;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.uiUnavailable =>
          AppLockBiometricResult.unavailable,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled =>
          AppLockBiometricResult.notEnrolled,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          AppLockBiometricResult.lockedOut,
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback =>
          AppLockBiometricResult.cancelled,
        _ => AppLockBiometricResult.failed,
      };
    }
  }
}
