import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/network/http_backend_api.dart';
import 'package:p2p_chat_app/modules/chat/events/chat_events.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_material.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_message_service.dart';
import 'package:p2p_chat_app/modules/crypto/domain/message_box.dart';
import 'package:p2p_chat_app/modules/crypto/domain/remote_device_key.dart';
import 'package:p2p_chat_app/modules/crypto/domain/replay_protection.dart';
import 'package:p2p_chat_app/modules/identity/domain/identity_session.dart';
import 'package:p2p_chat_app/modules/p2p/data/flutter_webrtc_peer_adapter.dart';
import 'package:p2p_chat_app/modules/p2p/domain/p2p_session_manager.dart';
import 'package:p2p_chat_app/modules/signaling/data/websocket_signaling_client.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';
import 'package:p2p_chat_app/shared/utils/id_generator.dart';
import 'package:sodium/sodium.dart';

const _role = String.fromEnvironment('E2E_ROLE');
const _backendUrl = String.fromEnvironment(
  'E2E_BACKEND_URL',
  defaultValue: 'http://10.0.2.2:8081',
);
const _signalingUrl = String.fromEnvironment(
  'E2E_SIGNALING_URL',
  defaultValue: 'ws://10.0.2.2:8081/ws/signaling',
);
const _userA = '11111111-1111-4111-8111-111111111111';
const _deviceA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _userB = '22222222-2222-4222-8222-222222222222';
const _deviceB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('兩個 Android App process 經 backend signaling 傳送 sodium 密文',
      (tester) async {
    expect(_role, anyOf('sender', 'receiver'));
    final sodium = await SodiumInit.init();
    final pairA = _seedPair(sodium, 0x0a);
    final pairB = _seedPair(sodium, 0x0b);
    final publicA = Uint8List.fromList(pairA.publicKey);
    final publicB = Uint8List.fromList(pairB.publicKey);
    final keyIdA = _keyId(publicA);
    final keyIdB = _keyId(publicB);
    const isSender = _role == 'sender';
    const localDeviceId = isSender ? _deviceA : _deviceB;
    const remoteDeviceId = isSender ? _deviceB : _deviceA;
    final localKey = DeviceKeyMaterial(
      publicKey: isSender ? publicA : publicB,
      secretKey: (isSender ? pairA.secretKey : pairB.secretKey).copy(),
      keyId: isSender ? keyIdA : keyIdB,
      fingerprint: isSender ? 'e2e-fingerprint-a' : 'e2e-fingerprint-b',
    );
    pairA.dispose();
    pairB.dispose();
    final resolver = _Resolver({
      _deviceA: RemoteDeviceKey(
        deviceId: _deviceA,
        keyId: keyIdA,
        publicKey: publicA,
      ),
      _deviceB: RemoteDeviceKey(
        deviceId: _deviceB,
        keyId: keyIdB,
        publicKey: publicB,
      ),
    });
    final cipher = EncryptedMessageService(
      box: SodiumMessageBox(sodium),
      localKey: localKey,
      localDeviceId: localDeviceId,
      remoteKeys: resolver,
      replayProtection: _MemoryReplayProtection(),
    );
    const identity = IdentitySession(
      userId: isSender ? _userA : _userB,
      deviceId: localDeviceId,
    );
    final api = HttpBackendApi(
      baseUrl: _backendUrl,
      localDevKey: 'test-local-dev-key',
    );
    final publicKey = base64UrlEncode(localKey.publicKey).replaceAll('=', '');
    final access = await api.register(
      identity,
      isSender ? 'Android Sender' : 'Android Receiver',
      publicKey: publicKey,
      publicKeyFingerprint: localKey.fingerprint,
    );
    await api.initializeDeviceKey(
      access.token,
      localDeviceId,
      publicKey: publicKey,
      publicKeyFingerprint: localKey.fingerprint,
    );
    await _waitUntilAsync(
      () async => (await api.listContacts(access.token))
          .any((contact) => contact.deviceId == remoteDeviceId),
      const Duration(minutes: 8),
    );
    final signaling = WebSocketSignalingClient();
    final bus = EventBus();
    final rejected = <Object>[];
    final manager = P2pSessionManager(
      signaling: signaling,
      peerFactory: (_, initiator) => FlutterWebRtcPeerAdapter.create(initiator),
      eventBus: bus,
      ids: IdGenerator(),
      localDeviceId: localDeviceId,
      messageCipher: cipher,
      connectionTimeout: const Duration(seconds: 10),
      maxOfferAttempts: 5,
      onMessageRejected: rejected.add,
    )..start();

    try {
      await signaling.connect(
        url: _signalingUrl,
        token: access.token,
        deviceId: localDeviceId,
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      if (isSender) {
        await Future<void>.delayed(const Duration(seconds: 8));
        final sessionId = await manager.connect(remoteDeviceId);
        await _waitUntil(
          () => manager.statusFor(sessionId) == P2pSessionStatus.connected,
          const Duration(seconds: 40),
        );
        await manager.sendMessage(remoteDeviceId, _message);
        await Future<void>.delayed(const Duration(seconds: 3));
        expect(rejected, isEmpty);
      } else {
        final received = Completer<MessageEnvelope>();
        final subscription = bus.on<MessageReceived>((event) {
          if (!received.isCompleted) received.complete(event.message);
        });
        try {
          final message =
              await received.future.timeout(const Duration(seconds: 90));
          expect(message.text, 'two emulator native secret');
          expect(message.senderDeviceId, _deviceA);
          expect(rejected, isEmpty);
        } finally {
          subscription.cancel();
        }
      }
    } finally {
      await manager.dispose();
      localKey.dispose();
    }
  });
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

Future<void> _waitUntil(bool Function() condition, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition was not met');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<void> _waitUntilAsync(
  Future<bool> Function() condition,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Async condition was not met');
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

const _message = MessageEnvelope(
  messageId: 'android-two-emulator-message',
  conversationId: 'android-two-emulator-conversation',
  senderUserId: _userA,
  senderDeviceId: _deviceA,
  type: MessageType.text,
  payload: {'text': 'two emulator native secret'},
  createdAt: 1,
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
