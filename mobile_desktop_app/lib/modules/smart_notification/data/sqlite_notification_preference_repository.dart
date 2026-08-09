import 'package:sqflite/sqflite.dart';

import '../domain/notification_preference.dart';

class SqliteNotificationPreferenceRepository {
  SqliteNotificationPreferenceRepository(this._db);

  final Database _db;

  Future<NotificationPreference> get(String conversationId) async {
    final rows = await _db.query(
      'notification_preferences',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return NotificationPreference(conversationId: conversationId);
    }
    final row = rows.single;
    return NotificationPreference(
      conversationId: conversationId,
      muted: row['muted'] == 1,
      allowPreview: row['allow_preview'] == 1,
    );
  }

  Future<void> save(NotificationPreference preference) => _db.insert(
        'notification_preferences',
        {
          'conversation_id': preference.conversationId,
          'muted': preference.muted ? 1 : 0,
          'allow_preview': preference.allowPreview ? 1 : 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
