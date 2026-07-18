import 'dart:async';
import 'dart:convert';

import '../../../core/events/event_bus.dart';
import '../../../shared/models/message_envelope.dart';
import '../../../shared/utils/id_generator.dart';
import '../../chat/events/chat_events.dart';
import '../../crypto/domain/encrypted_envelope.dart';
import '../../crypto/domain/encrypted_message_service.dart';
import '../../signaling/domain/signaling_client.dart';
import 'peer_adapter.dart';

enum P2pSessionStatus { connecting, connected, closing, closed, failed }

abstract class EncryptedPeerTransport {
  Future<void> sendEncrypted(
    String targetDeviceId,
    EncryptedEnvelope envelope,
  );
}

class P2pSessionManager implements EncryptedPeerTransport {
  P2pSessionManager({
    required this.signaling,
    required this.peerFactory,
    required this.eventBus,
    required this.ids,
    required this.localDeviceId,
    required this.messageCipher,
    this.connectionTimeout = const Duration(seconds: 10),
    this.maxOfferAttempts = 3,
    this.maxConcurrentSessions = 3,
    this.idleDisconnectAfter = const Duration(minutes: 2),
    this.onMessageRejected,
  })  : assert(maxOfferAttempts > 0),
        assert(maxConcurrentSessions > 0);

  final SignalingClient signaling;
  final PeerAdapterFactory peerFactory;
  final EventBus eventBus;
  final IdGenerator ids;
  final String localDeviceId;
  final MessageCipher messageCipher;
  final Duration connectionTimeout;
  final int maxOfferAttempts;
  int maxConcurrentSessions;
  Duration idleDisconnectAfter;
  final void Function(Object error)? onMessageRejected;
  final Map<String, _Session> _sessions = {};
  final Map<String, P2pSessionStatus> _states = {};
  StreamSubscription<Map<String, Object?>>? _signals;

  int get activeSessionCount => _sessions.length;
  P2pSessionStatus? statusFor(String sessionId) => _states[sessionId];

  void start() {
    _signals ??= signaling.messages.listen(_onSignal);
  }

  Future<String> connect(String targetDeviceId) async {
    if (_sessions.length >= maxConcurrentSessions) {
      throw StateError('P2P session limit reached');
    }
    final id = ids.raw();
    final peer = await peerFactory(id, true);
    final session = _bind(id, targetDeviceId, peer);
    session.offer = await peer.createOffer();
    _sendOffer(id, session);
    return id;
  }

  Future<void> sendMessage(
      String targetDeviceId, MessageEnvelope message) async {
    final session = _sessions.values
        .where((candidate) => candidate.targetDeviceId == targetDeviceId)
        .firstOrNull;
    if (session == null || session.status != P2pSessionStatus.connected) {
      throw StateError('No connected P2P session for target device');
    }
    await session.peer.waitUntilReady(connectionTimeout);
    final encrypted = await messageCipher.encrypt(targetDeviceId, message);
    await sendEncrypted(targetDeviceId, encrypted);
  }

  @override
  Future<void> sendEncrypted(
    String targetDeviceId,
    EncryptedEnvelope encrypted,
  ) async {
    final session = _sessions.values
        .where((candidate) => candidate.targetDeviceId == targetDeviceId)
        .firstOrNull;
    if (session == null || session.status != P2pSessionStatus.connected) {
      throw StateError('No connected P2P session for target device');
    }
    await session.peer.waitUntilReady(connectionTimeout);
    await session.peer.send(jsonEncode(encrypted.toWireJson()));
    _resetIdleTimer(session);
  }

  Future<void> updateResourcePolicy({
    required int maxSessions,
    required Duration idleAfter,
  }) async {
    if (maxSessions <= 0) {
      throw ArgumentError.value(maxSessions, 'maxSessions');
    }
    maxConcurrentSessions = maxSessions;
    idleDisconnectAfter = idleAfter;

    final excess = _sessions.keys.skip(maxSessions).toList();
    for (final id in excess) {
      await closeSession(id);
    }
    for (final session in _sessions.values) {
      if (session.status == P2pSessionStatus.connected) {
        _resetIdleTimer(session);
      }
    }
  }

