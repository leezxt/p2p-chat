import 'dart:convert';
import 'dart:typed_data';

class EncryptedEnvelopeFormatException implements Exception {
  const EncryptedEnvelopeFormatException(this.code);

  final String code;

  @override
  String toString() => 'EncryptedEnvelopeFormatException($code)';
}

class EncryptedEnvelope {
  EncryptedEnvelope({
    required this.senderDeviceId,
    required this.recipientDeviceId,
    required this.senderKeyId,
    required this.recipientKeyId,
    required this.messageId,
    required Uint8List nonce,
    required Uint8List ciphertext,
    this.cryptoVersion = currentCryptoVersion,
    this.suite = currentSuite,
  })  : _nonce = Uint8List.fromList(nonce),
        _ciphertext = Uint8List.fromList(ciphertext) {
    _validate();
  }

  static const currentCryptoVersion = 1;
  static const currentSuite = 'P2P_BOX_V1';
  static const nonceBytes = 24;
  static const authenticationTagBytes = 16;
  static const maxCiphertextBytes = 1024 * 1024;

  final int cryptoVersion;
  final String suite;
  final String senderDeviceId;
  final String recipientDeviceId;
  final String senderKeyId;
  final String recipientKeyId;
  final String messageId;
  final Uint8List _nonce;
  final Uint8List _ciphertext;

  Uint8List get nonce => Uint8List.fromList(_nonce);
  Uint8List get ciphertext => Uint8List.fromList(_ciphertext);

  Map<String, Object?> toWireJson() => {
        'cryptoVersion': cryptoVersion,
        'suite': suite,
        'senderDeviceId': senderDeviceId,
        'recipientDeviceId': recipientDeviceId,
        'senderKeyId': senderKeyId,
        'recipientKeyId': recipientKeyId,
        'messageId': messageId,
        'nonce': base64UrlEncode(_nonce).replaceAll('=', ''),
        'ciphertext': base64UrlEncode(_ciphertext).replaceAll('=', ''),
      };

  factory EncryptedEnvelope.fromWireJson(Map<String, Object?> json) {
    try {
      final version = json['cryptoVersion'];
      if (version is! int || version != currentCryptoVersion) {
        throw const EncryptedEnvelopeFormatException(
          'UNKNOWN_CRYPTO_VERSION',
        );
      }
      final suite = json['suite'];
      if (suite is! String || suite != currentSuite) {
        throw const EncryptedEnvelopeFormatException('UNKNOWN_CRYPTO_SUITE');
      }
      return EncryptedEnvelope(
        cryptoVersion: version,
        suite: suite,
        senderDeviceId: _requiredString(json, 'senderDeviceId'),
        recipientDeviceId: _requiredString(json, 'recipientDeviceId'),
        senderKeyId: _requiredString(json, 'senderKeyId'),
        recipientKeyId: _requiredString(json, 'recipientKeyId'),
        messageId: _requiredString(json, 'messageId'),
        nonce: _decodeBase64(json, 'nonce'),
        ciphertext: _decodeBase64(json, 'ciphertext'),
      );
    } on EncryptedEnvelopeFormatException {
      rethrow;
    } catch (_) {
      throw const EncryptedEnvelopeFormatException('INVALID_ENVELOPE');
    }
  }

  void _validate() {
    if (cryptoVersion != currentCryptoVersion) {
      throw const EncryptedEnvelopeFormatException('UNKNOWN_CRYPTO_VERSION');
    }
    if (suite != currentSuite) {
      throw const EncryptedEnvelopeFormatException('UNKNOWN_CRYPTO_SUITE');
    }
    for (final value in [
      senderDeviceId,
      recipientDeviceId,
      senderKeyId,
      recipientKeyId,
      messageId,
    ]) {
      if (value.isEmpty || value.length > 256) {
        throw const EncryptedEnvelopeFormatException('INVALID_IDENTIFIER');
      }
    }
    if (_nonce.length != nonceBytes) {
      throw const EncryptedEnvelopeFormatException('INVALID_NONCE');
    }
    if (_ciphertext.length < authenticationTagBytes ||
        _ciphertext.length > maxCiphertextBytes) {
      throw const EncryptedEnvelopeFormatException('INVALID_CIPHERTEXT');
    }
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw const EncryptedEnvelopeFormatException('INVALID_ENVELOPE');
    }
    return value;
  }

  static Uint8List _decodeBase64(Map<String, Object?> json, String key) {
    final value = _requiredString(json, key);
    final padding = (4 - value.length % 4) % 4;
    return base64Url.decode('$value${'=' * padding}');
  }

  @override
  String toString() =>
      'EncryptedEnvelope(messageId: $messageId, suite: $suite, ciphertext: [REDACTED])';
}
