import 'dart:typed_data';

import 'package:sodium/sodium.dart';

abstract class MessageBox {
  int get nonceBytes;
  int get publicKeyBytes;
  Uint8List randomNonce();

  Uint8List encrypt({
    required Uint8List message,
    required Uint8List nonce,
    required Uint8List publicKey,
    required SecureKey secretKey,
  });

  Uint8List decrypt({
    required Uint8List ciphertext,
    required Uint8List nonce,
    required Uint8List publicKey,
    required SecureKey secretKey,
  });
}

class SodiumMessageBox implements MessageBox {
  SodiumMessageBox(this._sodium);

  final Sodium _sodium;

  @override
  int get nonceBytes => _sodium.crypto.box.nonceBytes;

  @override
  int get publicKeyBytes => _sodium.crypto.box.publicKeyBytes;

  @override
  Uint8List randomNonce() => _sodium.randombytes.buf(nonceBytes);

  @override
  Uint8List encrypt({
    required Uint8List message,
    required Uint8List nonce,
    required Uint8List publicKey,
    required SecureKey secretKey,
  }) =>
      _sodium.crypto.box.easy(
        message: message,
        nonce: nonce,
        publicKey: publicKey,
        secretKey: secretKey,
      );

  @override
  Uint8List decrypt({
    required Uint8List ciphertext,
    required Uint8List nonce,
    required Uint8List publicKey,
    required SecureKey secretKey,
  }) =>
      _sodium.crypto.box.openEasy(
        cipherText: ciphertext,
        nonce: nonce,
        publicKey: publicKey,
        secretKey: secretKey,
      );
}
