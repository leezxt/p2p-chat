import 'dart:typed_data';

class RemoteDeviceKey {
  RemoteDeviceKey({
    required this.deviceId,
    required this.keyId,
    required Uint8List publicKey,
  }) : _publicKey = Uint8List.fromList(publicKey);

  final String deviceId;
  final String keyId;
  final Uint8List _publicKey;

  Uint8List get publicKey => Uint8List.fromList(_publicKey);
}

abstract class RemoteDeviceKeyResolver {
  Future<RemoteDeviceKey> resolve(String deviceId);
}
