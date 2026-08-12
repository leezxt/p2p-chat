import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/storage/data/sqlite_storage_repository.dart';
import 'package:p2p_chat_app/modules/storage/domain/storage_manager_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('預覽會揭露快取並保護未送 mailbox', () async {
    final fixture = await _Fixture.open();
    try {
      await fixture.database.db.insert('storage_cache_entries', {
        'cache_key': 'rebuildable-preview',
        'byte_size': 1536,
        'updated_at': 1,
      });
      await fixture.database.db.insert('mailbox_pending_queue', {
        'id': 'queue-1',
        'message_id': 'message-1',
        'recipient_device_id': 'device-1',
        'encrypted_envelope_json': '{"ciphertext":"protected"}',
        'state': 'PENDING',
        'attempt_count': 0,
        'next_attempt_at': 1,
        'created_at': 1,
        'updated_at': 1,
      });
      final service = StorageManagerService(
        SqliteStorageRepository(fixture.database.db),
      );

      final preview = await service.preview();

      expect(preview.databaseBytes, greaterThan(0));
      expect(preview.cacheBytes, 1536);
      expect(preview.attachmentBytes, 0);
      expect(preview.protectedPendingMailboxBytes, greaterThan(0));
      expect(preview.reclaimableBytes, 1536);
    } finally {
      await fixture.close();
    }
  });

  test('清理只移除可重建快取，不刪未送 mailbox', () async {
    final fixture = await _Fixture.open();
    try {
      await fixture.database.db.insert('storage_cache_entries', {
        'cache_key': 'temporary',
        'byte_size': 42,
        'updated_at': 1,
      });
      await fixture.database.db.insert('mailbox_pending_queue', {
        'id': 'queue-2',
        'message_id': 'message-2',
        'recipient_device_id': 'device-1',
        'encrypted_envelope_json': '{"ciphertext":"must-stay"}',
        'state': 'PENDING',
        'attempt_count': 0,
        'next_attempt_at': 1,
        'created_at': 1,
        'updated_at': 1,
      });
      final service = StorageManagerService(
        SqliteStorageRepository(fixture.database.db),
      );

      expect(await service.clearRebuildableCache(), 42);
      expect(
        await fixture.database.db.query('storage_cache_entries'),
        isEmpty,
      );
      expect(
        await fixture.database.db.query('mailbox_pending_queue'),
        hasLength(1),
      );
    } finally {
      await fixture.close();
    }
  });
}

class _Fixture {
  _Fixture(this.directory, this.database);

  final Directory directory;
  final DatabaseService database;

  static Future<_Fixture> open() async {
    final directory = await Directory.systemTemp.createTemp('p2p_storage_');
    final database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
    );
    await database.open(directoryPath: directory.path);
    return _Fixture(directory, database);
  }

  Future<void> close() async {
    await database.close();
    await directory.delete(recursive: true);
  }
}
