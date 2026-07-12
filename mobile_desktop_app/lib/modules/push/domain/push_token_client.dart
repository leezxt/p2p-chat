enum PushProvider {
  fcm,
  apns;

  String get wire => name.toUpperCase();
}

abstract class PushTokenClient {
  Future<void> register({
    required String deviceId,
    required PushProvider provider,
    required String token,
  });

  Future<void> revoke({
    required String deviceId,
    required PushProvider provider,
  });
}
