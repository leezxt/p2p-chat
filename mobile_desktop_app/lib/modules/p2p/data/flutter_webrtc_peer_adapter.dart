import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../domain/peer_adapter.dart';

class FlutterWebRtcPeerAdapter implements PeerAdapter {
  FlutterWebRtcPeerAdapter._(this._peer, this._channel);
  final RTCPeerConnection _peer;
  RTCDataChannel? _channel;
  Completer<void> _ready = Completer<void>();
  final _ice = StreamController<Map<String, Object?>>.broadcast();
  final _messages = StreamController<String>.broadcast();

  static Future<FlutterWebRtcPeerAdapter> create(bool initiator) async {
    final peer = await createPeerConnection(
        {'iceServers': <Object>[]}, {'sdpSemantics': 'unified-plan'});
    RTCDataChannel? channel;
    if (initiator) {
      channel = await peer.createDataChannel('messages', RTCDataChannelInit());
    }
    final adapter = FlutterWebRtcPeerAdapter._(peer, channel);
    peer.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        final rawCandidate = candidate.toMap();
        if (rawCandidate is Map) {
          adapter._ice.add(Map<String, Object?>.from(rawCandidate));
        }
      }
    };
    peer.onDataChannel = adapter._bindChannel;
    if (channel != null) adapter._bindChannel(channel);
    return adapter;
  }

  void _bindChannel(RTCDataChannel channel) {
    _channel = channel;
    if (_ready.isCompleted) _ready = Completer<void>();
    if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
      _ready.complete();
    }
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen &&
          !_ready.isCompleted) {
        _ready.complete();
      }
    };
    channel.onMessage = (message) {
      if (!message.isBinary) _messages.add(message.text);
    };
  }

  @override
  Stream<Map<String, Object?>> get iceCandidates => _ice.stream;
  @override
  Stream<String> get messages => _messages.stream;
  @override
  Future<Map<String, Object?>> createOffer() async {
    final description = await _peer.createOffer();
    await _peer.setLocalDescription(description);
    return {'sdp': description.sdp, 'type': description.type};
  }

  @override
  Future<Map<String, Object?>> acceptOffer(Map<String, Object?> offer) async {
    await _peer.setRemoteDescription(RTCSessionDescription(
        offer['sdp'] as String?, offer['type'] as String?));
    final answer = await _peer.createAnswer();
    await _peer.setLocalDescription(answer);
    return {'sdp': answer.sdp, 'type': answer.type};
  }

  @override
  Future<void> acceptAnswer(Map<String, Object?> answer) =>
      _peer.setRemoteDescription(RTCSessionDescription(
          answer['sdp'] as String?, answer['type'] as String?));
  @override
  Future<void> addIceCandidate(Map<String, Object?> candidate) =>
      _peer.addCandidate(RTCIceCandidate(candidate['candidate'] as String?,
          candidate['sdpMid'] as String?, candidate['sdpMLineIndex'] as int?));

  @override
  Future<void> waitUntilReady(Duration timeout) async {
    if (_channel?.state == RTCDataChannelState.RTCDataChannelOpen) return;
    await _ready.future.timeout(timeout);
  }

  @override
  Future<void> send(String message) async {
    final channel = _channel;
    if (channel == null ||
        channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('DataChannel is not open');
    }
    await channel.send(RTCDataChannelMessage(message));
  }

  @override
  Future<void> close() async {
    await _channel?.close();
    await _peer.close();
    await _ice.close();
    await _messages.close();
  }
}
