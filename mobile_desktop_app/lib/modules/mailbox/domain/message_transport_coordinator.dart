import 'dart:convert';

import '../../../shared/models/message_envelope.dart';
import '../../../shared/models/message_status.dart';
import '../../crypto/domain/encrypted_message_service.dart';
import '../../p2p/domain/p2p_session_manager.dart';
import '../data/sqlite_pending_mailbox_queue.dart';
import 'mailbox_uploader.dart';

class MessageTransportCoordinator {
  MessageTransportCoordinator({
    required MessageCipher cipher,
    required EncryptedPeerTransport peer,
    required SqlitePendingMailboxQueue pendingQueue,
    required MailboxUploader mailbox,
    required Future<void> Function(String, MessageStatus) updateStatus,
    int Function()? clock,
  })  : _cipher = cipher,
        _peer = peer,
        _pendingQueue = pendingQueue,
        _mailbox = mailbox,
        _updateStatus = updateStatus,
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch ~/ 1000);

  final MessageCipher _cipher;
  final EncryptedPeerTransport _peer;
  final SqlitePendingMailboxQueue _pendingQueue;
  final MailboxUploader _mailbox;
  final Future<void> Function(String, MessageStatus) _updateStatus;
  final int Function() _clock;

  Future<void> send(String targetDeviceId, MessageEnvelope message) async {
    final encrypted = await _cipher.encrypt(targetDeviceId, message);
    try {
      await _peer.sendEncrypted(targetDeviceId, encrypted);
      await _updateStatus(message.messageId, MessageStatus.sent);
      return;
    } catch (_) {
      final wire = jsonEncode(encrypted.toWireJson());
      await _pendingQueue.enqueue(
        id: message.messageId,
        messageId: message.messageId,
        recipientDeviceId: targetDeviceId,
        encryptedEnvelopeJson: wire,
        now: _clock(),
      );
      await _updateStatus(message.messageId, MessageStatus.pending);
      try {
        await _mailbox.upload(encrypted);
        await _pendingQueue.markSucceeded(message.messageId);
        await _updateStatus(message.messageId, MessageStatus.stored);
      } catch (_) {
        await _pendingQueue.markFailed(
          id: message.messageId,
          errorCode: 'MAILBOX_UPLOAD_FAILED',
          now: _clock(),
        );
        rethrow;
      }
    }
  }
}
