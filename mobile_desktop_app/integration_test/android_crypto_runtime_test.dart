import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:p2p_chat_app/modules/crypto/data/flutter_secure_key_value_store.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_material.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_service.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_envelope.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_message_service.dart';
import 'package:p2p_chat_app/modules/crypto/domain/message_box.dart';
import 'package:p2p_chat_app/modules/crypto/domain/remote_device_key.dart';
import 'package:p2p_chat_app/modules/crypto/domain/replay_protection.dart';
import 'package:p2p_chat_app/modules/p2p/data/flutter_webrtc_peer_adapter.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';
import 'package:sodium/sodium.dart';

const _platformLabel =
    String.fromEnvironment('RUNTIME_PLATFORM', defaultValue: 'Android');
const _secureStoragePhase =
    String.fromEnvironment('SECURE_STORAGE_PHASE', defaultValue: 'full');
const _runtimeDeviceId = 'android-runtime-test-device';
const _runtimeKey = 'p2p.crypto.device.$_runtimeDeviceId.v1';
const _runtimeMarkerKey = 'p2p.crypto.test.$_runtimeDeviceId.fingerprint';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('$_platformLabel secure storage 可重載同一組 libsodium 裝置金鑰',
      (tester) async {
    final sodium = await SodiumInit.init();
    final store = FlutterSecureKeyValueStore();
    final service = DeviceKeyService(sodium: sodium, store: store);

    if (_secureStoragePhase == 'write') {
      await store.delete(_runtimeKey);
      await store.delete(_runtimeMarkerKey);
      DeviceKeyMaterial? material;
      var persisted = false;
      try {
        material = await service.getOrCreate(_runtimeDeviceId);
        await store.write(_runtimeMarkerKey, material.fingerprint);
        expect(await store.read(_runtimeMarkerKey), material.fingerprint);
        persisted = true;
      } finally {
        material?.dispose();
        if (!persisted) {
          await store.delete(_runtimeKey);
          await store.delete(_runtimeMarkerKey);
        }
      }
      return;
    }

    if (_secureStoragePhase == 'verify') {
      DeviceKeyMaterial? material;
      try {
        final expectedFingerprint = await store.read(_runtimeMarkerKey);
        expect(expectedFingerprint, isNotNull,
            reason: 'The write phase did not persist its marker.');
        material = await service.getOrCreate(_runtimeDeviceId);
        expect(material.fingerprint, expectedFingerprint);
      } finally {
        material?.dispose();
        await store.delete(_runtimeKey);
        await store.delete(_runtimeMarkerKey);
      }
      return;
    }

    if (_secureStoragePhase != 'full') {
      fail('Unsupported SECURE_STORAGE_PHASE: $_secureStoragePhase');
    }

    await store.delete(_runtimeKey);

    final first = await service.getOrCreate(_runtimeDeviceId);
    final second = await service.getOrCreate(_runtimeDeviceId);
    try {
      expect(second.publicKey, orderedEquals(first.publicKey));
      expect(second.secretKey, first.secretKey);
      expect(first.keyId, hasLength(22));
    } finally {
      first.dispose();
      second.dispose();
      await store.delete(_runtimeKey);
    }
  });

  testWidgets('$_platformLabel 真實 crypto_box 拒絕竄改、錯 key、mismatch 與 replay',
      (tester) async {
    final sodium = await SodiumInit.init();
    final pairA = sodium.crypto.box.keyPair();
    final pairB = sodium.crypto.box.keyPair();
    final keyA = DeviceKeyMaterial(
      publicKey: pairA.publicKey,
      secretKey: pairA.secretKey.copy(),
      keyId: 'key-a',
      fingerprint: 'fingerprint-a',
    );
    final keyB = DeviceKeyMaterial(
      publicKey: pairB.publicKey,
      secretKey: pairB.secretKey.copy(),
      keyId: 'key-b',
      fingerprint: 'fingerprint-b',
    );
    pairA.dispose();
    pairB.dispose();

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
    final sender = EncryptedMessageService(
      box: SodiumMessageBox(sodium),
      localKey: keyA,
      localDeviceId: 'device-a',
      remoteKeys: resolver,
      replayProtection: _MemoryReplayProtection(),
    );
    final recipientReplay = _MemoryReplayProtection();
    final recipient = EncryptedMessageService(
      box: SodiumMessageBox(sodium),
      localKey: keyB,
      localDeviceId: 'device-b',
      remoteKeys: resolver,
      replayProtection: recipientReplay,
    );

    try {
      final encrypted = await sender.encrypt('device-b', _message);
      final decrypted = await recipient.decrypt(encrypted);
      expect(decrypted.text, 'native secret');

      final tamperedSource =
          await sender.encrypt('device-b', _messageFor('native-tampered'));
      final tamperedCiphertext = tamperedSource.ciphertext..[0] ^= 1;
      await expectLater(
        recipient.decrypt(_copy(
          tamperedSource,
          ciphertext: tamperedCiphertext,
        )),
        throwsA(_cryptoError('AUTH_FAILED')),
      );
      final wrongKeySource =
          await sender.encrypt('device-b', _messageFor('native-wrong-key'));
      await expectLater(
        recipient.decrypt(_copy(
          wrongKeySource,
          recipientKeyId: 'wrong-key',
        )),
        throwsA(_cryptoError('RECIPIENT_KEY_MISMATCH')),
      );
      final mismatchSource =
          await sender.encrypt('device-b', _messageFor('native-mismatch'));
      await expectLater(
        recipient.decrypt(_copy(mismatchSource, messageId: 'outer-mismatch')),
        throwsA(_cryptoError('INNER_OUTER_MISMATCH')),
      );
      final replaySource =
          await sender.encrypt('device-b', _messageFor('native-replay'));
      await recipient.decrypt(replaySource);
      await expectLater(
        recipient.decrypt(replaySource),
        throwsA(_cryptoError('REPLAY_REJECTED')),
      );
    } finally {
      keyA.dispose();
      keyB.dispose();
    }
  }, skip: _secureStoragePhase != 'full');

  testWidgets('$_platformLabel 真實 WebRTC DataChannel 傳送並解密 sodium envelope',
      (tester) async {
    final sodium = await SodiumInit.init();
    final pairA = sodium.crypto.box.keyPair();
    final pairB = sodium.crypto.box.keyPair();
    final keyA = DeviceKeyMaterial(
      publicKey: pairA.publicKey,
      secretKey: pairA.secretKey.copy(),
      keyId: 'rtc-key-a',
      fingerprint: 'rtc-fingerprint-a',
    );
    final keyB = DeviceKeyMaterial(
      publicKey: pairB.publicKey,
      secretKey: pairB.secretKey.copy(),
      keyId: 'rtc-key-b',
      fingerprint: 'rtc-fingerprint-b',
    );
    pairA.dispose();
    pairB.dispose();
    final resolver = _Resolver({
      'rtc-device-a': RemoteDeviceKey(
        deviceId: 'rtc-device-a',
        keyId: keyA.keyId,
        publicKey: keyA.publicKey,
      ),
      'rtc-device-b': RemoteDeviceKey(
        deviceId: 'rtc-device-b',
        keyId: keyB.keyId,
        publicKey: keyB.publicKey,
      ),
    });
    final sender = EncryptedMessageService(
      box: SodiumMessageBox(sodium),
      localKey: keyA,
      localDeviceId: 'rtc-device-a',
      remoteKeys: resolver,
      replayProtection: _MemoryReplayProtection(),
    );
    final recipient = EncryptedMessageService(
      box: SodiumMessageBox(sodium),
      localKey: keyB,
      localDeviceId: 'rtc-device-b',
      remoteKeys: resolver,
      replayProtection: _MemoryReplayProtection(),
    );
    final initiator = await FlutterWebRtcPeerAdapter.create(true);
    final receiver = await FlutterWebRtcPeerAdapter.create(false);
    final received = Completer<String>();
    final subscriptions = <StreamSubscription<dynamic>>[
      initiator.iceCandidates.listen(receiver.addIceCandidate),
      receiver.iceCandidates.listen(initiator.addIceCandidate),
      receiver.messages.listen((message) {
        if (!received.isCompleted) received.complete(message);
      }),
    ];

    try {
      final offer = await initiator.createOffer();
      final answer = await receiver.acceptOffer(offer);
      await initiator.acceptAnswer(answer);
      final encrypted = await sender.encrypt(
        'rtc-device-b',
        _rtcMessage,
      );
      await _sendWhenOpen(
        initiator,
        jsonEncode(encrypted.toWireJson()),
      );
      final raw = await received.future.timeout(const Duration(seconds: 15));
      expect(raw, isNot(contains('webrtc native secret')));
      final wire = Map<String, Object?>.from(jsonDecode(raw) as Map);
      final decrypted = await recipient.decrypt(
        EncryptedEnvelope.fromWireJson(wire),
      );
      expect(decrypted.text, 'webrtc native secret');
    } finally {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await initiator.close();
      await receiver.close();
      keyA.dispose();
      keyB.dispose();
    }
  }, skip: _secureStoragePhase != 'full');
}

