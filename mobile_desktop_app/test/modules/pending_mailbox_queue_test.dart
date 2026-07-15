import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/database/migrations.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/mailbox/data/sqlite_pending_mailbox_queue.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('pending queue 跨 service instance 保存、lease、退避與成功刪除', () async {
    final directory = await Directory.systemTemp.createTemp('p2p_pending_');
    final database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
      fileName: 'test.db',
    );
    try {
      await database.open(directoryPath: directory.path);
      final first = SqlitePendingMailboxQueue(database.db, random: Random(1));
      await first.enqueue(
        id: 'queue-1',
        messageId: 'message-1',
        recipientDeviceId: 'device-b',
        encryptedEnvelopeJson: '{"ciphertext":"redacted"}',
        now: 100,
      );
      await first.enqueue(
        id: 'duplicate',
        messageId: 'message-1',
        recipientDeviceId: 'device-b',
        encryptedEnvelopeJson: '{}',
        now: 100,
      );

      final afterRestart =
          SqlitePendingMailboxQueue(database.db, random: Random(1));
      final claimed = await afterRestart.claimNext(now: 100, leaseSeconds: 30);
      expect(claimed!.id, 'queue-1');
      expect(await afterRestart.claimNext(now: 120), isNull);
      expect((await afterRestart.claimNext(now: 130))!.id, 'queue-1');

      expect(
        await afterRestart.markFailed(
          id: 'queue-1',
          errorCode: 'NETWORK_ERROR',
          now: 130,
        ),
        isFalse,
      );
      expect(await afterRestart.claimNext(now: 134), isNull);
      final retried = await afterRestart.claimNext(now: 136);
      expect(retried!.attemptCount, 1);
      await afterRestart.markSucceeded(retried.id);
      expect(await afterRestart.claimNext(now: 1000), isNull);
      expect(await database.db.getVersion(), kCurrentDbVersion);
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
