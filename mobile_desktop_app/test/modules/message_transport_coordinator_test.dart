import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_envelope.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_message_service.dart';
import 'package:p2p_chat_app/modules/mailbox/data/sqlite_pending_mailbox_queue.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_uploader.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/message_transport_coordinator.dart';
import 'package:p2p_chat_app/modules/p2p/domain/p2p_session_manager.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_status.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory directory;
  late DatabaseService database;
  late SqlitePendingMailboxQueue queue;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('p2p_transport_');
    database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
      fileName: 'test.db',
    );
    await database.open(directoryPath: directory.path);
    queue = SqlitePendingMailboxQueue(database.db, random: Random(1));
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  MessageTransportCoordinator coordinator(
    _Peer peer,
    _Mailbox mailbox,
    List<MessageStatus> statuses,
  ) =>
      MessageTransportCoordinator(
        cipher: _Cipher(),
        peer: peer,
        pendingQueue: queue,
        mailbox: mailbox,
        updateStatus: (_, status) async => statuses.add(status),
        clock: () => 100,
      );

  test('P2P 成功不寫入 mailbox queue', () async {
    final peer = _Peer();
    final mailbox = _Mailbox();
    final statuses = <MessageStatus>[];
    final transport = coordinator(peer, mailbox, statuses);

    await transport.send('device-b', _message);

    expect(peer.sent, hasLength(1));
    expect(mailbox.uploaded, isEmpty);
    expect(statuses, [MessageStatus.sent]);
    expect(await queue.claimNext(now: 1000), isNull);
  });

  test('P2P 失敗後 mailbox 成功只上傳同一密文並標記 STORED', () async {
    final peer = _Peer(fail: true);
    final mailbox = _Mailbox();
    final statuses = <MessageStatus>[];

    await coordinator(peer, mailbox, statuses).send('device-b', _message);

    expect(mailbox.uploaded, hasLength(1));
    expect(mailbox.uploaded.single.messageId, _message.messageId);
    expect(statuses, [MessageStatus.pending, MessageStatus.stored]);
    expect(await queue.claimNext(now: 1000), isNull);
  });

  test('reaction event 也會經 P2P 失敗後的加密 mailbox fallback', () async {
    final peer = _Peer(fail: true);
    final mailbox = _Mailbox();
    final statuses = <MessageStatus>[];

    await coordinator(peer, mailbox, statuses).send('device-b', _reaction);

    expect(peer.sent.single.messageId, _reaction.messageId);
    expect(mailbox.uploaded.single.messageId, _reaction.messageId);
    expect(statuses, [MessageStatus.pending, MessageStatus.stored]);
  });

  test('P2P 與 mailbox 都失敗時保留 queue 並增加 attempt', () async {
    final peer = _Peer(fail: true);
    final mailbox = _Mailbox(fail: true);
    final statuses = <MessageStatus>[];

    await expectLater(
      coordinator(peer, mailbox, statuses).send('device-b', _message),
      throwsStateError,
    );

    expect(statuses, [MessageStatus.pending]);
    final pending = await queue.claimNext(now: 1000);
    expect(pending, isNotNull);
    expect(pending!.messageId, _message.messageId);
    expect(pending.attemptCount, 1);
    expect(mailbox.uploaded, hasLength(1));
  });
}

const _message = MessageEnvelope(
  messageId: 'message-1',
  conversationId: 'conversation-1',
  senderUserId: 'user-a',
  senderDeviceId: 'device-a',
  type: MessageType.text,
  payload: {'text': 'secret'},
  createdAt: 1,
);

const _reaction = MessageEnvelope(
  messageId: 'reaction-1',
  conversationId: 'conversation-1',
  senderUserId: 'user-a',
  senderDeviceId: 'device-a',
  type: MessageType.reaction,
  payload: {
    'reactionVersion': 1,
    'targetMessageId': 'message-1',
    'emoji': '👍',
    'active': true,
    'updatedAt': 2,
  },
  createdAt: 2,
);

class _Cipher implements MessageCipher {
  @override
  Future<EncryptedEnvelope> encrypt(
    String recipientDeviceId,
    MessageEnvelope message,
  ) async =>
      EncryptedEnvelope(
        senderDeviceId: message.senderDeviceId,
        recipientDeviceId: recipientDeviceId,
        senderKeyId: 'key-a',
        recipientKeyId: 'key-b',
        messageId: message.messageId,
        nonce: Uint8List(24),
        ciphertext: Uint8List(16),
      );

  @override
  Future<MessageEnvelope> decrypt(EncryptedEnvelope envelope) =>
      throw UnimplementedError();
}

class _Peer implements EncryptedPeerTransport {
  _Peer({this.fail = false});
  final bool fail;
  final sent = <EncryptedEnvelope>[];

  @override
  Future<void> sendEncrypted(
    String targetDeviceId,
    EncryptedEnvelope envelope,
  ) async {
    sent.add(envelope);
    if (fail) throw StateError('P2P unavailable');
  }
}

class _Mailbox implements MailboxUploader {
  _Mailbox({this.fail = false});
  final bool fail;
  final uploaded = <EncryptedEnvelope>[];

  @override
  Future<void> upload(EncryptedEnvelope envelope) async {
    uploaded.add(envelope);
    if (fail) throw StateError('Mailbox unavailable');
  }
}
