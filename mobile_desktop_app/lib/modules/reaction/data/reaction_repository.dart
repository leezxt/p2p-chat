import 'package:sqflite/sqflite.dart';

import '../../../shared/models/message_envelope.dart';
import '../domain/reaction_event.dart';

/// Materializes reaction events into one deterministic state per
/// message/reactor/emoji tuple.
class ReactionRepository {
  ReactionRepository(this._db);

  final Database _db;

  Future<bool> applyEnvelope(MessageEnvelope envelope) =>
      apply(ReactionEvent.fromEnvelope(envelope));

  /// Applies only events newer than the current state. [eventId] is the stable
  /// tie-breaker when two events have the same timestamp.
  Future<bool> apply(ReactionEvent event) => _db.transaction((txn) async {
        final rows = await txn.query(
          'message_reactions',
          columns: ['event_id', 'updated_at'],
          where: 'target_message_id = ? AND reactor_user_id = ? AND emoji = ?',
          whereArgs: [
            event.targetMessageId,
            event.reactorUserId,
            event.emoji,
          ],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final currentAt = rows.first['updated_at'] as int;
          final currentId = rows.first['event_id'] as String;
          if (event.updatedAt < currentAt ||
              (event.updatedAt == currentAt &&
                  event.eventId.compareTo(currentId) <= 0)) {
            return false;
          }
        }
        await txn.insert(
          'message_reactions',
          {
            'target_message_id': event.targetMessageId,
            'reactor_user_id': event.reactorUserId,
            'emoji': event.emoji,
            'active': event.active ? 1 : 0,
            'event_id': event.eventId,
            'updated_at': event.updatedAt,
            'schema_version': event.version,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      });

  Future<List<ReactionEvent>> listActiveForMessage(String messageId) async {
    final rows = await _db.query(
      'message_reactions',
      where: 'target_message_id = ? AND active = 1',
      whereArgs: [messageId],
      orderBy: 'emoji ASC, reactor_user_id ASC',
    );
    return rows
        .map((row) => ReactionEvent(
              eventId: row['event_id'] as String,
              targetMessageId: row['target_message_id'] as String,
              reactorUserId: row['reactor_user_id'] as String,
              emoji: row['emoji'] as String,
              active: (row['active'] as int) == 1,
              updatedAt: row['updated_at'] as int,
              version: row['schema_version'] as int,
            ))
        .toList(growable: false);
  }
}
