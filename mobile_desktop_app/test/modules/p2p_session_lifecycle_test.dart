import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_envelope.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_message_service.dart';
import 'package:p2p_chat_app/modules/p2p/domain/p2p_session_manager.dart';
import 'package:p2p_chat_app/modules/p2p/domain/peer_adapter.dart';
import 'package:p2p_chat_app/modules/signaling/domain/signaling_client.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';
import 'package:p2p_chat_app/shared/utils/id_generator.dart';

void main() {
  test('連線完成前不可傳送訊息', () async {
    final harness = _Harness();
    final manager = harness.manager();
    final sessionId = await manager.connect('device-b');

    await expectLater(
      manager.sendMessage('device-b', _message),
      throwsStateError,
    );
    expect(manager.statusFor(sessionId), P2pSessionStatus.connecting);
    await manager.dispose();
  });

  test('connected 後 wire payload 只包含 encrypted envelope', () async {
    final harness = _Harness();
    final manager = harness.manager();
    final sessionId = await manager.connect('device-b');
    harness.signaling.emit({
      'type': 'ANSWER',
      'sessionId': sessionId,
      'senderDeviceId': 'device-b',
      'payload': {'sdp': 'answer', 'type': 'answer'},
    });
    await Future<void>.delayed(Duration.zero);

    await manager.sendMessage('device-b', _message);
    final raw = harness.peers.single.sentMessages.single;
    final wire = jsonDecode(raw) as Map<String, dynamic>;
    expect(wire['cryptoVersion'], 1);
    expect(wire.containsKey('payload'), isFalse);
    expect(raw, isNot(contains('hello')));
    await manager.dispose();
  });

  test('offer 逾時會有限次重送，耗盡後標記 failed 並關閉 peer', () async {
    final harness = _Harness();
    final manager = harness.manager(
      connectionTimeout: const Duration(milliseconds: 10),
      maxOfferAttempts: 2,
    );
    final sessionId = await manager.connect('device-b');

    await Future<void>.delayed(const Duration(milliseconds: 35));

    expect(harness.signaling.sent.where((item) => item['type'] == 'OFFER'),
        hasLength(2));
    expect(manager.statusFor(sessionId), P2pSessionStatus.failed);
    expect(manager.activeSessionCount, 0);
    expect(harness.peers.single.closed, isTrue);
    await manager.dispose();
  });

  test('ANSWER 後可傳訊，close 會通知對端並清除 session', () async {
    final harness = _Harness();
    final manager = harness.manager();
    final sessionId = await manager.connect('device-b');
    harness.signaling.emit({
      'type': 'ANSWER',
      'sessionId': sessionId,
      'senderDeviceId': 'device-b',
      'payload': {'sdp': 'answer', 'type': 'answer'},
    });
    await Future<void>.delayed(Duration.zero);

    expect(manager.statusFor(sessionId), P2pSessionStatus.connected);
    await manager.sendMessage('device-b', _message);
    expect(harness.peers.single.sentMessages, hasLength(1));

    await manager.closeSession(sessionId);
    expect(manager.statusFor(sessionId), P2pSessionStatus.closed);
    expect(manager.activeSessionCount, 0);
    expect(harness.peers.single.closed, isTrue);
    expect(harness.signaling.sent.last['type'], 'CLOSE');
    await manager.dispose();
  });

  test('signaling ERROR 會標記 failed 並釋放 peer', () async {
    final harness = _Harness();
    final manager = harness.manager();
    final sessionId = await manager.connect('device-b');

    harness.signaling.emit({
      'type': 'ERROR',
      'sessionId': sessionId,
      'payload': {'code': 'TARGET_OFFLINE'},
    });
    await Future<void>.delayed(Duration.zero);

    expect(manager.statusFor(sessionId), P2pSessionStatus.failed);
    expect(manager.activeSessionCount, 0);
    expect(harness.peers.single.closed, isTrue);
    await manager.dispose();
  });

  test('sleep 關閉 session 與 signaling，之後可重新連線', () async {
    final harness = _Harness();
    final manager = harness.manager();
    await harness.signaling
        .connect(url: 'ws://test', token: 'token', deviceId: 'device-a');
    await manager.connect('device-b');

    await manager.sleep();
    expect(manager.activeSessionCount, 0);
    expect(harness.signaling.connected, isFalse);

    await harness.signaling
        .connect(url: 'ws://test', token: 'token', deviceId: 'device-a');
    final nextSession = await manager.connect('device-c');
    expect(manager.statusFor(nextSession), P2pSessionStatus.connecting);
    expect(harness.signaling.connected, isTrue);
    await manager.dispose();
  });

  test('session limit rejects extra outbound connections', () async {
    final harness = _Harness();
    final manager = harness.manager(maxConcurrentSessions: 1);
    await manager.connect('device-b');

    await expectLater(manager.connect('device-c'), throwsStateError);
    expect(manager.activeSessionCount, 1);
    expect(harness.peers, hasLength(1));
    await manager.dispose();
  });

  test('connected session is released after idle timeout', () async {
    final harness = _Harness();
    final manager = harness.manager(
      idleDisconnectAfter: const Duration(milliseconds: 15),
    );
    final sessionId = await manager.connect('device-b');
    harness.signaling.emit({
      'type': 'ANSWER',
      'sessionId': sessionId,
      'senderDeviceId': 'device-b',
      'payload': {'sdp': 'answer', 'type': 'answer'},
    });
    await Future<void>.delayed(const Duration(milliseconds: 35));

    expect(manager.statusFor(sessionId), P2pSessionStatus.closed);
    expect(manager.activeSessionCount, 0);
    expect(harness.peers.single.closed, isTrue);
    await manager.dispose();
  });

  test('policy update closes sessions above the new limit', () async {
    final harness = _Harness();
    final manager = harness.manager();
    await manager.connect('device-b');
    await manager.connect('device-c');

    await manager.updateResourcePolicy(
      maxSessions: 1,
      idleAfter: const Duration(minutes: 1),
    );

    expect(manager.maxConcurrentSessions, 1);
    expect(manager.activeSessionCount, 1);
    expect(harness.peers.where((peer) => peer.closed), hasLength(1));
    await manager.dispose();
  });
}

