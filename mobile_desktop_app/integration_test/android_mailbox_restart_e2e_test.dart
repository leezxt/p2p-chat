import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/core/network/http_backend_api.dart';
import 'package:p2p_chat_app/modules/chat/data/chat_repository.dart';
import 'package:p2p_chat_app/modules/chat/data/chat_sqflite_dao.dart';
import 'package:p2p_chat_app/modules/chat/domain/conversation.dart';
import 'package:p2p_chat_app/modules/crypto/data/sqlite_replay_protection.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_material.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_envelope.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_message_service.dart';
import 'package:p2p_chat_app/modules/crypto/domain/message_box.dart';
import 'package:p2p_chat_app/modules/crypto/domain/remote_device_key.dart';
import 'package:p2p_chat_app/modules/crypto/domain/replay_protection.dart';
import 'package:p2p_chat_app/modules/identity/domain/identity_session.dart';
import 'package:p2p_chat_app/modules/mailbox/data/http_mailbox_uploader.dart';
import 'package:p2p_chat_app/modules/mailbox/data/sqlite_mailbox_receipts.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_ack.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_client.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_sync_service.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_status.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';
import 'package:sodium/sodium.dart';
import 'package:sqflite/sqflite.dart';

const _phase = String.fromEnvironment('E2E_MAILBOX_PHASE');
const _backendUrl = String.fromEnvironment(
  'E2E_BACKEND_URL',
  defaultValue: 'http://10.0.2.2:8081',
);
const _messageKind = String.fromEnvironment(
  'E2E_MAILBOX_MESSAGE_KIND',
  defaultValue: 'text',
);
const _userA = '11111111-1111-4111-8111-111111111111';
const _deviceA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _userB = '22222222-2222-4222-8222-222222222222';
const _deviceB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _dbFile = 'android_mailbox_restart.db';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android mailbox survives process restart and advances ACK state',
      (tester) async {
    expect(
      _phase,
      anyOf(
        'register_sender',
        'register_receiver',
        'sender_upload',
        'receiver_ack_loss',
        'receiver_restart',
      ),
    );
    // 新訊息類型要明確選擇；不能在 Android runtime 將未知值靜默降級為文字。
    expect(_messageKind, anyOf('text', 'sticker'));

    const isSender = _phase == 'register_sender' || _phase == 'sender_upload';
    final crypto = await _createCrypto(isSender: isSender);
    try {
      final token = await _register(crypto, isSender: isSender);
      switch (_phase) {
        case 'register_sender':
        case 'register_receiver':
          return;
        case 'sender_upload':
          await _senderUpload(crypto, token);
        case 'receiver_ack_loss':
          await _receiverAckLoss(crypto, token);
        case 'receiver_restart':
          await _receiverRestart(crypto, token);
      }
    } finally {
      crypto.localKey.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}

Future<String> _register(_CryptoContext crypto,
    {required bool isSender}) async {
  final api = HttpBackendApi(
    baseUrl: _backendUrl,
    localDevKey: 'test-local-dev-key',
  );
  final identity = IdentitySession(
    userId: isSender ? _userA : _userB,
    deviceId: isSender ? _deviceA : _deviceB,
  );
  final publicKey =
      base64UrlEncode(crypto.localKey.publicKey).replaceAll('=', '');
  final access = await api.register(
    identity,
    isSender ? 'Mailbox Sender' : 'Mailbox Receiver',
    publicKey: publicKey,
    publicKeyFingerprint: crypto.localKey.fingerprint,
  );
  await api.initializeDeviceKey(
    access.token,
    identity.deviceId,
    publicKey: publicKey,
    publicKeyFingerprint: crypto.localKey.fingerprint,
  );
  return access.token;
}

Future<void> _senderUpload(_CryptoContext crypto, String token) async {
  await _deleteDatabase();
  final database = await _openDatabase();
  try {
    final repository = _repository(database);
    await repository.createConversation(const Conversation(
      id: 'android-mailbox-conversation',
      title: 'Mailbox Receiver',
      peerUserId: _userB,
      createdAt: 1,
      updatedAt: 1,
    ));
    await repository.saveOutgoingMessage(_message);
    final client =
        HttpMailboxUploader(baseUrl: _backendUrl, accessToken: token);
    await client.upload(await crypto.cipher.encrypt(_deviceB, _message));
    await _sync(database, client, crypto.cipher, _deviceA).syncSenderStatuses();

    final stored = await repository.loadRecentMessages(
      _message.conversationId,
      limit: 10,
    );
    expect(stored, hasLength(1));
    expect(stored.single.type, _message.type);
    expect(stored.single.payload, _message.payload);
    expect(stored.single.status, MessageStatus.stored);
    debugPrint('E2E_MAILBOX_UPLOAD_READY');

    final deadline = DateTime.now().add(const Duration(minutes: 8));
    while (DateTime.now().isBefore(deadline)) {
      await _sync(database, client, crypto.cipher, _deviceA)
          .syncSenderStatuses();
      final messages = await repository.loadRecentMessages(
        _message.conversationId,
        limit: 10,
      );
      if (messages.single.status == MessageStatus.read) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException('Sender did not observe the READ mailbox status');
  } finally {
    await database.close();
  }
}

Future<void> _receiverAckLoss(_CryptoContext crypto, String token) async {
  await _deleteDatabase();
  final database = await _openDatabase();
  final delegate =
      HttpMailboxUploader(baseUrl: _backendUrl, accessToken: token);
  final service = _sync(
    database,
    _RejectAcknowledgementClient(delegate),
    crypto.cipherFor(database),
    _deviceB,
  );

  await expectLater(service.syncIncoming(), throwsStateError);
  expect(await _count(database, 'chat_conversations'), 1);
  expect(await _count(database, 'chat_messages'), 1);
  expect(await _count(database, 'crypto_replay_records'), 1);
  expect(await _count(database, 'mailbox_receipts'), 1);
  debugPrint('E2E_MAILBOX_ACK_LOSS_READY');

  // The runner force-stops this process here to verify SQLite durability without
  // allowing normal test or database teardown to run.
  await Completer<void>().future;
}

Future<void> _receiverRestart(_CryptoContext crypto, String token) async {
  final database = await _openDatabase();
  try {
    final client =
        HttpMailboxUploader(baseUrl: _backendUrl, accessToken: token);
    final service = _sync(
      database,
      client,
      crypto.cipherFor(database),
      _deviceB,
    );
    await service.syncIncoming();
    await service.markRead(_message.messageId);

    expect(await _count(database, 'chat_conversations'), 1);
    expect(await _count(database, 'chat_messages'), 1);
    expect(await _count(database, 'crypto_replay_records'), 1);
    expect(await _count(database, 'mailbox_receipts'), 1);
    final receipt =
        await SqliteMailboxReceipts(database.db).find(_message.messageId);
    expect(receipt?['ack_status'], MailboxDeliveryState.read.wire);
    final messages = await _repository(database).loadRecentMessages(
      _message.conversationId,
      limit: 10,
    );
    expect(messages, hasLength(1));
    // 驗證的是重啟前 SQLite 寫入的完整 schema，不把貼圖 ID 誤當文字 payload。
    expect(messages.single.type, _message.type);
    expect(messages.single.payload, _message.payload);
  } finally {
    await database.close();
  }
}

MailboxSyncService _sync(
  DatabaseService database,
  MailboxClient client,
  MessageCipher cipher,
  String deviceId,
) {
  final repository = _repository(database);
  return MailboxSyncService(
    client: client,
    cipher: cipher,
    receipts: SqliteMailboxReceipts(database.db),
    localDeviceId: deviceId,
    saveIncoming: repository.saveIncomingMessage,
    updateStatus: repository.updateStatus,
  );
}

ChatRepository _repository(DatabaseService database) =>
    ChatRepository(ChatSqfliteDao(database.db), EventBus());

Future<DatabaseService> _openDatabase() async {
  final database = DatabaseService(
    databaseFactory: databaseFactory,
    logger: LoggingService(),
    fileName: _dbFile,
  );
  await database.open();
  return database;
}

Future<void> _deleteDatabase() async {
  final path = p.join(await databaseFactory.getDatabasesPath(), _dbFile);
  await databaseFactory.deleteDatabase(path);
}

Future<int> _count(DatabaseService database, String table) async {
  final rows =
      await database.db.rawQuery('SELECT COUNT(*) AS count FROM $table');
  return rows.single['count'] as int;
}

Future<_CryptoContext> _createCrypto({required bool isSender}) async {
  final sodium = await SodiumInit.init();
  final pairA = _seedPair(sodium, 0x0a);
  final pairB = _seedPair(sodium, 0x0b);
  final publicA = Uint8List.fromList(pairA.publicKey);
  final publicB = Uint8List.fromList(pairB.publicKey);
  final localPublic = isSender ? publicA : publicB;
  final localKey = DeviceKeyMaterial(
    publicKey: localPublic,
    secretKey: (isSender ? pairA.secretKey : pairB.secretKey).copy(),
    keyId: _keyId(localPublic),
    fingerprint: sha256.convert(localPublic).toString(),
  );
  pairA.dispose();
  pairB.dispose();
  final resolver = _Resolver({
    _deviceA: RemoteDeviceKey(
      deviceId: _deviceA,
      keyId: _keyId(publicA),
      publicKey: publicA,
    ),
    _deviceB: RemoteDeviceKey(
      deviceId: _deviceB,
      keyId: _keyId(publicB),
      publicKey: publicB,
    ),
  });
  return _CryptoContext(
      sodium, localKey, resolver, isSender ? _deviceA : _deviceB);
}

KeyPair _seedPair(Sodium sodium, int value) {
  final seed = sodium.secureCopy(Uint8List.fromList(List.filled(32, value)));
  try {
    return sodium.crypto.box.seedKeyPair(seed);
  } finally {
    seed.dispose();
  }
}

String _keyId(Uint8List publicKey) => base64UrlEncode(
      sha256.convert(publicKey).bytes,
    ).replaceAll('=', '').substring(0, 22);

MessageEnvelope get _message => switch (_messageKind) {
      'text' => const MessageEnvelope(
          messageId: 'android-mailbox-restart-message',
          conversationId: 'android-mailbox-conversation',
          senderUserId: _userA,
          senderDeviceId: _deviceA,
          type: MessageType.text,
          payload: {'text': 'survives Android process restart'},
          createdAt: 1,
        ),
      'sticker' => const MessageEnvelope(
          messageId: 'android-mailbox-restart-sticker',
          conversationId: 'android-mailbox-conversation',
          senderUserId: _userA,
          senderDeviceId: _deviceA,
          type: MessageType.sticker,
          payload: {
            'packId': 'simple_communication',
            'stickerId': 'flutter',
          },
          createdAt: 1,
        ),
      _ => throw StateError('Unsupported mailbox message kind: $_messageKind'),
    };

class _CryptoContext {
  _CryptoContext(this.sodium, this.localKey, this.resolver, this.localDeviceId);

  final Sodium sodium;
  final DeviceKeyMaterial localKey;
  final _Resolver resolver;
  final String localDeviceId;

  MessageCipher get cipher => EncryptedMessageService(
        box: SodiumMessageBox(sodium),
        localKey: localKey,
        localDeviceId: localDeviceId,
        remoteKeys: resolver,
        replayProtection: _MemoryReplayProtection(),
      );

  MessageCipher cipherFor(DatabaseService database) => EncryptedMessageService(
        box: SodiumMessageBox(sodium),
        localKey: localKey,
        localDeviceId: localDeviceId,
        remoteKeys: resolver,
        replayProtection: SqliteReplayProtection(database.db),
      );
}

class _Resolver implements RemoteDeviceKeyResolver {
  _Resolver(this.keys);
  final Map<String, RemoteDeviceKey> keys;

  @override
  Future<RemoteDeviceKey> resolve(String deviceId) async => keys[deviceId]!;
}

class _MemoryReplayProtection implements ReplayProtection {
  @override
  Future<bool> seen({
    required String senderDeviceId,
    required String messageId,
    required String nonce,
  }) async =>
      false;

  @override
  Future<bool> acceptOnce({
    required String senderDeviceId,
    required String messageId,
    required String nonce,
    required int receivedAt,
  }) async =>
      true;
}

class _RejectAcknowledgementClient implements MailboxClient {
  _RejectAcknowledgementClient(this.delegate);
  final MailboxClient delegate;

  @override
  Future<void> acknowledge(MailboxAck ack) async {
    throw StateError('Simulated ACK transport loss');
  }

  @override
  Future<List<MailboxRemoteStatus>> fetchStatuses(String senderDeviceId) =>
      delegate.fetchStatuses(senderDeviceId);

  @override
  Future<List<MailboxDownload>> pull(String deviceId) =>
      delegate.pull(deviceId);

  @override
  Future<void> upload(EncryptedEnvelope envelope) => delegate.upload(envelope);
}
