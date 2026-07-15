import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/localization/app_language.dart';
import 'package:p2p_chat_app/core/localization/locale_controller.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/settings/data/sqlite_locale_preference_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('language preference survives database close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp('p2p_locale_');
    DatabaseService? database;
    try {
      database = _database();
      await database.open(directoryPath: directory.path);
      final first = LocaleController(SqliteLocalePreferenceStore(database.db));
      await first.load();
      expect(first.language, AppLanguage.system);
      await first.setLanguage(AppLanguage.english);
      first.dispose();
      await database.close();

      database = _database();
      await database.open(directoryPath: directory.path);
      final restored =
          LocaleController(SqliteLocalePreferenceStore(database.db));
      await restored.load();
      expect(restored.language, AppLanguage.english);
      restored.dispose();
    } finally {
      await database?.close();
      await directory.delete(recursive: true);
    }
  });
}

DatabaseService _database() => DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
      fileName: 'locale.db',
    );
