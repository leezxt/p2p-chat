import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'app_language.dart';
import 'locale_preference_store.dart';

class LocaleController extends ChangeNotifier {
  LocaleController(this._store);

  final LocalePreferenceStore _store;
  AppLanguage _language = AppLanguage.system;

  AppLanguage get language => _language;
  Locale? get locale => _language.locale;

  Future<void> load() async {
    _language = AppLanguage.fromStorage(await _store.read());
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    await _store.write(language.storageValue);
    _language = language;
    notifyListeners();
  }
}
