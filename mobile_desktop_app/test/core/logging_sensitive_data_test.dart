import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_envelope.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_message_service.dart';

void main() {
  test('logger 遮蔽 token、JWT、key、plaintext、ciphertext 與 payload', () {
    final entries = <LogEntry>[];
    final logger = LoggingService(sink: entries.add);
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.signature';

    logger.error(
      'crypto',
      'Authorization: Bearer bearer-secret token=token-secret '
          'secretKey=key-secret privateKey=private-secret '
          'plaintext="hello world" ciphertext=deadbeef '
          'payload={message:secret} jwt=$jwt',
      StackTrace.fromString('token=stack-secret plaintext=stack-message'),
    );

    final output = '${entries.single.message}\n${entries.single.stackTrace}';
    for (final secret in [
      'bearer-secret',
      'token-secret',
      'key-secret',
      'private-secret',
      'hello world',
      'deadbeef',
      'message:secret',
      jwt,
      'stack-secret',
      'stack-message',
    ]) {
      expect(output, isNot(contains(secret)));
    }
    expect(output, contains('[REDACTED]'));
  });

  test('crypto toString 不輸出 ciphertext、secret key 或底層 cause', () {
    final envelope = EncryptedEnvelope(
      senderDeviceId: 'device-a',
      recipientDeviceId: 'device-b',
      senderKeyId: 'key-a',
      recipientKeyId: 'key-b',
      messageId: 'message-1',
      nonce: Uint8List(24),
      ciphertext: Uint8List.fromList(List<int>.filled(16, 99)),
    );
    const cryptoError = CryptoMessageException(
      'AUTH_FAILED',
      'plaintext=do-not-log',
    );

    expect(envelope.toString(), contains('ciphertext: [REDACTED]'));
    expect(envelope.toString(), isNot(contains('99')));
    expect(cryptoError.toString(), 'CryptoMessageException(AUTH_FAILED)');
    expect(cryptoError.toString(), isNot(contains('do-not-log')));
  });
}
