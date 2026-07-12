import 'dart:typed_data';

import 'package:sodium/sodium.dart';

class DeviceKeyMaterial {
  DeviceKeyMaterial({
    required Uint8List publicKey,
    required this.secretKey,
    required this.keyId,
    required this.fingerprint,
  }) : _publicKey = Uint8List.fromList(publicKey);

  final Uint8List _publicKey;
  final SecureKey secretKey;
  final String keyId;
  final String fingerprint;
  bool _disposed = false;

  Uint8List get publicKey => Uint8List.fromList(_publicKey);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    secretKey.dispose();
    _publicKey.fillRange(0, _publicKey.length, 0);
  }

  @override
  String toString() =>
      'DeviceKeyMaterial(keyId: $keyId, fingerprint: $fingerprint, secretKey: [REDACTED])';
}
