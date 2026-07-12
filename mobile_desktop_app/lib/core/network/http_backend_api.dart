import 'dart:convert';
import 'dart:io';
import 'backend_api.dart';
import '../../modules/identity/domain/identity_session.dart';

class HttpBackendApi implements BackendApi {
  HttpBackendApi({required this.baseUrl, required this.localDevKey});
  final String baseUrl;
  final String localDevKey;

  @override
  Future<AccessSession> register(
    IdentitySession identity,
    String displayName, {
    required String publicKey,
    required String publicKeyFingerprint,
  }) async {
    final response = await _post('/api/v1/registration', {
      'userId': identity.userId,
      'deviceId': identity.deviceId,
      'displayName': displayName,
      'deviceName': 'Primary Device',
      'publicKey': publicKey,
      'publicKeyFingerprint': publicKeyFingerprint,
    }, headers: {
      'X-Local-Dev-Key': localDevKey
    }, accepted: {
      201,
      409
    });
    if (response.statusCode == 409) {
      final token = await _post(
          '/api/v1/auth/local-token', {'userId': identity.userId},
          headers: {'X-Local-Dev-Key': localDevKey}, accepted: {200});
      return _access(token.body, tokenField: 'token');
    }
    return _access(response.body, tokenField: 'accessToken');
  }

  @override
  Future<InviteResult> createInvite(String token) async {
    final response = await _post('/api/v1/invites', null,
        headers: {'Authorization': 'Bearer $token'}, accepted: {201});
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return InviteResult(
        body['code'] as String, DateTime.parse(body['expiresAt'] as String));
  }

  @override
  Future<void> initializeDeviceKey(
    String token,
    String deviceId, {
    required String publicKey,
    required String publicKeyFingerprint,
  }) async {
    await _put(
      '/api/v1/devices/$deviceId/key',
      {
        'publicKey': publicKey,
        'publicKeyFingerprint': publicKeyFingerprint,
      },
      headers: {'Authorization': 'Bearer $token'},
      accepted: {204},
    );
  }

  @override
  Future<RedeemedContact> redeemInvite(
      String token, String codeOrQrPayload) async {
    final uri = Uri.tryParse(codeOrQrPayload);
    final code =
        uri?.scheme == 'p2pchat' ? uri!.pathSegments.last : codeOrQrPayload;
    final response = await _post('/api/v1/invites/redeem', {'code': code},
        headers: {'Authorization': 'Bearer $token'}, accepted: {200});
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return RedeemedContact(
        body['userId'] as String,
        body['displayName'] as String,
        body['deviceId'] as String,
        body['publicKey'] as String,
        body['publicKeyFingerprint'] as String);
  }

  @override
  Future<List<RedeemedContact>> listContacts(String token) async {
    final response = await _get('/api/v1/invites/contacts',
        headers: {'Authorization': 'Bearer $token'}, accepted: {200});
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((item) {
      final contact = item as Map<String, dynamic>;
      return RedeemedContact(
        contact['userId'] as String,
        contact['displayName'] as String,
        contact['deviceId'] as String,
        contact['publicKey'] as String,
        contact['publicKeyFingerprint'] as String,
      );
    }).toList(growable: false);
  }

  AccessSession _access(String raw, {required String tokenField}) {
    final body = jsonDecode(raw) as Map<String, dynamic>;
    return AccessSession(body[tokenField] as String,
        DateTime.parse(body['expiresAt'] as String));
  }

  Future<_Response> _post(String path, Map<String, Object?>? body,
      {required Map<String, String> headers,
      required Set<int> accepted}) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final raw = await utf8.decoder.bind(response).join();
      if (!accepted.contains(response.statusCode)) {
        throw HttpException('Backend $path failed (${response.statusCode})');
      }
      return _Response(response.statusCode, raw);
    } finally {
      client.close(force: true);
    }
  }

  Future<_Response> _put(String path, Map<String, Object?> body,
      {required Map<String, String> headers,
      required Set<int> accepted}) async {
    final client = HttpClient();
    try {
      final request = await client.putUrl(Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.write(jsonEncode(body));
      final response = await request.close();
      final raw = await utf8.decoder.bind(response).join();
      if (!accepted.contains(response.statusCode)) {
        throw HttpException('Backend $path failed (${response.statusCode})');
      }
      return _Response(response.statusCode, raw);
    } finally {
      client.close(force: true);
    }
  }

  Future<_Response> _get(String path,
      {required Map<String, String> headers,
      required Set<int> accepted}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl$path'));
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final response = await request.close();
      final raw = await utf8.decoder.bind(response).join();
      if (!accepted.contains(response.statusCode)) {
        throw HttpException('Backend $path failed (${response.statusCode})');
      }
      return _Response(response.statusCode, raw);
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
