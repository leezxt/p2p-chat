import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/database/migrations.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  for (var oldVersion = 1; oldVersion < kCurrentDbVersion; oldVersion++) {
    test(
        'schema v$oldVersion upgrades to v$kCurrentDbVersion without losing existing data',
        () async {
      final directory = await Directory.systemTemp.createTemp(
        'p2p_migration_v${oldVersion}_',
      );
      DatabaseService? upgraded;
      try {
        await _createFixture(directory.path, oldVersion);
        upgraded = DatabaseService(
          databaseFactory: databaseFactoryFfi,
          logger: LoggingService(),
          fileName: 'fixture.db',
        );
        await upgraded.open(directoryPath: directory.path);

        expect(await upgraded.db.getVersion(), kCurrentDbVersion);
        await _expectRow(upgraded, 'chat_conversations', 'conversation-1');
        await _expectRow(upgraded, 'chat_messages', 'message-1');

        if (oldVersion >= 2) {
          await _expectRow(
            upgraded,
            'local_identities',
            'user-local',
            idColumn: 'user_id',
          );
          await _expectRow(upgraded, 'devices', 'device-local');
          await _expectRow(
            upgraded,
            'contacts',
            'user-contact',
            idColumn: 'user_id',
          );
          await _expectRow(
            upgraded,
            'remote_key_trust',
            'device-contact',
            idColumn: 'device_id',
          );
        }
        if (oldVersion >= 3) {
          await _expectRow(
            upgraded,
            'crypto_replay_records',
            'message-replay',
            idColumn: 'message_id',
          );
        }
        if (oldVersion >= 5) {
          await _expectRow(upgraded, 'mailbox_pending_queue', 'queue-1');
        }

        final tables = await upgraded.db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        );
        expect(
          tables.map((row) => row['name']),
          containsAll(const [
            'crypto_replay_records',
            'remote_key_trust',
            'mailbox_pending_queue',
            'mailbox_receipts',
            'app_settings',
            'safety_number_verifications',
          ]),
        );
      } finally {
        await upgraded?.close();
        await directory.delete(recursive: true);
      }
    });
  }
}

Future<void> _createFixture(String directory, int version) async {
  final path = '$directory${Platform.pathSeparator}fixture.db';
  final database = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: version,
      onCreate: (db, _) async {
        for (final migration in kMigrations) {
          if (migration.version > version) break;
          for (final statement in migration.statements) {
            await db.execute(statement);
          }
        }
      },
    ),
  );
  try {
    await database.insert('chat_conversations', const {
      'id': 'conversation-1',
      'title': 'Existing chat',
      'peer_user_id': 'user-contact',
      'created_at': 1,
      'updated_at': 2,
    });
    await database.insert('chat_messages', const {
      'id': 'message-1',
      'conversation_id': 'conversation-1',
      'sender_user_id': 'user-contact',
      'sender_device_id': 'device-contact',
      'type': 'TEXT',
      'payload_json': '{"text":"existing"}',
      'status': 'DELIVERED',
      'created_at': 1,
      'updated_at': 2,
      'schema_version': 1,
    });

    if (version >= 2) {
      await database.insert('local_identities', const {
        'user_id': 'user-local',
        'display_name': 'Local user',
        'created_at': 1,
        'updated_at': 2,
      });
      await database.insert('devices', const {
        'id': 'device-local',
        'user_id': 'user-local',
        'name': 'Local device',
        'public_key': 'local-public-key',
        'public_key_fingerprint': 'local-fingerprint',
        'is_local': 1,
        'created_at': 1,
        'updated_at': 2,
      });
      await database.insert('contacts', const {
        'user_id': 'user-contact',
        'display_name': 'Existing contact',
        'device_id': 'device-contact',
        'public_key': 'contact-public-key',
        'public_key_fingerprint': 'contact-fingerprint',
        'created_at': 1,
        'updated_at': 2,
      });
    }
    if (version >= 3) {
      await database.insert('crypto_replay_records', const {
        'sender_device_id': 'device-contact',
        'message_id': 'message-replay',
        'nonce': 'existing-nonce',
        'received_at': 2,
      });
    }
    if (version >= 4) {
      await database.insert('remote_key_trust', const {
        'device_id': 'device-contact',
        'trusted_public_key': 'contact-public-key',
        'trusted_fingerprint': 'contact-fingerprint',
        'trusted_at': 2,
        'updated_at': 2,
      });
    }
    if (version >= 5) {
      await database.insert('mailbox_pending_queue', const {
        'id': 'queue-1',
        'message_id': 'message-pending',
        'recipient_device_id': 'device-contact',
        'encrypted_envelope_json': '{}',
        'state': 'PENDING',
        'attempt_count': 0,
        'next_attempt_at': 2,
        'created_at': 1,
        'updated_at': 2,
      });
    }
  } finally {
    await database.close();
  }
}

Future<void> _expectRow(
  DatabaseService database,
  String table,
  String id, {
  String idColumn = 'id',
}) async {
  final rows = await database.db.query(
    table,
    where: '$idColumn = ?',
    whereArgs: [id],
  );
  expect(rows, hasLength(1), reason: '$table should preserve $id');
}
