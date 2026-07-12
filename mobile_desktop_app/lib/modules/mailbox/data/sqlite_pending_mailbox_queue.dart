import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../domain/pending_mailbox_item.dart';

class SqlitePendingMailboxQueue {
  SqlitePendingMailboxQueue(this._db, {Random? random})
      : _random = random ?? Random.secure();

  static const maxAttempts = 8;
  static const _baseDelaySeconds = 5;
  static const _maxDelaySeconds = 15 * 60;

  final Database _db;
  final Random _random;

  Future<void> enqueue({
    required String id,
    required String messageId,
    required String recipientDeviceId,
    required String encryptedEnvelopeJson,
    required int now,
  }) async {
    await _db.insert(
      'mailbox_pending_queue',
      {
        'id': id,
        'message_id': messageId,
        'recipient_device_id': recipientDeviceId,
        'encrypted_envelope_json': encryptedEnvelopeJson,
        'state': 'PENDING',
        'attempt_count': 0,
        'next_attempt_at': now,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<PendingMailboxItem?> claimNext({
    required int now,
    int leaseSeconds = 30,
  }) =>
      _db.transaction((txn) async {
        final rows = await txn.query(
          'mailbox_pending_queue',
          where: "(state = 'PENDING' AND next_attempt_at <= ?) OR "
              "(state = 'IN_FLIGHT' AND lease_until <= ?)",
          whereArgs: [now, now],
          orderBy: 'next_attempt_at ASC, created_at ASC',
          limit: 1,
        );
        if (rows.isEmpty) return null;
        final row = rows.single;
        await txn.update(
          'mailbox_pending_queue',
          {
            'state': 'IN_FLIGHT',
            'lease_until': now + leaseSeconds,
            'updated_at': now
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        return _item(row);
      });

  Future<void> markSucceeded(String id) =>
      _db.delete('mailbox_pending_queue', where: 'id = ?', whereArgs: [id]);

  Future<bool> markFailed({
    required String id,
    required String errorCode,
    required int now,
  }) async {
    final rows = await _db.query(
      'mailbox_pending_queue',
      columns: const ['attempt_count'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return true;
    final attempts = (rows.single['attempt_count'] as int) + 1;
    final exhausted = attempts >= maxAttempts;
    final delay = _retryDelaySeconds(attempts);
    await _db.update(
      'mailbox_pending_queue',
      {
        'state': exhausted ? 'FAILED' : 'PENDING',
        'attempt_count': attempts,
        'next_attempt_at': now + delay,
        'lease_until': null,
        'last_error_code': errorCode,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return exhausted;
  }

  int _retryDelaySeconds(int attempts) {
    final exponential = min(
      _baseDelaySeconds * (1 << min(attempts - 1, 16)),
      _maxDelaySeconds,
    );
    return exponential + _random.nextInt(max(1, exponential ~/ 5 + 1));
  }

  static PendingMailboxItem _item(Map<String, Object?> row) =>
      PendingMailboxItem(
        id: row['id'] as String,
        messageId: row['message_id'] as String,
        recipientDeviceId: row['recipient_device_id'] as String,
        encryptedEnvelopeJson: row['encrypted_envelope_json'] as String,
        attemptCount: row['attempt_count'] as int,
      );
}
