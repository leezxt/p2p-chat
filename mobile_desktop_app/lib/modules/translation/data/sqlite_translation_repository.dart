import 'package:sqflite/sqflite.dart';

class CachedTranslation {
  const CachedTranslation({
    required this.sourceHash,
    required this.text,
  });

  final String sourceHash;
  final String text;
}

class SqliteTranslationRepository {
  SqliteTranslationRepository(this._db);

  static const _consentKey = 'translation_explicit_opt_in';
  final Database _db;

  Future<bool> hasConsent() async {
    final rows = await _db.query(
      'app_settings',
      columns: const ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: const [_consentKey],
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['setting_value'] == 'true';
  }

  Future<void> saveConsent(bool value) => _db.insert(
        'app_settings',
        {
          'setting_key': _consentKey,
          'setting_value': value.toString(),
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<CachedTranslation?> find({
    required String messageId,
    required String providerId,
    required String targetLanguage,
  }) async {
    final rows = await _db.query(
      'message_translations',
      where: 'message_id = ? AND provider_id = ? AND target_language = ?',
      whereArgs: [messageId, providerId, targetLanguage],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return CachedTranslation(
      sourceHash: row['source_hash']! as String,
      text: row['translated_text']! as String,
    );
  }

  Future<void> save({
    required String messageId,
    required String providerId,
    required String targetLanguage,
    required String sourceHash,
    required String translatedText,
  }) =>
      _db.insert(
        'message_translations',
        {
          'message_id': messageId,
          'provider_id': providerId,
          'target_language': targetLanguage,
          'source_hash': sourceHash,
          'translated_text': translatedText,
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<int> clearMessage(String messageId) => _db.delete(
        'message_translations',
        where: 'message_id = ?',
        whereArgs: [messageId],
      );
}
