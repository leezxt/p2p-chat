abstract class ReplayProtection {
  Future<bool> seen({
    required String senderDeviceId,
    required String messageId,
    required String nonce,
  });

  Future<bool> acceptOnce({
    required String senderDeviceId,
    required String messageId,
    required String nonce,
    required int receivedAt,
  });
}
