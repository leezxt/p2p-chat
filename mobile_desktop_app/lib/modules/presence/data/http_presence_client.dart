import 'dart:convert';
import 'dart:io';

import '../domain/presence_client.dart';

class HttpPresenceClient implements PresenceClient {
  HttpPresenceClient({required this.baseUrl, required this.accessToken});

  final String baseUrl;
  final String accessToken;

  @override
  Future<void> heartbeat(String deviceId) async {
    final response =
        await _request('POST', '/api/v1/presence/$deviceId/heartbeat');
    if (response.statusCode != HttpStatus.noContent) {
      throw HttpException('Presence heartbeat failed (${response.statusCode})');
    }
  }

  @override
  Future<List<ContactPresence>> fetchContacts() async {
    final response = await _request('GET', '/api/v1/presence/contacts');
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Presence contacts failed (${response.statusCode})');
    }
    final items = jsonDecode(response.body) as List<dynamic>;
    return items.map((item) {
      final value = item as Map<String, dynamic>;
      final lastSeen = value['lastSeenAt'] as String?;
      return ContactPresence(
        userId: value['userId'] as String,
        deviceId: value['deviceId'] as String?,
        lastSeenAt: lastSeen == null ? null : DateTime.parse(lastSeen),
      );
    }).toList(growable: false);
  }

  Future<_Response> _request(String method, String path) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      final response = await request.close();
      return _Response(
          response.statusCode, await utf8.decoder.bind(response).join());
    } finally {
      client.close(force: true);
    }
  }
}

class _Response {
  const _Response(this.statusCode, this.body);
  final int statusCode;
  final String body;
}
