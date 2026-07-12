import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/core/network/backend_api.dart';
import 'package:p2p_chat_app/modules/contacts/data/contact_repository.dart';
import 'package:p2p_chat_app/modules/contacts/domain/contact_service.dart';
import 'package:p2p_chat_app/modules/crypto/data/remote_key_trust_repository.dart';
import 'package:p2p_chat_app/modules/crypto/data/stored_remote_device_key_resolver.dart';
import 'package:p2p_chat_app/modules/crypto/domain/remote_key_trust.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_fingerprint.dart';
import 'package:p2p_chat_app/modules/devices/data/device_repository.dart';
import 'package:p2p_chat_app/modules/identity/domain/identity_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('公鑰變更會阻斷解析，明確重新信任後才使用新 key', () async {
    final directory = await Directory.systemTemp.createTemp('p2p_key_trust_');
    final database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
      fileName: 'test.db',
    );
    try {
      await database.open(directoryPath: directory.path);
      final contacts = ContactRepository(database.db);
      final trust = RemoteKeyTrustRepository(database.db);
      final events = EventBus();
      final api = _RotatingBackend();
      final service = ContactService(
        api,
        AccessSession('token', DateTime.now().add(const Duration(minutes: 1))),
        contacts,
        keyTrust: trust,
        eventBus: events,
      );
      final resolver = StoredRemoteDeviceKeyResolver(
        DeviceRepository(database.db),
        contacts,
        trust,
      );

      final securityEvents = <RemoteDeviceKeyChanged>[];
      events.on<RemoteDeviceKeyChanged>(securityEvents.add);
      final original = await service.redeemInvite('invite');
      expect((await resolver.resolve('peer-device')).publicKey,
          base64Url.decode(_withPadding(original.publicKey!)));

      api.rotate();
      await expectLater(
        service.redeemInvite('invite'),
        throwsA(isA<RemoteKeyChangeException>()),
      );
      expect(securityEvents, hasLength(1));
      expect(securityEvents.single.trustedFingerprint, api.fingerprintFor(1));
      expect(securityEvents.single.pendingFingerprint, api.fingerprintFor(2));
      await expectLater(
        resolver.resolve('peer-device'),
        throwsA(isA<RemoteKeyChangeException>()),
      );
      expect((await contacts.findByDeviceId('peer-device'))!.publicKey,
          original.publicKey);

      final updated = await service.trustPendingKey('peer-device');
      expect(updated.publicKeyFingerprint, api.fingerprintFor(2));
      expect((await resolver.resolve('peer-device')).publicKey,
          base64Url.decode(_withPadding(updated.publicKey!)));
      expect((await trust.find('peer-device'))!.hasPendingChange, isFalse);
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}

class _RotatingBackend implements BackendApi {
  var _rotated = false;

  void rotate() => _rotated = true;

  String fingerprintFor(int byte) => computeDeviceKeyFingerprint(
        'peer-device',
        Uint8List.fromList(List<int>.filled(32, byte)),
      );

  @override
  Future<RedeemedContact> redeemInvite(String token, String code) async {
    final byte = _rotated ? 2 : 1;
    return RedeemedContact(
      'peer-user',
      'Peer',
      'peer-device',
      base64UrlEncode(List<int>.filled(32, byte)).replaceAll('=', ''),
      fingerprintFor(byte),
    );
  }

  @override
  Future<InviteResult> createInvite(String token) => throw UnimplementedError();

  @override
  Future<List<RedeemedContact>> listContacts(String token) async => const [];

  @override
  Future<void> initializeDeviceKey(
    String token,
    String deviceId, {
    required String publicKey,
    required String publicKeyFingerprint,
  }) =>
      throw UnimplementedError();

  @override
  Future<AccessSession> register(
    IdentitySession identity,
    String displayName, {
    required String publicKey,
    required String publicKeyFingerprint,
  }) =>
      throw UnimplementedError();
}

String _withPadding(String value) =>
    '$value${'=' * ((4 - value.length % 4) % 4)}';
