import 'package:sqflite/sqflite.dart';

import '../domain/mailbox_ack.dart';

class SqliteMailboxReceipts {
  SqliteMailboxReceipts(this._db);
  final Database _db;

  Future<void> save({
    required String messageId,
    required String mailboxMessageId,
    required String deviceId,
    required MailboxDeliveryState status,
    required int now,
  }) =>
      _db.insert(
        'mailbox_receipts',
        {
          'message_id': messageId,
          'mailbox_message_id': mailboxMessageId,
          'acknowledging_device_id': deviceId,
          'ack_status': status.wire,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<Map<String, Object?>?> find(String messageId) async {
    final rows = await _db.query(
      'mailbox_receipts',
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }
}
