import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const _fingerprintDomain = 'p2p-chat-device-key-v1';

String computeDeviceKeyFingerprint(String deviceId, Uint8List publicKey) {
  final bytes = sha256.convert([
    ...utf8.encode(_fingerprintDomain),
    ...utf8.encode(deviceId),
    ...publicKey,
  ]).bytes;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
  return [
    for (var index = 0; index < hex.length; index += 4)
      hex.substring(index, index + 4),
  ].join(' ');
}
