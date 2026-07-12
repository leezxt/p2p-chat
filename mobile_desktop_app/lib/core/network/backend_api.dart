import '../../modules/identity/domain/identity_session.dart';

class AccessSession {
  const AccessSession(this.token, this.expiresAt);
  final String token;
  final DateTime expiresAt;
}

class InviteResult {
  const InviteResult(this.code, this.expiresAt);
  final String code;
  final DateTime expiresAt;
  String get qrPayload => 'p2pchat://invite/$code';
}

class RedeemedContact {
  const RedeemedContact(this.userId, this.displayName, this.deviceId,
      this.publicKey, this.publicKeyFingerprint);
  final String userId;
  final String displayName;
  final String deviceId;
  final String publicKey;
  final String publicKeyFingerprint;
}

abstract class BackendApi {
  Future<AccessSession> register(
    IdentitySession identity,
    String displayName, {
    required String publicKey,
    required String publicKeyFingerprint,
  });
  Future<void> initializeDeviceKey(
    String token,
    String deviceId, {
    required String publicKey,
    required String publicKeyFingerprint,
  });
  Future<InviteResult> createInvite(String token);
  Future<RedeemedContact> redeemInvite(String token, String codeOrQrPayload);
  Future<List<RedeemedContact>> listContacts(String token) =>
      throw UnimplementedError('Contact sync is unavailable');
}
