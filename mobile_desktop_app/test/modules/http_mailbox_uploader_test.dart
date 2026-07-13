import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_envelope.dart';
import 'package:p2p_chat_app/modules/mailbox/data/http_mailbox_uploader.dart';

void main() {
  test('pull follows opaque cursor until all mailbox pages are downloaded',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    final subscription = server.listen((request) async {
      requests++;
      expect(request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer access-token');
      expect(request.uri.queryParameters['deviceId'], 'device-b');
      expect(request.uri.queryParameters['limit'], '100');
      final cursor = request.uri.queryParameters['cursor'];
      final response = cursor == null
          ? {
              'items': [_item('mailbox-1', 'message-1')],
              'nextCursor': 'opaque_cursor_1'
            }
          : {
              'items': [_item('mailbox-2', 'message-2')],
              'nextCursor': null
            };
      expect(cursor, requests == 1 ? isNull : 'opaque_cursor_1');
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });

    try {
      final client = HttpMailboxUploader(
        baseUrl: 'http://${server.address.host}:${server.port}',
        accessToken: 'access-token',
      );
      final downloads = await client.pull('device-b');
      expect(downloads.map((item) => item.mailboxMessageId),
          ['mailbox-1', 'mailbox-2']);
      expect(requests, 2);
    } finally {
      await server.close(force: true);
      await subscription.cancel();
    }
  });

  test('pull rejects a repeated cursor instead of looping forever', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'items': const [],
        'nextCursor': 'repeated_cursor',
      }));
      await request.response.close();
    });

    try {
      final client = HttpMailboxUploader(
        baseUrl: 'http://${server.address.host}:${server.port}',
        accessToken: 'access-token',
      );
      await expectLater(client.pull('device-b'), throwsFormatException);
    } finally {
      await server.close(force: true);
      await subscription.cancel();
    }
  });

  test('sender status sync follows its opaque cursor pages', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    final subscription = server.listen((request) async {
      requests++;
      expect(request.uri.path, '/api/v1/mailbox/acks');
      expect(request.uri.queryParameters['deviceId'], 'device-a');
      final cursor = request.uri.queryParameters['cursor'];
      final response = cursor == null
          ? {
              'items': [
                {'messageId': 'message-1', 'status': 'DELIVERED'},
              ],
              'nextCursor': 'ack_cursor_1',
            }
          : {
              'items': [
                {'messageId': 'message-2', 'status': 'READ'},
              ],
              'nextCursor': null,
            };
      expect(cursor, requests == 1 ? isNull : 'ack_cursor_1');
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });

    try {
      final client = HttpMailboxUploader(
        baseUrl: 'http://${server.address.host}:${server.port}',
        accessToken: 'access-token',
      );
      final statuses = await client.fetchStatuses('device-a');
      expect(
          statuses.map((item) => item.messageId), ['message-1', 'message-2']);
      expect(requests, 2);
    } finally {
      await server.close(force: true);
      await subscription.cancel();
    }
  });
}

Map<String, Object?> _item(String mailboxMessageId, String messageId) => {
      'mailboxMessageId': mailboxMessageId,
      'envelope': EncryptedEnvelope(
        senderDeviceId: 'device-a',
        recipientDeviceId: 'device-b',
        senderKeyId: 'key-a',
        recipientKeyId: 'key-b',
        messageId: messageId,
        nonce: Uint8List(24),
        ciphertext: Uint8List(16),
      ).toWireJson(),
    };
