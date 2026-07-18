import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/contacts/data/contact_repository.dart';
import 'package:p2p_chat_app/modules/contacts/domain/contact.dart';
import 'package:p2p_chat_app/modules/identity/domain/identity_session.dart';
import 'package:p2p_chat_app/modules/safety_number/data/safety_number_verification_repository.dart';
import 'package:p2p_chat_app/modules/safety_number/domain/safety_number_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('verification persists and a remote key change invalidates it',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('p2p_safety_number_');
    final database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
      fileName: 'test.db',
    );
    try {
      await database.open(directoryPath: directory.path);
      final contacts = ContactRepository(database.db);
      final verifications = SafetyNumberVerificationRepository(database.db);
      final service = SafetyNumberService(
        identity: const IdentitySession(
          userId: 'alice',
          deviceId: 'alice-phone',
        ),
        localPublicKey: _key(0),
        contacts: contacts,
        verifications: verifications,
      );
      await contacts.upsert(_contact(_key(32)));

      final initial = await service.forContact('bob');
      expect(initial.verified, isFalse);
      expect(await service.verifyQrPayload('bob', initial.qrPayload), isTrue);
      expect((await service.forContact('bob')).verified, isTrue);

      await contacts.upsert(_contact(_key(64)));
      final changed = await service.forContact('bob');
      expect(changed.digest, isNot(initial.digest));
      expect(changed.verified, isFalse);
      expect(await service.verifyQrPayload('bob', initial.qrPayload), isFalse);
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}

Contact _contact(Uint8List publicKey) => Contact(
      userId: 'bob',
      displayName: 'Bob',
      deviceId: 'bob-phone',
      publicKey: base64UrlEncode(publicKey).replaceAll('=', ''),
      publicKeyFingerprint: 'test-fingerprint',
      createdAt: 1,
      updatedAt: 1,
    );

Uint8List _key(int offset) =>
    Uint8List.fromList(List.generate(32, (index) => index + offset));
