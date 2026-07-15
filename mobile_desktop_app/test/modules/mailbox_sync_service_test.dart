import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/database/migrations.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_envelope.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_message_service.dart';
import 'package:p2p_chat_app/modules/mailbox/data/sqlite_mailbox_receipts.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_ack.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_client.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_sync_service.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_status.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('下載保存後 ACK，重複投遞重送 ACK，READ 與 sender status 冪等同步', () async {
    final directory = await Directory.systemTemp.createTemp('p2p_sync_');
    final database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
      fileName: 'test.db',
    );
    try {
      await database.open(directoryPath: directory.path);
      final client = _Client();
      final cipher = _Cipher();
      final saved = <MessageEnvelope>[];
      final statuses = <MessageStatus>[];
      final service = MailboxSyncService(
        client: client,
        cipher: cipher,
        receipts: SqliteMailboxReceipts(database.db),
        localDeviceId: 'device-b',
        saveIncoming: (message) async => saved.add(message),
        updateStatus: (_, status) async => statuses.add(status),
        clock: () => 100,
      );

      await service.syncIncoming();
      await service.syncIncoming();
      expect(saved, hasLength(1));
      expect(client.acks.map((ack) => ack.status), [
        MailboxDeliveryState.delivered,
        MailboxDeliveryState.delivered,
      ]);

      await service.markRead('message-1');
      expect(client.acks.last.status, MailboxDeliveryState.read);
      await service.syncSenderStatuses();
      expect(statuses, [MessageStatus.delivered, MessageStatus.read]);
      expect(await database.db.getVersion(), kCurrentDbVersion);
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  test('DELIVERED ACK 遺失後重複拉取會重送 ACK 而不重複保存', () async {
    final directory = await Directory.systemTemp.createTemp('p2p_ack_loss_');
    final database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
      fileName: 'test.db',
    );
    try {
      await database.open(directoryPath: directory.path);
      final client = _Client(failAcks: 1);
      final saved = <MessageEnvelope>[];
      final service = MailboxSyncService(
        client: client,
        cipher: _Cipher(),
        receipts: SqliteMailboxReceipts(database.db),
        localDeviceId: 'device-b',
        saveIncoming: (message) async => saved.add(message),
        updateStatus: (_, __) async {},
        clock: () => 100,
      );

      await expectLater(service.syncIncoming(), throwsStateError);
      await service.syncIncoming();

      expect(saved, hasLength(1));
      expect(client.ackAttempts, 2);
      expect(client.acks, hasLength(1));
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}

final _encrypted = EncryptedEnvelope(
  senderDeviceId: 'device-a',
  recipientDeviceId: 'device-b',
  senderKeyId: 'key-a',
  recipientKeyId: 'key-b',
  messageId: 'message-1',
  nonce: Uint8List(24),
  ciphertext: Uint8List(16),
);

const _message = MessageEnvelope(
  messageId: 'message-1',
  conversationId: 'conversation-1',
  senderUserId: 'user-a',
  senderDeviceId: 'device-a',
  type: MessageType.text,
  payload: {'text': 'hello'},
  createdAt: 1,
);

class _Cipher implements MessageCipher {
  var decryptions = 0;
  @override
  Future<MessageEnvelope> decrypt(EncryptedEnvelope envelope) async {
    if (decryptions++ > 0) {
      throw const CryptoMessageException('REPLAY_REJECTED');
    }
    return _message;
  }

  @override
  Future<EncryptedEnvelope> encrypt(
          String recipientDeviceId, MessageEnvelope message) =>
      throw UnimplementedError();
}

class _Client implements MailboxClient {
  _Client({this.failAcks = 0});
  int failAcks;
  int ackAttempts = 0;
  final acks = <MailboxAck>[];

  @override
  Future<List<MailboxDownload>> pull(String deviceId) async => [
        MailboxDownload(mailboxMessageId: 'mailbox-1', envelope: _encrypted),
      ];

  @override
  Future<void> acknowledge(MailboxAck ack) async {
    ackAttempts++;
    if (failAcks > 0) {
      failAcks--;
      throw StateError('ACK lost');
    }
    acks.add(ack);
  }

  @override
  Future<List<MailboxRemoteStatus>> fetchStatuses(
          String senderDeviceId) async =>
      const [
        MailboxRemoteStatus(
          messageId: 'message-1',
          status: MailboxDeliveryState.delivered,
        ),
        MailboxRemoteStatus(
          messageId: 'message-1',
          status: MailboxDeliveryState.read,
        ),
      ];

  @override
  Future<void> upload(EncryptedEnvelope envelope) async {}
}