const _message = MessageEnvelope(
  messageId: 'native-message-1',
  conversationId: 'native-conversation-1',
  senderUserId: 'user-a',
  senderDeviceId: 'device-a',
  type: MessageType.text,
  payload: {'text': 'native secret'},
  createdAt: 1,
);

const _rtcMessage = MessageEnvelope(
  messageId: 'rtc-native-message-1',
  conversationId: 'rtc-native-conversation-1',
  senderUserId: 'rtc-user-a',
  senderDeviceId: 'rtc-device-a',
  type: MessageType.text,
  payload: {'text': 'webrtc native secret'},
  createdAt: 1,
);

Future<void> _sendWhenOpen(
  FlutterWebRtcPeerAdapter peer,
  String message,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (true) {
    try {
      await peer.send(message);
      return;
    } on StateError {
      if (DateTime.now().isAfter(deadline)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

MessageEnvelope _messageFor(String messageId) => MessageEnvelope(
      messageId: messageId,
      conversationId: 'native-conversation-1',
      senderUserId: 'user-a',
      senderDeviceId: 'device-a',
      type: MessageType.text,
      payload: const {'text': 'native secret'},
      createdAt: 1,
    );

Matcher _cryptoError(String code) => isA<CryptoMessageException>().having(
      (error) => error.code,
      'code',
      code,
    );

EncryptedEnvelope _copy(
  EncryptedEnvelope source, {
  String? messageId,
  String? recipientKeyId,
  Uint8List? ciphertext,
}) =>
    EncryptedEnvelope(
      senderDeviceId: source.senderDeviceId,
      recipientDeviceId: source.recipientDeviceId,
      senderKeyId: source.senderKeyId,
      recipientKeyId: recipientKeyId ?? source.recipientKeyId,
      messageId: messageId ?? source.messageId,
      nonce: source.nonce,
      ciphertext: ciphertext ?? source.ciphertext,
    );

class _Resolver implements RemoteDeviceKeyResolver {
  _Resolver(this.keys);

  final Map<String, RemoteDeviceKey> keys;

  @override
  Future<RemoteDeviceKey> resolve(String deviceId) async => keys[deviceId]!;
}

class _MemoryReplayProtection implements ReplayProtection {
  final records = <String>{};

  @override
  Future<bool> seen({
    required String senderDeviceId,
    required String messageId,
    required String nonce,
  }) async =>
      records.any((record) {
        final parts = record.split('|');
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
      records.add('$senderDeviceId|$messageId|$nonce');
}
