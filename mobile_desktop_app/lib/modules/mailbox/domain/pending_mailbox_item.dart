class PendingMailboxItem {
  const PendingMailboxItem({
    required this.id,
    required this.messageId,
    required this.recipientDeviceId,
    required this.encryptedEnvelopeJson,
    required this.attemptCount,
  });

  final String id;
  final String messageId;
  final String recipientDeviceId;
  final String encryptedEnvelopeJson;
  final int attemptCount;
}
