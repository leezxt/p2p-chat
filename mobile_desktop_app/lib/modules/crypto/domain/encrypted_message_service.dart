import 'dart:convert';
import 'dart:typed_data';

import '../../../shared/models/message_envelope.dart';
import 'device_key_material.dart';
import 'encrypted_envelope.dart';
import 'message_box.dart';
import 'remote_device_key.dart';
import 'replay_protection.dart';

class CryptoMessageException implements Exception {
  const CryptoMessageException(this.code, [this.cause]);

  final String code;
  final Object? cause;

  @override
  String toString() => 'CryptoMessageException($code)';
}

abstract class MessageCipher {
  Future<EncryptedEnvelope> encrypt(
    String recipientDeviceId,
    MessageEnvelope message,
  );

  Future<MessageEnvelope> decrypt(EncryptedEnvelope envelope);
}

class EncryptedMessageService implements MessageCipher {
  EncryptedMessageService({
    required MessageBox box,
    required DeviceKeyMaterial localKey,
    required String localDeviceId,
    required RemoteDeviceKeyResolver remoteKeys,
    required ReplayProtection replayProtection,
    int Function()? clock,
  })  : _box = box,
        _localKey = localKey,
        _localDeviceId = localDeviceId,
        _remoteKeys = remoteKeys,
        _replayProtection = replayProtection,
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch ~/ 1000);

  final MessageBox _box;
  final DeviceKeyMaterial _localKey;
  final String _localDeviceId;
  final RemoteDeviceKeyResolver _remoteKeys;
  final ReplayProtection _replayProtection;
  final int Function() _clock;

  @override
  Future<EncryptedEnvelope> encrypt(
    String recipientDeviceId,
    MessageEnvelope message,
  ) async {
    if (message.senderDeviceId != _localDeviceId) {
      throw const CryptoMessageException('SENDER_DEVICE_MISMATCH');
    }
    final recipient = await _resolveKey(recipientDeviceId);
    final nonce = _box.randomNonce();
    if (nonce.length != EncryptedEnvelope.nonceBytes) {
      throw const CryptoMessageException('INVALID_NONCE');
    }
    final plaintext = Uint8List.fromList(JsonUtf8Encoder().convert({
      'message': message.toWireJson(),
      'recipientDeviceId': recipientDeviceId,
      'senderKeyId': _localKey.keyId,
      'recipientKeyId': recipient.keyId,
    }));
    try {
      final ciphertext = _box.encrypt(
        message: plaintext,
        nonce: nonce,
        publicKey: recipient.publicKey,
        secretKey: _localKey.secretKey,
      );
      return EncryptedEnvelope(
        senderDeviceId: _localDeviceId,
        recipientDeviceId: recipientDeviceId,
        senderKeyId: _localKey.keyId,
        recipientKeyId: recipient.keyId,
        messageId: message.messageId,
        nonce: nonce,
        ciphertext: ciphertext,
      );
    } catch (error) {
      if (error is CryptoMessageException) rethrow;
      throw CryptoMessageException('ENCRYPTION_FAILED', error);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
      nonce.fillRange(0, nonce.length, 0);
    }
  }

  @override
  Future<MessageEnvelope> decrypt(EncryptedEnvelope envelope) async {
    if (envelope.recipientDeviceId != _localDeviceId ||
        envelope.recipientKeyId != _localKey.keyId) {
      throw const CryptoMessageException('RECIPIENT_KEY_MISMATCH');
    }
    final sender = await _resolveKey(envelope.senderDeviceId);
    if (sender.keyId != envelope.senderKeyId) {
      throw const CryptoMessageException('SENDER_KEY_MISMATCH');
    }
    final nonce = base64UrlEncode(envelope.nonce).replaceAll('=', '');
    if (await _replayProtection.seen(
      senderDeviceId: envelope.senderDeviceId,
      messageId: envelope.messageId,
      nonce: nonce,
    )) {
      throw const CryptoMessageException('REPLAY_REJECTED');
    }

    Uint8List? plaintext;
    try {
      plaintext = _box.decrypt(
        ciphertext: envelope.ciphertext,
        nonce: envelope.nonce,
        publicKey: sender.publicKey,
        secretKey: _localKey.secretKey,
      );
    } catch (error) {
      throw CryptoMessageException('AUTH_FAILED', error);
    }

    try {
      final decoded = jsonDecode(utf8.decode(plaintext));
      if (decoded is! Map<String, dynamic>) {
        throw const CryptoMessageException('INVALID_INNER_ENVELOPE');
      }
      final messageRaw = decoded['message'];
      if (messageRaw is! Map) {
        throw const CryptoMessageException('INVALID_INNER_ENVELOPE');
      }
      final message = MessageEnvelope.fromWireJson(
        Map<String, Object?>.from(messageRaw),
      );
      if (message.messageId != envelope.messageId ||
          message.senderDeviceId != envelope.senderDeviceId ||
          decoded['recipientDeviceId'] != envelope.recipientDeviceId ||
          decoded['senderKeyId'] != envelope.senderKeyId ||
          decoded['recipientKeyId'] != envelope.recipientKeyId) {
        throw const CryptoMessageException('INNER_OUTER_MISMATCH');
      }
      final accepted = await _replayProtection.acceptOnce(
        senderDeviceId: envelope.senderDeviceId,
        messageId: envelope.messageId,
        nonce: nonce,
        receivedAt: _clock(),
      );
      if (!accepted) {
        throw const CryptoMessageException('REPLAY_REJECTED');
      }
      return message;
    } on CryptoMessageException {
      rethrow;
    } catch (error) {
      throw CryptoMessageException('INVALID_INNER_ENVELOPE', error);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  Future<RemoteDeviceKey> _resolveKey(String deviceId) async {
    try {
      final key = await _remoteKeys.resolve(deviceId);
      if (key.publicKey.length != _box.publicKeyBytes) {
        throw const CryptoMessageException('INVALID_REMOTE_KEY');
      }
      return key;
    } on CryptoMessageException {
      rethrow;
    } catch (error) {
      throw CryptoMessageException('REMOTE_KEY_UNAVAILABLE', error);
    }
  }
}