const _message = MessageEnvelope(
  messageId: 'm1',
  conversationId: 'c1',
  senderUserId: 'user-a',
  senderDeviceId: 'device-a',
  type: MessageType.text,
  payload: {'text': 'hello'},
  createdAt: 1,
);

class _Harness {
  final signaling = _RecordingSignaling();
  final peers = <_RecordingPeer>[];

  P2pSessionManager manager({
    Duration connectionTimeout = const Duration(seconds: 1),
    int maxOfferAttempts = 3,
    int maxConcurrentSessions = 3,
    Duration idleDisconnectAfter = const Duration(minutes: 2),
  }) {
    return P2pSessionManager(
      signaling: signaling,
      peerFactory: (_, __) async {
        final peer = _RecordingPeer();
        peers.add(peer);
        return peer;
      },
      eventBus: EventBus(),
      ids: IdGenerator(),
      localDeviceId: 'device-a',
      messageCipher: _TestCipher('device-a'),
      connectionTimeout: connectionTimeout,
      maxOfferAttempts: maxOfferAttempts,
      maxConcurrentSessions: maxConcurrentSessions,
      idleDisconnectAfter: idleDisconnectAfter,
    )..start();
  }
}

class _TestCipher implements MessageCipher {
  _TestCipher(this.localDeviceId);

  final String localDeviceId;

  @override
  Future<EncryptedEnvelope> encrypt(
    String recipientDeviceId,
    MessageEnvelope message,
  ) async =>
      EncryptedEnvelope(
        senderDeviceId: localDeviceId,
        recipientDeviceId: recipientDeviceId,
        senderKeyId: 'key-a',
        recipientKeyId: 'key-b',
        messageId: message.messageId,
        nonce: Uint8List(24),
        ciphertext: Uint8List.fromList(List.filled(16, 1)),
      );

  @override
  Future<MessageEnvelope> decrypt(EncryptedEnvelope envelope) async => _message;
}

class _RecordingSignaling implements SignalingClient {
  final _messages = StreamController<Map<String, Object?>>.broadcast();
  final sent = <Map<String, Object?>>[];
  bool connected = false;

  @override
  Stream<Map<String, Object?>> get messages => _messages.stream;

  void emit(Map<String, Object?> message) => _messages.add(message);

  @override
  Future<void> connect(
      {required String url,
      required String token,
      required String deviceId}) async {
    connected = true;
  }

  @override
  void send(Map<String, Object?> message) => sent.add(message);

  @override
  Future<void> close() async {
    connected = false;
  }

  @override
  Future<void> dispose() async {
    await close();
    await _messages.close();
  }
}

class _RecordingPeer implements PeerAdapter {
  final _ice = StreamController<Map<String, Object?>>.broadcast();
  final _messages = StreamController<String>.broadcast();
  final sentMessages = <String>[];
  bool closed = false;

  @override
  Stream<Map<String, Object?>> get iceCandidates => _ice.stream;
  @override
  Stream<String> get messages => _messages.stream;
  @override
  Future<Map<String, Object?>> createOffer() async =>
      {'sdp': 'offer', 'type': 'offer'};
  @override
  Future<Map<String, Object?>> acceptOffer(Map<String, Object?> offer) async =>
      {'sdp': 'answer', 'type': 'answer'};
  @override
  Future<void> acceptAnswer(Map<String, Object?> answer) async {}
  @override
  Future<void> addIceCandidate(Map<String, Object?> candidate) async {}
  @override
  Future<void> waitUntilReady(Duration timeout) async {}
  @override
  Future<void> send(String message) async {
    sentMessages.add(message);
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await _ice.close();
    await _messages.close();
  }
}
