import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/crypto/data/sqlite_replay_protection.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('sender/message 與 sender/nonce 唯一約束可跨 service instance 防 replay',
      () async {
    final directory = await Directory.systemTemp.createTemp('p2p_replay_');
    final database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
      fileName: 'test.db',
    );
    try {
      await database.open(directoryPath: directory.path);
      final first = SqliteReplayProtection(database.db);
      expect(
        await first.acceptOnce(
          senderDeviceId: 'device-a',
          messageId: 'message-1',
          nonce: 'nonce-1',
          receivedAt: 1,
        ),
        isTrue,
      );

      final afterRestart = SqliteReplayProtection(database.db);
      expect(
        await afterRestart.acceptOnce(
          senderDeviceId: 'device-a',
          messageId: 'message-1',
          nonce: 'nonce-2',
          receivedAt: 2,
        ),
        isFalse,
      );
      expect(
        await afterRestart.acceptOnce(
          senderDeviceId: 'device-a',
          messageId: 'message-2',
          nonce: 'nonce-1',
          receivedAt: 2,
        ),
        isFalse,
      );
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
