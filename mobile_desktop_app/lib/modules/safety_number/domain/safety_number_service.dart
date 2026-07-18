import 'dart:convert';
import 'dart:typed_data';

import '../../contacts/data/contact_repository.dart';
import '../../identity/domain/identity_session.dart';
import '../data/safety_number_verification_repository.dart';
import 'safety_number.dart';

class SafetyNumberService {
  SafetyNumberService({
    required IdentitySession identity,
    required Uint8List localPublicKey,
    required ContactRepository contacts,
    required SafetyNumberVerificationRepository verifications,
  })  : _identity = identity,
        _localPublicKey = Uint8List.fromList(localPublicKey),
        _contacts = contacts,
        _verifications = verifications;

  final IdentitySession _identity;
  final Uint8List _localPublicKey;
  final ContactRepository _contacts;
  final SafetyNumberVerificationRepository _verifications;

  Future<SafetyNumber> forContact(String remoteUserId) async {
    final contact = await _contacts.findByUserId(remoteUserId);
    if (contact == null ||
        contact.deviceId == null ||
        contact.publicKey == null) {
      throw StateError('Contact device key is unavailable');
    }
    final remoteKey = _decodePublicKey(contact.publicKey!);
    final local = SafetyNumberParticipant(
      userId: _identity.userId,
      deviceId: _identity.deviceId,
      publicKey: _localPublicKey,
    );
    final remote = SafetyNumberParticipant(
      userId: contact.userId,
      deviceId: contact.deviceId!,
      publicKey: remoteKey,
    );
    final unverified = SafetyNumber.generate(
      local: local,
      remote: remote,
    );
    final verification = await _verifications.find(contact.deviceId!);
    final verified = verification?.digest == unverified.digest;
    return SafetyNumber.generate(
      local: SafetyNumberParticipant(
        userId: local.userId,
        deviceId: local.deviceId,
        publicKey: local.publicKey,
      ),
      remote: SafetyNumberParticipant(
        userId: remote.userId,
        deviceId: remote.deviceId,
        publicKey: remote.publicKey,
      ),
      verified: verified,
      verifiedAt: verified ? verification!.verifiedAt : null,
    );
  }

  Future<void> markVerified(SafetyNumber safetyNumber) => _verifications.save(
        remoteDeviceId: _remoteParticipant(safetyNumber).deviceId,
        digest: safetyNumber.digest,
      );

  Future<bool> verifyQrPayload(String remoteUserId, String payload) async {
    final current = await forContact(remoteUserId);
    if (!current.matchesQrPayload(payload)) return false;
    await markVerified(current);
    return true;
  }

  SafetyNumberParticipant _remoteParticipant(SafetyNumber safetyNumber) =>
      safetyNumber.participants.firstWhere(
        (participant) =>
            participant.userId != _identity.userId ||
            participant.deviceId != _identity.deviceId,
      );

  Uint8List _decodePublicKey(String encoded) {
    final padded = '$encoded${'=' * ((4 - encoded.length % 4) % 4)}';
    final decoded = base64Url.decode(padded);
    if (decoded.length != 32) {
      throw const FormatException(
          'Remote device public key has invalid length');
    }
    return Uint8List.fromList(decoded);
  }
}
