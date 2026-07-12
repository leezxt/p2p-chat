import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/modules/chat/events/chat_events.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_envelope.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_message_service.dart';
import 'package:p2p_chat_app/modules/p2p/domain/p2p_session_manager.dart';
import 'package:p2p_chat_app/modules/p2p/domain/peer_adapter.dart';
import 'package:p2p_chat_app/modules/signaling/domain/signaling_client.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';
import 'package:p2p_chat_app/shared/utils/id_generator.dart';

void main() {
  test('兩個獨立裝置經 offer/answer 後以 DataChannel 傳送文字 envelope', () async {
    final signaling = _SignalingHub();
    final peers = _PeerNetwork();
    final busA = EventBus();
    final busB = EventBus();
    final ciphers = _CipherHub();
    final a = P2pSessionManager(
        signaling: signaling.client('device-a'),
        peerFactory: (id, initiator) => peers.create(id, 'device-a'),
        eventBus: busA,
        ids: IdGenerator(),
        localDeviceId: 'device-a',
        messageCipher: ciphers.forDevice('device-a'))
      ..start();
    final b = P2pSessionManager(
        signaling: signaling.client('device-b'),
        peerFactory: (id, initiator) => peers.create(id, 'device-b'),
        eventBus: busB,
        ids: IdGenerator(),
        localDeviceId: 'device-b',
        messageCipher: ciphers.forDevice('device-b'))
      ..start();
    final received = Completer<MessageEnvelope>();
    busB.on<MessageReceived>((event) => received.complete(event.message));
    await a.connect('device-b');
    await Future<void>.delayed(Duration.zero);
    const message = MessageEnvelope(
        messageId: 'm1',
        conversationId: 'c1',
        senderUserId: 'user-a',
        senderDeviceId: 'device-a',
        type: MessageType.text,
        payload: {'text': 'hello peer'},
        createdAt: 1);
    await a.sendMessage('device-b', message);
    expect((await received.future.timeout(const Duration(seconds: 1))).text,
        'hello peer');
    await a.dispose();
    await b.dispose();
  });
}

class _CipherHub {
  final messages = <String, MessageEnvelope>{};

  MessageCipher forDevice(String deviceId) => _TestCipher(this, deviceId);
}

class _TestCipher implements MessageCipher {
  _TestCipher(this.hub, this.localDeviceId);

  final _CipherHub hub;
  final String localDeviceId;

  @override
  Future<EncryptedEnvelope> encrypt(
    String recipientDeviceId,
    MessageEnvelope message,
  ) async {
    hub.messages[message.messageId] = message;
    return EncryptedEnvelope(
      senderDeviceId: localDeviceId,
      recipientDeviceId: recipientDeviceId,
      senderKeyId: 'key-$localDeviceId',
      recipientKeyId: 'key-$recipientDeviceId',
      messageId: message.messageId,
      nonce: Uint8List(24),
      ciphertext: Uint8List.fromList(List.filled(16, 1)),
    );
  }

  @override
  Future<MessageEnvelope> decrypt(EncryptedEnvelope envelope) async =>
      hub.messages[envelope.messageId]!;
}

class _SignalingHub {
  final Map<String, _MemorySignal> clients = {};
  _MemorySignal client(String id) =>
      clients.putIfAbsent(id, () => _MemorySignal(id, this));
  void relay(String sender, Map<String, Object?> message) {
    final target = message['targetDeviceId'] as String;
    clients[target]!._controller.add({...message, 'senderDeviceId': sender});
  }
}

class _MemorySignal implements SignalingClient {
  _MemorySignal(this.id, this.hub);
  final String id;
  final _SignalingHub hub;
  final _controller = StreamController<Map<String, Object?>>.broadcast();
  @override
  Stream<Map<String, Object?>> get messages => _controller.stream;
  @override
  Future<void> connect(
      {required String url,
      required String token,
      required String deviceId}) async {}
  @override
  void send(Map<String, Object?> message) => hub.relay(id, message);
  @override
  Future<void> close() async {}
  @override
  Future<void> dispose() => _controller.close();
}

class _PeerNetwork {
  final Map<String, List<_FakePeer>> sessions = {};
  Future<PeerAdapter> create(String session, String device) async {
    final peer = _FakePeer(session, device, this);
    sessions.putIfAbsent(session, () => []).add(peer);
    return peer;
  }

  void deliver(_FakePeer sender, String message) {
    sessions[sender.session]!
        .firstWhere((p) => p != sender)
        ._messages
        .add(message);
  }
}

class _FakePeer implements PeerAdapter {
  _FakePeer(this.session, this.device, this.network);
  final String session;
  final String device;
  final _PeerNetwork network;
  final _ice = StreamController<Map<String, Object?>>.broadcast();
  final _messages = StreamController<String>.broadcast();
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
  Future<void> send(String message) async => network.deliver(this, message);
  @override
  Future<void> close() async {
    await _ice.close();
    await _messages.close();
  }
}
