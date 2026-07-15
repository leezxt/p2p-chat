import 'package:sqflite/sqflite.dart';

import '../../../core/localization/locale_preference_store.dart';

class SqliteLocalePreferenceStore implements LocalePreferenceStore {
  SqliteLocalePreferenceStore(this._database);

  static const _key = 'locale';
  final Database _database;

  @override
  Future<String?> read() async {
    final rows = await _database.query(
      'app_settings',
      columns: const ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: const [_key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['setting_value'] as String;
  }

  @override
  Future<void> write(String value) async {
    await _database.insert(
      'app_settings',
      {
        'setting_key': _key,
        'setting_value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
