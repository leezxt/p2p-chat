import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/chat/data/chat_repository.dart';
import 'package:p2p_chat_app/modules/chat/data/chat_sqflite_dao.dart';
import 'package:p2p_chat_app/modules/crypto/data/sqlite_replay_protection.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_envelope.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_message_service.dart';
import 'package:p2p_chat_app/modules/mailbox/data/sqlite_mailbox_receipts.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_ack.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_client.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_sync_service.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('restart after lost ACK preserves one message and resends delivery ACK',
      () async {
    final directory = await Directory.systemTemp.createTemp('p2p_restart_');
    final client = _MailboxClient(failAcks: 1);
    DatabaseService? database;
    try {
      database = await _openDatabase(directory.path);
      final first = _syncService(database, client);

      await expectLater(first.syncIncoming(), throwsStateError);
      expect(await _count(database, 'chat_messages'), 1);
      expect(await _count(database, 'crypto_replay_records'), 1);
      expect(await _count(database, 'mailbox_receipts'), 1);
      await database.close();

      database = await _openDatabase(directory.path);
      final restarted = _syncService(database, client);
      await restarted.syncIncoming();

      expect(await _count(database, 'chat_conversations'), 1);
      expect(await _count(database, 'chat_messages'), 1);
      expect(await _count(database, 'crypto_replay_records'), 1);
      expect(await _count(database, 'mailbox_receipts'), 1);
      expect(client.ackAttempts, 2);
      expect(client.acks, hasLength(1));
      expect(client.acks.single.status, MailboxDeliveryState.delivered);

      final repository = ChatRepository(
        ChatSqfliteDao(database.db),
        EventBus(),
      );
      final messages = await repository.loadRecentMessages(
        _message.conversationId,
        limit: 50,
      );
      expect(messages, hasLength(1));
      expect(messages.single.messageId, _message.messageId);
    } finally {
      await database?.close();
      await directory.delete(recursive: true);
    }
  });
}

Future<DatabaseService> _openDatabase(String directory) async {
  final database = DatabaseService(
    databaseFactory: databaseFactoryFfi,
    logger: LoggingService(),
    fileName: 'restart.db',
  );
  await database.open(directoryPath: directory);
  return database;
}

MailboxSyncService _syncService(
  DatabaseService database,
  _MailboxClient client,
) {
  final repository = ChatRepository(ChatSqfliteDao(database.db), EventBus());
  return MailboxSyncService(
    client: client,
    cipher: _PersistentReplayCipher(database),
    receipts: SqliteMailboxReceipts(database.db),
    localDeviceId: 'device-b',
    saveIncoming: repository.saveIncomingMessage,
    updateStatus: repository.updateStatus,
    clock: () => 100,
  );
}

Future<int> _count(DatabaseService database, String table) async {
  final rows =
      await database.db.rawQuery('SELECT COUNT(*) AS count FROM $table');
  return rows.single['count'] as int;
}

final _encrypted = EncryptedEnvelope(
  senderDeviceId: 'device-a',
  recipientDeviceId: 'device-b',
  senderKeyId: 'key-a',
  recipientKeyId: 'key-b',
  messageId: 'message-restart-1',
  nonce: Uint8List.fromList(List<int>.generate(24, (index) => index)),
  ciphertext: Uint8List(16),
);

const _message = MessageEnvelope(
  messageId: 'message-restart-1',
  conversationId: 'conversation-restart-1',
  senderUserId: 'user-a',
  senderDeviceId: 'device-a',
  type: MessageType.text,
  payload: {'text': 'survives restart'},
  createdAt: 1,
);

class _PersistentReplayCipher implements MessageCipher {
  _PersistentReplayCipher(DatabaseService database)
      : _replay = SqliteReplayProtection(database.db);

  final SqliteReplayProtection _replay;

  @override
  Future<MessageEnvelope> decrypt(EncryptedEnvelope envelope) async {
    final accepted = await _replay.acceptOnce(
      senderDeviceId: envelope.senderDeviceId,
      messageId: envelope.messageId,
      nonce: base64Encode(envelope.nonce),
      receivedAt: 100,
    );
    if (!accepted) {
      throw const CryptoMessageException('REPLAY_REJECTED');
    }
    return _message;
  }

  @override
  Future<EncryptedEnvelope> encrypt(
    String recipientDeviceId,
    MessageEnvelope message,
  ) =>
      throw UnimplementedError();
}

class _MailboxClient implements MailboxClient {
  _MailboxClient({required this.failAcks});

  int failAcks;
  int ackAttempts = 0;
  final List<MailboxAck> acks = [];

  @override
  Future<List<MailboxDownload>> pull(String deviceId) async => [
        MailboxDownload(
          mailboxMessageId: 'mailbox-restart-1',
          envelope: _encrypted,
        ),
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
    String senderDeviceId,
  ) async =>
      const [];

  @override
  Future<void> upload(EncryptedEnvelope envelope) async {}
}
