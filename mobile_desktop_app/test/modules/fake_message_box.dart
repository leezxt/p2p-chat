import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_fingerprint.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_material.dart';
import 'package:p2p_chat_app/modules/crypto/domain/message_box.dart';
import 'package:sodium/sodium.dart';

/// 僅供 host protocol tests 使用的可驗證 MessageBox fake。
///
/// 它不是密碼學實作，也絕不能用於 App runtime；目的只是讓測試不載入 Windows
/// libsodium native asset 時，仍能驗證「錯 key／錯 nonce／竄改」會被 protocol 拒絕。
class TestMessageBox implements MessageBox {
  static const _tagBytes = 32;

  final _publicBySecret = <String, Uint8List>{};
  int _nonceCounter = 0;

  @override
  int get nonceBytes => 24;

  @override
  int get publicKeyBytes => 32;

  void registerKey({
    required Uint8List publicKey,
    required TestSecureKey secretKey,
  }) {
    if (publicKey.length != publicKeyBytes) {
      throw ArgumentError.value(publicKey, 'publicKey', 'must be 32 bytes');
    }
    _publicBySecret[_secretId(secretKey)] = Uint8List.fromList(publicKey);
  }

  @override
  Uint8List randomNonce() {
    final seed = _nonceCounter++;
    return Uint8List.fromList(
      List<int>.generate(nonceBytes, (index) => (seed + index + 1) & 0xff),
    );
  }

  @override
  Uint8List encrypt({
    required Uint8List message,
    required Uint8List nonce,
    required Uint8List publicKey,
    required SecureKey secretKey,
  }) {
    _validateNonce(nonce);
    _validatePublicKey(publicKey);
    final senderPublicKey = _publicFor(secretKey);
    final tag = _tag(senderPublicKey, publicKey, nonce, message);
    return Uint8List.fromList([...tag, ...message]);
  }

  @override
  Uint8List decrypt({
    required Uint8List ciphertext,
    required Uint8List nonce,
    required Uint8List publicKey,
    required SecureKey secretKey,
  }) {
    _validateNonce(nonce);
    _validatePublicKey(publicKey);
    if (ciphertext.length < _tagBytes) {
      throw StateError('invalid fake ciphertext');
    }
    final recipientPublicKey = _publicFor(secretKey);
    final receivedTag = Uint8List.sublistView(ciphertext, 0, _tagBytes);
    final plaintext = Uint8List.fromList(ciphertext.sublist(_tagBytes));
    final expectedTag = _tag(publicKey, recipientPublicKey, nonce, plaintext);
    if (!_constantTimeEquals(receivedTag, expectedTag)) {
      plaintext.fillRange(0, plaintext.length, 0);
      throw StateError('fake authentication failed');
    }
    return plaintext;
  }

  String _secretId(SecureKey key) {
    final bytes = key.extractBytes();
    try {
      return base64UrlEncode(bytes).replaceAll('=', '');
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Uint8List _publicFor(SecureKey secretKey) {
    final publicKey = _publicBySecret[_secretId(secretKey)];
    if (publicKey == null) throw StateError('unregistered fake secret key');
    return Uint8List.fromList(publicKey);
  }

  Uint8List _tag(
    Uint8List leftPublicKey,
    Uint8List rightPublicKey,
    Uint8List nonce,
    Uint8List message,
  ) {
    final ordered = _compareBytes(leftPublicKey, rightPublicKey) <= 0
        ? [leftPublicKey, rightPublicKey]
        : [rightPublicKey, leftPublicKey];
    return Uint8List.fromList(
      sha256
          .convert([...ordered[0], ...ordered[1], ...nonce, ...message]).bytes,
    );
  }

  void _validateNonce(Uint8List nonce) {
    if (nonce.length != nonceBytes) throw StateError('invalid fake nonce');
  }

  void _validatePublicKey(Uint8List publicKey) {
    if (publicKey.length != publicKeyBytes) {
      throw StateError('invalid fake public key');
    }
  }
}

class TestSecureKey implements SecureKey {
  TestSecureKey(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;
  bool _disposed = false;

  @override
  int get length => _bytes.length;

  @override
  T runUnlockedSync<T>(SecureCallbackFn<T> callback, {bool writable = false}) {
    _ensureActive();
    return callback(_bytes);
  }

  @override
  FutureOr<T> runUnlockedAsync<T>(
    SecureCallbackFn<FutureOr<T>> callback, {
    bool writable = false,
  }) {
    _ensureActive();
    return callback(_bytes);
  }

  @override
  Uint8List extractBytes() {
    _ensureActive();
    return Uint8List.fromList(_bytes);
  }

  @override
  SecureKey copy() {
    _ensureActive();
    return TestSecureKey(_bytes);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bytes.fillRange(0, _bytes.length, 0);
  }

  void _ensureActive() {
    if (_disposed) throw StateError('test key was disposed');
  }
}

DeviceKeyMaterial testDeviceKey({
  required String deviceId,
  required Uint8List publicKey,
  required TestSecureKey secretKey,
}) =>
    DeviceKeyMaterial(
      publicKey: publicKey,
      secretKey: secretKey,
      keyId: 'test-$deviceId',
      fingerprint: computeDeviceKeyFingerprint(deviceId, publicKey),
    );

bool _constantTimeEquals(Uint8List left, Uint8List right) {
  var difference = left.length ^ right.length;
  final maxLength = left.length >= right.length ? left.length : right.length;
  for (var index = 0; index < maxLength; index++) {
    final leftByte = index < left.length ? left[index] : 0;
    final rightByte = index < right.length ? right[index] : 0;
    difference |= leftByte ^ rightByte;
  }
  return difference == 0;
}

int _compareBytes(Uint8List left, Uint8List right) {
  final count = left.length <= right.length ? left.length : right.length;
  for (var index = 0; index < count; index++) {
    final comparison = left[index].compareTo(right[index]);
    if (comparison != 0) return comparison;
  }
  return left.length.compareTo(right.length);
}
