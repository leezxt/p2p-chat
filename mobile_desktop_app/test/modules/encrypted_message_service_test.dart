import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_material.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_envelope.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_message_service.dart';
import 'package:p2p_chat_app/modules/crypto/domain/message_box.dart';
import 'package:p2p_chat_app/modules/crypto/domain/remote_device_key.dart';
import 'package:p2p_chat_app/modules/crypto/domain/replay_protection.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';
import 'package:sodium/sodium.dart';

void main() {
  late _Harness harness;

  setUp(() => harness = _Harness());
  tearDown(() => harness.dispose());

  test('加密後可由收件裝置解密並保留 MessageEnvelope', () async {
    final encrypted = await harness.sender.encrypt('device-b', _message);
    final decrypted = await harness.recipient.decrypt(encrypted);

    expect(decrypted.messageId, _message.messageId);
    expect(decrypted.text, _message.text);
    expect(encrypted.senderKeyId, harness.keyA.keyId);
    expect(encrypted.recipientKeyId, harness.keyB.keyId);
  });

  test('竄改 ciphertext 會以 AUTH_FAILED 拒絕', () async {
    final encrypted = await harness.sender.encrypt('device-b', _message);
    final tampered = encrypted.ciphertext..[0] ^= 1;

    await expectLater(
      harness.recipient.decrypt(_copy(encrypted, ciphertext: tampered)),
      throwsA(_cryptoError('AUTH_FAILED')),
    );
  });

  test('錯 recipient key 與 sender key 在解密前拒絕', () async {
    final encrypted = await harness.sender.encrypt('device-b', _message);

    await expectLater(
      harness.recipient.decrypt(
        _copy(encrypted, recipientKeyId: 'wrong-recipient-key'),
      ),
      throwsA(_cryptoError('RECIPIENT_KEY_MISMATCH')),
    );
    await expectLater(
      harness.recipient.decrypt(_copy(encrypted, senderKeyId: 'wrong-key')),
      throwsA(_cryptoError('SENDER_KEY_MISMATCH')),
    );
  });

  test('outer message id 與密文內資料不一致時拒絕', () async {
    final encrypted = await harness.sender.encrypt('device-b', _message);

    await expectLater(
      harness.recipient.decrypt(_copy(encrypted, messageId: 'other-message')),
      throwsA(_cryptoError('INNER_OUTER_MISMATCH')),
    );
  });

  test('同一 sender/message/nonce 第二次投遞會拒絕 replay', () async {
    final encrypted = await harness.sender.encrypt('device-b', _message);
    await harness.recipient.decrypt(encrypted);

    await expectLater(
      harness.recipient.decrypt(encrypted),
      throwsA(_cryptoError('REPLAY_REJECTED')),
    );
  });

  test('連續加密不重用 nonce', () async {
    final first = await harness.sender.encrypt('device-b', _message);
    final second = await harness.sender.encrypt(
      'device-b',
      const MessageEnvelope(
        messageId: 'message-2',
        conversationId: 'conversation-1',
        senderUserId: 'user-a',
        senderDeviceId: 'device-a',
        type: MessageType.text,
        payload: {'text': 'another secret'},
        createdAt: 2,
      ),
    );

    expect(second.nonce, isNot(orderedEquals(first.nonce)));
  });
}

Matcher _cryptoError(String code) => isA<CryptoMessageException>().having(
      (error) => error.code,
      'code',
      code,
    );

EncryptedEnvelope _copy(
  EncryptedEnvelope source, {
  String? senderKeyId,
  String? recipientKeyId,
  String? messageId,
  Uint8List? ciphertext,
}) =>
    EncryptedEnvelope(
      senderDeviceId: source.senderDeviceId,
      recipientDeviceId: source.recipientDeviceId,
      senderKeyId: senderKeyId ?? source.senderKeyId,
      recipientKeyId: recipientKeyId ?? source.recipientKeyId,
      messageId: messageId ?? source.messageId,
      nonce: source.nonce,
      ciphertext: ciphertext ?? source.ciphertext,
    );

const _message = MessageEnvelope(
  messageId: 'message-1',
  conversationId: 'conversation-1',
  senderUserId: 'user-a',
  senderDeviceId: 'device-a',
  type: MessageType.text,
  payload: {'text': 'secret text'},
  createdAt: 1,
);

