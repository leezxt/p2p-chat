import 'package:sqflite/sqflite.dart';

import '../domain/replay_protection.dart';

class SqliteReplayProtection implements ReplayProtection {
  SqliteReplayProtection(this._db);

  final Database _db;

  @override
  Future<bool> seen({
    required String senderDeviceId,
    required String messageId,
    required String nonce,
  }) async {
    final rows = await _db.query(
      'crypto_replay_records',
      columns: const ['message_id'],
      where: 'sender_device_id = ? AND (message_id = ? OR nonce = ?)',
      whereArgs: [senderDeviceId, messageId, nonce],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<bool> acceptOnce({
    required String senderDeviceId,
    required String messageId,
    required String nonce,
    required int receivedAt,
  }) async {
    try {
      await _db.insert('crypto_replay_records', {
        'sender_device_id': senderDeviceId,
        'message_id': messageId,
        'nonce': nonce,
        'received_at': receivedAt,
      });
      return true;
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) return false;
      rethrow;
    }
  }
}
