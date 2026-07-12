import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/crypto/domain/encrypted_envelope.dart';

void main() {
  EncryptedEnvelope envelope() => EncryptedEnvelope(
        senderDeviceId: 'device-a',
        recipientDeviceId: 'device-b',
        senderKeyId: 'key-a',
        recipientKeyId: 'key-b',
        messageId: 'message-1',
        nonce: Uint8List.fromList(List.generate(24, (index) => index)),
        ciphertext: Uint8List.fromList(List.generate(32, (index) => index)),
      );

  test('wire JSON round-trip 保留 routing metadata 與 binary payload', () {
    final original = envelope();
    final decoded = EncryptedEnvelope.fromWireJson(original.toWireJson());

    expect(decoded.cryptoVersion, 1);
    expect(decoded.suite, 'P2P_BOX_V1');
    expect(decoded.messageId, original.messageId);
    expect(decoded.nonce, orderedEquals(original.nonce));
    expect(decoded.ciphertext, orderedEquals(original.ciphertext));
    expect(decoded.toString(), contains('ciphertext: [REDACTED]'));
  });

  test('binary getter 回傳副本，外部不能修改 envelope', () {
    final original = envelope();
    final nonce = original.nonce..fillRange(0, 24, 255);
    final ciphertext = original.ciphertext..fillRange(0, 32, 255);

    expect(original.nonce, isNot(orderedEquals(nonce)));
    expect(original.ciphertext, isNot(orderedEquals(ciphertext)));
  });

  test('拒絕未知版本與 suite', () {
    final json = envelope().toWireJson();

    expect(
      () => EncryptedEnvelope.fromWireJson({...json, 'cryptoVersion': 2}),
      throwsA(
        isA<EncryptedEnvelopeFormatException>().having(
          (error) => error.code,
          'code',
          'UNKNOWN_CRYPTO_VERSION',
        ),
      ),
    );
    expect(
      () => EncryptedEnvelope.fromWireJson({...json, 'suite': 'OTHER'}),
      throwsA(
        isA<EncryptedEnvelopeFormatException>().having(
          (error) => error.code,
          'code',
          'UNKNOWN_CRYPTO_SUITE',
        ),
      ),
    );
  });

  test('拒絕錯誤 nonce、過短 ciphertext 與 malformed base64', () {
    final json = envelope().toWireJson();

    for (final invalid in [
      {...json, 'nonce': 'AA'},
      {...json, 'ciphertext': 'AA'},
      {...json, 'nonce': '!not-base64!'},
    ]) {
      expect(
        () => EncryptedEnvelope.fromWireJson(invalid),
        throwsA(isA<EncryptedEnvelopeFormatException>()),
      );
    }
  });

  test('拒絕空白 routing identifier 與過大 ciphertext', () {
    final json = envelope().toWireJson();
    expect(
      () => EncryptedEnvelope.fromWireJson({...json, 'messageId': ''}),
      throwsA(
        isA<EncryptedEnvelopeFormatException>().having(
          (error) => error.code,
          'code',
          'INVALID_IDENTIFIER',
        ),
      ),
    );
    expect(
      () => EncryptedEnvelope(
        senderDeviceId: 'a',
        recipientDeviceId: 'b',
        senderKeyId: 'c',
        recipientKeyId: 'd',
        messageId: 'e',
        nonce: Uint8List(24),
        ciphertext: Uint8List(EncryptedEnvelope.maxCiphertextBytes + 1),
      ),
      throwsA(isA<EncryptedEnvelopeFormatException>()),
    );
  });
}