class _Harness {
  _Harness()
      : secretA = _FakeSecureKey(List.filled(32, 0x0a)),
        secretB = _FakeSecureKey(List.filled(32, 0x0b)) {
    keyA = DeviceKeyMaterial(
      publicKey: secretA.extractBytes(),
      secretKey: secretA,
      keyId: 'key-a',
      fingerprint: 'fingerprint-a',
    );
    keyB = DeviceKeyMaterial(
      publicKey: secretB.extractBytes(),
      secretKey: secretB,
      keyId: 'key-b',
      fingerprint: 'fingerprint-b',
    );
    final resolver = _Resolver({
      'device-a': RemoteDeviceKey(
        deviceId: 'device-a',
        keyId: keyA.keyId,
        publicKey: keyA.publicKey,
      ),
      'device-b': RemoteDeviceKey(
        deviceId: 'device-b',
        keyId: keyB.keyId,
        publicKey: keyB.publicKey,
      ),
    });
    sender = EncryptedMessageService(
      box: _FakeMessageBox(),
      localKey: keyA,
      localDeviceId: 'device-a',
      remoteKeys: resolver,
      replayProtection: _MemoryReplayProtection(),
    );
    recipient = EncryptedMessageService(
      box: _FakeMessageBox(),
      localKey: keyB,
      localDeviceId: 'device-b',
      remoteKeys: resolver,
      replayProtection: _MemoryReplayProtection(),
    );
  }

  late final _FakeSecureKey secretA;
  late final _FakeSecureKey secretB;
  late final DeviceKeyMaterial keyA;
  late final DeviceKeyMaterial keyB;
  late final EncryptedMessageService sender;
  late final EncryptedMessageService recipient;

  void dispose() {
    keyA.dispose();
    keyB.dispose();
  }
}

class _FakeMessageBox implements MessageBox {
  var _nonceCounter = 0;

  @override
  int get nonceBytes => 24;

  @override
  int get publicKeyBytes => 32;

  @override
  Uint8List randomNonce() => Uint8List(24)..[23] = _nonceCounter++;

  @override
  Uint8List encrypt({
    required Uint8List message,
    required Uint8List nonce,
    required Uint8List publicKey,
    required SecureKey secretKey,
  }) {
    final tag = _tag(message, nonce, publicKey, secretKey.extractBytes());
    return Uint8List.fromList([...tag, ...message]);
  }

  @override
  Uint8List decrypt({
    required Uint8List ciphertext,
    required Uint8List nonce,
    required Uint8List publicKey,
    required SecureKey secretKey,
  }) {
    if (ciphertext.length < 16) throw StateError('authentication failed');
    final message = Uint8List.fromList(ciphertext.sublist(16));
    final expected = _tag(message, nonce, publicKey, secretKey.extractBytes());
    if (!_equal(ciphertext.sublist(0, 16), expected)) {
      throw StateError('authentication failed');
    }
    return message;
  }

  Uint8List _tag(
    Uint8List message,
    Uint8List nonce,
    Uint8List publicKey,
    Uint8List secretKey,
  ) {
    final shared =
        List.generate(32, (index) => publicKey[index] ^ secretKey[index]);
    return Uint8List.fromList(
      sha256.convert([...message, ...nonce, ...shared]).bytes.take(16).toList(),
    );
  }

  bool _equal(List<int> first, List<int> second) {
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}

class _FakeSecureKey implements SecureKey {
  _FakeSecureKey(List<int> bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;

  @override
  int get length => _bytes.length;

  @override
  SecureKey copy() => _FakeSecureKey(_bytes);

  @override
  void dispose() {
    _bytes.fillRange(0, _bytes.length, 0);
  }

  @override
  Uint8List extractBytes() => Uint8List.fromList(_bytes);

  @override
  FutureOr<T> runUnlockedAsync<T>(
    SecureCallbackFn<FutureOr<T>> callback, {
    bool writable = false,
  }) =>
      callback(_bytes);

  @override
  T runUnlockedSync<T>(
    SecureCallbackFn<T> callback, {
    bool writable = false,
  }) =>
      callback(_bytes);
}

class _Resolver implements RemoteDeviceKeyResolver {
  _Resolver(this.keys);

  final Map<String, RemoteDeviceKey> keys;

  @override
  Future<RemoteDeviceKey> resolve(String deviceId) async => keys[deviceId]!;
}

class _MemoryReplayProtection implements ReplayProtection {
  final accepted = <String>{};

  @override
  Future<bool> seen({
    required String senderDeviceId,
    required String messageId,
    required String nonce,
  }) async =>
      accepted.any((entry) {
        final parts = entry.split('|');
        return parts[0] == senderDeviceId &&
            (parts[1] == messageId || parts[2] == nonce);
      });

  @override
  Future<bool> acceptOnce({
    required String senderDeviceId,
    required String messageId,
    required String nonce,
    required int receivedAt,
  }) async =>
      accepted.add('$senderDeviceId|$messageId|$nonce');
}
