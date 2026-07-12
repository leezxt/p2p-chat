import 'dart:convert';
import 'dart:typed_data';

import '../../../core/events/event_bus.dart';
import '../../../core/network/backend_api.dart';
import '../../crypto/data/remote_key_trust_repository.dart';
import '../../crypto/domain/device_key_fingerprint.dart';
import '../../crypto/domain/remote_key_trust.dart';
import '../data/contact_repository.dart';
import 'contact.dart';

class ContactService {
  ContactService(
    this._api,
    this._access,
    this._repository, {
    required RemoteKeyTrustRepository keyTrust,
    required EventBus eventBus,
  })  : _keyTrust = keyTrust,
        _eventBus = eventBus;
  final BackendApi _api;
  final AccessSession _access;
  final ContactRepository _repository;
  final RemoteKeyTrustRepository _keyTrust;
  final EventBus _eventBus;

  Future<InviteResult> createInvite() => _api.createInvite(_access.token);
  Future<Contact> redeemInvite(String codeOrQrPayload) async {
    final remote = await _api.redeemInvite(_access.token, codeOrQrPayload);
    return _saveRemote(remote);
  }

  Future<void> syncContacts() async {
    for (final remote in await _api.listContacts(_access.token)) {
      await _saveRemote(remote);
    }
  }

  Future<Contact> _saveRemote(RedeemedContact remote) async {
    final publicKey = _decodePublicKey(remote.publicKey);
    if (computeDeviceKeyFingerprint(remote.deviceId, publicKey) !=
        remote.publicKeyFingerprint) {
      throw const FormatException('Remote device key fingerprint mismatch');
    }
    final observation = await _keyTrust.observe(
      deviceId: remote.deviceId,
      publicKey: remote.publicKey,
      fingerprint: remote.publicKeyFingerprint,
    );
    if (observation == RemoteKeyObservation.changePending) {
      final trust = await _keyTrust.find(remote.deviceId);
      _eventBus.emit(RemoteDeviceKeyChanged(
        deviceId: remote.deviceId,
        trustedFingerprint: trust!.trustedFingerprint,
        pendingFingerprint: remote.publicKeyFingerprint,
      ));
      throw RemoteKeyChangeException(remote.deviceId);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final contact = Contact(
        userId: remote.userId,
        displayName: remote.displayName,
        deviceId: remote.deviceId,
        publicKey: remote.publicKey,
        publicKeyFingerprint: remote.publicKeyFingerprint,
        createdAt: now,
        updatedAt: now);
    await _repository.upsert(contact);
    return contact;
  }

  Uint8List _decodePublicKey(String encoded) {
    final padded = '$encoded${'=' * ((4 - encoded.length % 4) % 4)}';
    final decoded = base64Url.decode(padded);
    if (decoded.length != 32) {
      throw const FormatException(
          'Remote device public key has invalid length');
    }
    return Uint8List.fromList(decoded);
  }

  Future<Contact> trustPendingKey(String deviceId) async {
    final trust = await _keyTrust.trustPending(deviceId);
    final existing = await _repository.findByDeviceId(deviceId);
    if (existing == null) throw StateError('Contact unavailable');
    final updated = Contact(
      userId: existing.userId,
      displayName: existing.displayName,
      deviceId: existing.deviceId,
      publicKey: trust.trustedPublicKey,
      publicKeyFingerprint: trust.trustedFingerprint,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _repository.upsert(updated);
    return updated;
  }
}
