import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sodium/sodium.dart';

import '../data/secure_key_value_store.dart';
import 'device_key_exceptions.dart';
import 'device_key_fingerprint.dart';
import 'device_key_material.dart';

class DeviceKeyService {
  DeviceKeyService({required Sodium sodium, required SecureKeyValueStore store})
      : _sodium = sodium,
        _store = store;

  static const _recordVersion = 1;
  static const _storagePrefix = 'p2p.crypto.device';

  final Sodium _sodium;
  final SecureKeyValueStore _store;

  Future<DeviceKeyMaterial> getOrCreate(String deviceId) async {
    final storageKey = '$_storagePrefix.$deviceId.v1';
    final String? stored;
    try {
      stored = await _store.read(storageKey);
    } catch (error) {
      throw DeviceKeyStorageException(error);
    }
    if (stored != null) return _decode(deviceId, stored);

    final pair = _sodium.crypto.box.keyPair();
    try {
      final encoded = _encode(pair);
      try {
        await _store.write(storageKey, encoded);
      } catch (error) {
        throw DeviceKeyStorageException(error);
      }
      return _material(deviceId, pair.publicKey, pair.secretKey.copy());
    } finally {
      pair.dispose();
    }
  }

  String _encode(KeyPair pair) {
    final secretBytes = pair.secretKey.extractBytes();
    try {
      return jsonEncode({
        'version': _recordVersion,
        'publicKey': base64UrlEncode(pair.publicKey),
        'secretKey': base64UrlEncode(secretBytes),
      });
    } finally {
      secretBytes.fillRange(0, secretBytes.length, 0);
    }
  }

  DeviceKeyMaterial _decode(String deviceId, String encoded) {
    Uint8List? secretBytes;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != _recordVersion) {
        throw const FormatException('Unsupported device key record');
      }
      final publicKey = base64Url.decode(decoded['publicKey'] as String);
      secretBytes = base64Url.decode(decoded['secretKey'] as String);
      final box = _sodium.crypto.box;
      if (publicKey.length != box.publicKeyBytes ||
          secretBytes.length != box.secretKeyBytes) {
        throw const FormatException('Invalid device key length');
      }
      return _material(deviceId, publicKey, _sodium.secureCopy(secretBytes));
    } catch (error) {
      if (error is DeviceKeyException) rethrow;
      throw DeviceKeyCorruptedException(error);
    } finally {
      secretBytes?.fillRange(0, secretBytes.length, 0);
    }
  }

  DeviceKeyMaterial _material(
      String deviceId, Uint8List publicKey, SecureKey secretKey) {
    final publicDigest = sha256.convert(publicKey).bytes;
    return DeviceKeyMaterial(
      publicKey: publicKey,
      secretKey: secretKey,
      keyId:
          base64Url.encode(publicDigest).replaceAll('=', '').substring(0, 22),
      fingerprint: computeDeviceKeyFingerprint(deviceId, publicKey),
    );
  }
}
