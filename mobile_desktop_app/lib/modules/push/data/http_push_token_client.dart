import 'dart:convert';
import 'dart:io';

import '../domain/push_token_client.dart';

class HttpPushTokenClient implements PushTokenClient {
  HttpPushTokenClient({required this.baseUrl, required this.accessToken});

  final String baseUrl;
  final String accessToken;

  @override
  Future<void> register({
    required String deviceId,
    required PushProvider provider,
    required String token,
  }) async {
    final response = await _request(
      'PUT',
      '/api/v1/push/devices/$deviceId/token',
      body: {'provider': provider.wire, 'token': token},
    );
    if (response != HttpStatus.noContent) {
      throw HttpException('Push token registration failed ($response)');
    }
  }

  @override
  Future<void> revoke({
    required String deviceId,
    required PushProvider provider,
  }) async {
    final response = await _request(
      'DELETE',
      '/api/v1/push/devices/$deviceId/token/${provider.wire}',
    );
    if (response != HttpStatus.noContent) {
      throw HttpException('Push token revoke failed ($response)');
    }
  }

  Future<int> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      return (await request.close()).statusCode;
    } finally {
      client.close(force: true);
    }
  }
}
