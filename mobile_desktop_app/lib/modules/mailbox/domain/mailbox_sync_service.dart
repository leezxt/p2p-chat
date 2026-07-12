import '../../../shared/models/message_status.dart';
import '../../../shared/models/message_envelope.dart';
import '../../crypto/domain/encrypted_message_service.dart';
import '../data/sqlite_mailbox_receipts.dart';
import 'mailbox_ack.dart';
import 'mailbox_client.dart';

class MailboxSyncService {
  MailboxSyncService({
    required MailboxClient client,
    required MessageCipher cipher,
    required SqliteMailboxReceipts receipts,
    required this.localDeviceId,
    required Future<void> Function(MessageEnvelope message) saveIncoming,
    required Future<void> Function(String, MessageStatus) updateStatus,
    int Function()? clock,
  })  : _client = client,
        _cipher = cipher,
        _receipts = receipts,
        _saveIncoming = saveIncoming,
        _updateStatus = updateStatus,
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch ~/ 1000);

  final MailboxClient _client;
  final MessageCipher _cipher;
  final SqliteMailboxReceipts _receipts;
  final String localDeviceId;
  final Future<void> Function(MessageEnvelope message) _saveIncoming;
  final Future<void> Function(String, MessageStatus) _updateStatus;
  final int Function() _clock;

  Future<void> syncIncoming() async {
    for (final download in await _client.pull(localDeviceId)) {
      try {
        final message = await _cipher.decrypt(download.envelope);
        await _saveIncoming(message);
      } on CryptoMessageException catch (error) {
        if (error.code != 'REPLAY_REJECTED') rethrow;
      }
      final ack = MailboxAck(
        mailboxMessageId: download.mailboxMessageId,
        messageId: download.envelope.messageId,
        acknowledgingDeviceId: localDeviceId,
        status: MailboxDeliveryState.delivered,
        occurredAt: _clock(),
      );
      await _receipts.save(
        messageId: ack.messageId,
        mailboxMessageId: ack.mailboxMessageId,
        deviceId: localDeviceId,
        status: ack.status,
        now: _clock(),
      );
      await _client.acknowledge(ack);
    }
  }

  Future<void> markRead(String messageId) async {
    final receipt = await _receipts.find(messageId);
    if (receipt == null) return;
    final ack = MailboxAck(
      mailboxMessageId: receipt['mailbox_message_id'] as String,
      messageId: messageId,
      acknowledgingDeviceId: localDeviceId,
      status: MailboxDeliveryState.read,
      occurredAt: _clock(),
    );
    await _client.acknowledge(ack);
    await _receipts.save(
      messageId: messageId,
      mailboxMessageId: ack.mailboxMessageId,
      deviceId: localDeviceId,
      status: ack.status,
      now: _clock(),
    );
  }

  Future<void> syncSenderStatuses() async {
    for (final remote in await _client.fetchStatuses(localDeviceId)) {
      final status = switch (remote.status) {
        MailboxDeliveryState.stored => MessageStatus.stored,
        MailboxDeliveryState.delivered => MessageStatus.delivered,
        MailboxDeliveryState.read => MessageStatus.read,
        MailboxDeliveryState.expired => MessageStatus.expired,
      };
      await _updateStatus(remote.messageId, status);
    }
  }
}
