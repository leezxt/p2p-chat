import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../domain/signaling_client.dart';

class WebSocketSignalingClient implements SignalingClient {
  final _messages = StreamController<Map<String, Object?>>.broadcast();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  @override
  Stream<Map<String, Object?>> get messages => _messages.stream;

  @override
  Future<void> connect(
      {required String url,
      required String token,
      required String deviceId}) async {
    await close();
    final socket = await WebSocket.connect(url);
    _socket = socket;
    _subscription = socket.listen((raw) {
      final decoded = jsonDecode(raw as String);
      if (decoded is Map) _messages.add(Map<String, Object?>.from(decoded));
    }, onError: _messages.addError);
    socket.add(jsonEncode({
      'schemaVersion': 1,
      'type': 'AUTH',
      'deviceId': deviceId,
      'token': token
    }));
  }

  @override
  void send(Map<String, Object?> message) => _socket?.add(jsonEncode(message));
  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _socket?.close();
    _subscription = null;
    _socket = null;
  }

  @override
  Future<void> dispose() async {
    await close();
    await _messages.close();
  }
}
