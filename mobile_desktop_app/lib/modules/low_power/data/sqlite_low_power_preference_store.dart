import 'package:sqflite/sqflite.dart';

import '../domain/low_power_preference_store.dart';

class SqliteLowPowerPreferenceStore implements LowPowerPreferenceStore {
  SqliteLowPowerPreferenceStore(this._database);

  static const _key = 'low_power_mode';
  final Database _database;

  @override
  Future<bool?> read() async {
    final rows = await _database.query(
      'app_settings',
      columns: const ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: const [_key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return switch (rows.single['setting_value']) {
      '1' => true,
      '0' => false,
      _ => null,
    };
  }

  @override
  Future<void> write(bool enabled) async {
    await _database.insert(
      'app_settings',
      {
        'setting_key': _key,
        'setting_value': enabled ? '1' : '0',
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
