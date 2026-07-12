import '../../crypto/domain/encrypted_envelope.dart';
import 'mailbox_ack.dart';
import 'mailbox_uploader.dart';

class MailboxDownload {
  const MailboxDownload({
    required this.mailboxMessageId,
    required this.envelope,
  });
  final String mailboxMessageId;
  final EncryptedEnvelope envelope;
}

class MailboxRemoteStatus {
  const MailboxRemoteStatus({required this.messageId, required this.status});
  final String messageId;
  final MailboxDeliveryState status;
}

abstract class MailboxClient implements MailboxUploader {
  Future<List<MailboxDownload>> pull(String deviceId);
  Future<void> acknowledge(MailboxAck ack);
  Future<List<MailboxRemoteStatus>> fetchStatuses(String senderDeviceId);
}
