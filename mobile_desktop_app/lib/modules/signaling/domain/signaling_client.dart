abstract class SignalingClient {
  Stream<Map<String, Object?>> get messages;
  Future<void> connect(
      {required String url, required String token, required String deviceId});
  void send(Map<String, Object?> message);

  /// 中斷目前連線，但保留 client 供模組重新 activate。
  Future<void> close();

  /// 永久釋放 stream 與底層資源。
  Future<void> dispose();
}
