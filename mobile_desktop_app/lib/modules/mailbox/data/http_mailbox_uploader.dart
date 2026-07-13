import 'dart:convert';
import 'dart:io';

import '../../crypto/domain/encrypted_envelope.dart';
import '../domain/mailbox_client.dart';
import '../domain/mailbox_ack.dart';

class HttpMailboxUploader implements MailboxClient {
  HttpMailboxUploader({required this.baseUrl, required this.accessToken});

  static const _pullPageSize = 100;
  static const _maxPullPages = 11;

  final String baseUrl;
  final String accessToken;

  @override
  Future<void> upload(EncryptedEnvelope envelope) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$baseUrl/api/v1/mailbox/messages'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $accessToken');
      request.write(jsonEncode({
        'schemaVersion': 1,
        'expiresInSeconds': 7 * 24 * 60 * 60,
        'envelope': envelope.toWireJson(),
      }));
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode != HttpStatus.created &&
          response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Mailbox upload failed (${response.statusCode})',
        );
      }
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<List<MailboxDownload>> pull(String deviceId) async {
    final downloads = <MailboxDownload>[];
    final seenCursors = <String>{};
    String? cursor;
    for (var page = 0; page < _maxPullPages; page++) {
      final path = Uri(
        path: '/api/v1/mailbox/messages',
        queryParameters: {
          'deviceId': deviceId,
          'limit': '$_pullPageSize',
          if (cursor != null) 'cursor': cursor,
        },
      ).toString();
      final body = await _jsonRequest('GET', path);
      final items = body['items'] as List? ?? const [];
      downloads.addAll(items.map((raw) {
        final item = Map<String, Object?>.from(raw as Map);
        return MailboxDownload(
          mailboxMessageId: item['mailboxMessageId'] as String,
          envelope: EncryptedEnvelope.fromWireJson(
            Map<String, Object?>.from(item['envelope'] as Map),
          ),
        );
      }));
      final nextCursor = body['nextCursor'];
      if (nextCursor == null) return downloads;
      if (nextCursor is! String ||
          nextCursor.isEmpty ||
          !seenCursors.add(nextCursor)) {
        throw const FormatException('Invalid mailbox pagination cursor');
      }
      cursor = nextCursor;
    }
    throw StateError('Mailbox pagination exceeded the safety limit');
  }

  @override
  Future<void> acknowledge(MailboxAck ack) async {
    await _jsonRequest(
      'PUT',
      '/api/v1/mailbox/messages/${ack.mailboxMessageId}/ack',
      body: ack.toWireJson(),
    );
  }

  @override
  Future<List<MailboxRemoteStatus>> fetchStatuses(
    String senderDeviceId,
  ) async {
    final statuses = <MailboxRemoteStatus>[];
    final seenCursors = <String>{};
    String? cursor;
    for (var page = 0; page < _maxPullPages; page++) {
      final path = Uri(
        path: '/api/v1/mailbox/acks',
        queryParameters: {
          'deviceId': senderDeviceId,
          'limit': '$_pullPageSize',
          if (cursor != null) 'cursor': cursor,
        },
      ).toString();
      final body = await _jsonRequest('GET', path);
      final items =
          body['items'] is List ? body['items'] as List : body['data'] as List?;
      statuses.addAll((items ?? const []).map((raw) {
        final item = Map<String, Object?>.from(raw as Map);
        return MailboxRemoteStatus(
          messageId: item['messageId'] as String,
          status: MailboxDeliveryState.fromWire(item['status'] as String),
        );
      }));
      final nextCursor = body['nextCursor'];
      if (nextCursor == null) return statuses;
      if (nextCursor is! String ||
          nextCursor.isEmpty ||
          !seenCursors.add(nextCursor)) {
        throw const FormatException('Invalid mailbox pagination cursor');
      }
      cursor = nextCursor;
    }
    throw StateError('Mailbox pagination exceeded the safety limit');
  }

  Future<Map<String, Object?>> _jsonRequest(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $accessToken');
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final raw = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Mailbox request failed (${response.statusCode})');
      }
      if (raw.isEmpty) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is List) return {'data': decoded};
      return Map<String, Object?>.from(decoded as Map);
    } finally {
      client.close(force: true);
    }
  }
}