  Future<void> closeSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) return;
    session.status = P2pSessionStatus.closing;
    _states[sessionId] = session.status;
    _send('CLOSE', sessionId, session.targetDeviceId, const {});
    await _closeOne(sessionId, P2pSessionStatus.closed);
  }

  Future<void> sleep() async {
    for (final id in _sessions.keys.toList()) {
      await closeSession(id);
    }
    await signaling.close();
  }

  Future<void> _onSignal(Map<String, Object?> signal) async {
    final type = signal['type'];
    if (type == 'AUTHENTICATED') return;
    final id = signal['sessionId'];
    if (type == 'ERROR') {
      if (id is String) await _closeOne(id, P2pSessionStatus.failed);
      return;
    }
    final sender = signal['senderDeviceId'];
    if (id is! String || sender is! String) return;
    final payload =
        Map<String, Object?>.from((signal['payload'] as Map?) ?? const {});
    if (type == 'OFFER') {
      await _closeOne(id, P2pSessionStatus.closed);
      if (_sessions.length >= maxConcurrentSessions) {
        _send('CLOSE', id, sender, const {});
        return;
      }
      final peer = await peerFactory(id, false);
      final session = _bind(id, sender, peer);
      final answer = await peer.acceptOffer(payload);
      session.status = P2pSessionStatus.connected;
      _states[id] = session.status;
      _resetIdleTimer(session);
      _send('ANSWER', id, sender, answer);
    } else if (type == 'ANSWER') {
      final session = _sessions[id];
      if (session == null) return;
      await session.peer.acceptAnswer(payload);
      session.timer?.cancel();
      session.status = P2pSessionStatus.connected;
      _states[id] = session.status;
      _resetIdleTimer(session);
    } else if (type == 'ICE_CANDIDATE') {
      await _sessions[id]?.peer.addIceCandidate(payload);
    } else if (type == 'CLOSE') {
      await _closeOne(id, P2pSessionStatus.closed);
    }
  }

  _Session _bind(String id, String target, PeerAdapter peer) {
    final session = _Session(target, peer);
    _sessions[id] = session;
    _states[id] = session.status;
    session.iceSubscription = peer.iceCandidates.listen(
      (ice) => _send('ICE_CANDIDATE', id, target, ice),
    );
    session.messageSubscription = peer.messages.listen(
      (raw) => unawaited(_receiveMessage(session, raw)),
    );
    return session;
  }

  Future<void> _receiveMessage(_Session session, String raw) async {
    try {
      final decoded = Map<String, Object?>.from(jsonDecode(raw) as Map);
      final encrypted = EncryptedEnvelope.fromWireJson(decoded);
      if (encrypted.senderDeviceId != session.targetDeviceId ||
          encrypted.recipientDeviceId != localDeviceId) {
        throw const CryptoMessageException('SESSION_DEVICE_MISMATCH');
      }
      final message = await messageCipher.decrypt(encrypted);
      _resetIdleTimer(session);
      eventBus.emit(MessageReceived(message));
    } catch (error) {
      onMessageRejected?.call(error);
    }
  }

  void _sendOffer(String id, _Session session) {
    final offer = session.offer;
    if (offer == null || !_sessions.containsKey(id)) return;
    session.attempts += 1;
    _send('OFFER', id, session.targetDeviceId, offer);
    session.timer?.cancel();
    session.timer = Timer(connectionTimeout, () {
      unawaited(_onConnectionTimeout(id));
    });
  }

  Future<void> _onConnectionTimeout(String id) async {
    final session = _sessions[id];
    if (session == null || session.status != P2pSessionStatus.connecting) {
      return;
    }
    if (session.attempts < maxOfferAttempts) {
      _sendOffer(id, session);
      return;
    }
    await _closeOne(id, P2pSessionStatus.failed);
  }

  void _send(
      String type, String id, String target, Map<String, Object?> payload) {
    signaling.send({
      'schemaVersion': 1,
      'type': type,
      'sessionId': id,
      'targetDeviceId': target,
      'payload': payload,
    });
  }

  void _resetIdleTimer(_Session session) {
    session.idleTimer?.cancel();
    session.idleTimer = Timer(idleDisconnectAfter, () {
      final id = _sessions.entries
          .where((entry) => identical(entry.value, session))
          .map((entry) => entry.key)
          .firstOrNull;
      if (id != null) unawaited(closeSession(id));
    });
  }

  Future<void> _closeOne(String id, P2pSessionStatus terminalStatus) async {
    final session = _sessions.remove(id);
    if (session == null) return;
    session.timer?.cancel();
    session.idleTimer?.cancel();
    await session.iceSubscription?.cancel();
    await session.messageSubscription?.cancel();
    await session.peer.close();
    session.status = terminalStatus;
    _states[id] = terminalStatus;
  }

  Future<void> dispose() async {
    await sleep();
    await _signals?.cancel();
    _signals = null;
    await signaling.dispose();
  }
}

class _Session {
  _Session(this.targetDeviceId, this.peer);
  final String targetDeviceId;
  final PeerAdapter peer;
  P2pSessionStatus status = P2pSessionStatus.connecting;
  Map<String, Object?>? offer;
  int attempts = 0;
  Timer? timer;
  Timer? idleTimer;
  StreamSubscription<Map<String, Object?>>? iceSubscription;
  StreamSubscription<String>? messageSubscription;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
