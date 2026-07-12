import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/network/backend_api.dart';
import 'package:p2p_chat_app/modules/contacts/data/contact_repository.dart';
import 'package:p2p_chat_app/modules/contacts/domain/contact.dart';
import 'package:p2p_chat_app/modules/contacts/domain/contact_service.dart';
import 'package:p2p_chat_app/modules/crypto/data/remote_key_trust_repository.dart';
import 'package:p2p_chat_app/modules/crypto/domain/remote_key_trust.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_fingerprint.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/modules/identity/domain/identity_session.dart';

void main() {
  test('QR payload 兌換後寫入聯絡人 repository', () async {
    final api = _FakeBackend();
    final repository = _FakeContactRepository();
    final service = ContactService(
        api,
        AccessSession('token', DateTime.now().add(const Duration(minutes: 1))),
        repository,
        keyTrust: _FakeKeyTrustRepository(),
        eventBus: EventBus());
    final contact = await service.redeemInvite('p2pchat://invite/code-123');
    expect(api.redeemedCode, 'p2pchat://invite/code-123');
    expect(contact.userId, 'peer-user');
    expect(repository.saved, isNotNull);
  });
}

class _FakeKeyTrustRepository implements RemoteKeyTrustRepository {
  @override
  Future<RemoteKeyObservation> observe({
    required String deviceId,
    required String publicKey,
    required String fingerprint,
  }) async =>
      RemoteKeyObservation.firstTrusted;

  @override
  Future<RemoteKeyTrust?> find(String deviceId) async => null;

  @override
  Future<RemoteKeyTrust> trustPending(String deviceId) =>
      throw UnimplementedError();
}

class _FakeBackend implements BackendApi {
  String? redeemedCode;
  @override
  Future<RedeemedContact> redeemInvite(String token, String code) async {
    redeemedCode = code;
    final publicKey = Uint8List.fromList(List<int>.filled(32, 1));
    return RedeemedContact(
      'peer-user',
      'Peer',
      'peer-device',
      base64UrlEncode(publicKey).replaceAll('=', ''),
      computeDeviceKeyFingerprint('peer-device', publicKey),
    );
  }

  @override
  Future<InviteResult> createInvite(String token) async =>
      InviteResult('code-123', DateTime.now());

  @override
  Future<List<RedeemedContact>> listContacts(String token) async => const [];

  @override
  Future<void> initializeDeviceKey(
    String token,
    String deviceId, {
    required String publicKey,
    required String publicKeyFingerprint,
  }) async {}
  @override
  Future<AccessSession> register(
    IdentitySession identity,
    String displayName, {
    required String publicKey,
    required String publicKeyFingerprint,
  }) =>
      throw UnimplementedError();
}

class _FakeContactRepository implements ContactRepository {
  Object? saved;
  @override
  Future<void> upsert(contact) async {
    saved = contact;
  }

  @override
  Future<List<Map<String, Object?>>> list() async => [];

  @override
  Future<Contact?> findByDeviceId(String deviceId) async => null;

  @override
  Future<Contact?> findByUserId(String userId) async => null;
}
