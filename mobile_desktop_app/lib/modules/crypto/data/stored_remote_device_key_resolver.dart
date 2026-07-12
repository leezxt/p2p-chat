import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../contacts/data/contact_repository.dart';
import '../../devices/data/device_repository.dart';
import '../domain/remote_device_key.dart';
import '../domain/remote_key_trust.dart';
import 'remote_key_trust_repository.dart';

class StoredRemoteDeviceKeyResolver implements RemoteDeviceKeyResolver {
  StoredRemoteDeviceKeyResolver(this._devices, this._contacts, this._trust);

  final DeviceRepository _devices;
  final ContactRepository _contacts;
  final RemoteKeyTrustRepository _trust;

  @override
  Future<RemoteDeviceKey> resolve(String deviceId) async {
    final trust = await _trust.find(deviceId);
    if (trust == null || trust.hasPendingChange) {
      throw RemoteKeyChangeException(deviceId);
    }
    final device = await _devices.findById(deviceId);
    if (device != null &&
        device.revokedAt == null &&
        device.publicKey != null) {
      return _decodeTrusted(deviceId, device.publicKey!, trust);
    }
    final contact = await _contacts.findByDeviceId(deviceId);
    if (contact?.publicKey != null) {
      return _decodeTrusted(deviceId, contact!.publicKey!, trust);
    }
    throw StateError('Remote device key unavailable');
  }

  RemoteDeviceKey _decodeTrusted(
    String deviceId,
    String encoded,
    RemoteKeyTrust trust,
  ) {
    if (encoded != trust.trustedPublicKey) {
      throw RemoteKeyChangeException(deviceId);
    }
    return _decode(deviceId, encoded);
  }

  RemoteDeviceKey _decode(String deviceId, String encoded) {
    final publicKey = base64Url.decode(_withPadding(encoded));
    final digest = sha256.convert(publicKey).bytes;
    final keyId = base64UrlEncode(digest).replaceAll('=', '').substring(0, 22);
    return RemoteDeviceKey(
      deviceId: deviceId,
      keyId: keyId,
      publicKey: publicKey,
    );
  }

  String _withPadding(String value) =>
      '$value${'=' * ((4 - value.length % 4) % 4)}';
}
