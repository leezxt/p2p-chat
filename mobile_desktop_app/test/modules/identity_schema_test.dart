import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/database/migrations.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/identity/data/identity_repository.dart';
import 'package:p2p_chat_app/shared/utils/id_generator.dart';

void main() {
  sqfliteFfiInit();
  test('目前 schema 建立 identity、device、contact、crypto、mailbox、安全碼與設定資料表',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('p2p_identity_schema_');
    final service = DatabaseService(
        databaseFactory: databaseFactoryFfi,
        logger: LoggingService(),
        fileName: 'test.db');
    try {
      await service.open(directoryPath: directory.path);
      final tables = await service.db
          .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      expect(
          tables.map((row) => row['name']),
          containsAll([
            'local_identities',
            'devices',
            'contacts',
            'crypto_replay_records',
            'remote_key_trust',
            'mailbox_pending_queue',
            'mailbox_receipts',
            'app_settings',
            'safety_number_verifications',
            'message_reactions',
            'storage_cache_entries',
            'notification_preferences',
            'message_translations',
            'desktop_link_authorizations',
          ]));
      expect(await service.db.getVersion(), kCurrentDbVersion);
      final repository = IdentityRepository(service.db);
      final first = await repository.getOrCreateLocalIdentity(IdGenerator());
      final second = await repository.getOrCreateLocalIdentity(IdGenerator());
      expect(second.userId, first.userId);
      expect(second.deviceId, first.deviceId);
    } finally {
      await service.close();
      await directory.delete(recursive: true);
    }
  });
}
