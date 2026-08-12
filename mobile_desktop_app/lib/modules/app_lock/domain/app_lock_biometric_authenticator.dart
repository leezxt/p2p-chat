enum AppLockBiometricResult {
  success,
  cancelled,
  unavailable,
  notEnrolled,
  lockedOut,
  failed,
  configurationError,
}

abstract interface class AppLockBiometricAuthenticator {
  Future<bool> isAvailable();

  Future<AppLockBiometricResult> authenticate({required String reason});
}
