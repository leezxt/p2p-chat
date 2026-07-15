import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/localization/app_language.dart';
import 'package:p2p_chat_app/core/localization/locale_controller.dart';
import 'package:p2p_chat_app/core/localization/locale_preference_store.dart';

void main() {
  test('loads a saved language and persists changes before notifying',
      () async {
    final store = _MemoryLocaleStore('en');
    final controller = LocaleController(store);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.load();
    expect(controller.language, AppLanguage.english);
    expect(controller.locale, const Locale('en'));
    expect(notifications, 0);

    await controller.setLanguage(AppLanguage.traditionalChinese);
    expect(store.value, 'zh_TW');
    expect(controller.locale, const Locale('zh', 'TW'));
    expect(notifications, 1);
  });

  test('invalid saved values fail closed to system language', () async {
    final controller = LocaleController(_MemoryLocaleStore('unsupported'));
    await controller.load();
    expect(controller.language, AppLanguage.system);
    expect(controller.locale, isNull);
  });

  test('locale resolution prefers exact, then language, then zh-TW fallback',
      () {
    const supported = [Locale('en'), Locale('zh'), Locale('zh', 'TW')];
    expect(
      resolveSupportedLocale(const [Locale('en', 'US')], supported),
      const Locale('en'),
    );
    expect(
      resolveSupportedLocale(const [Locale('zh', 'TW')], supported),
      const Locale('zh', 'TW'),
    );
    expect(
      resolveSupportedLocale(const [Locale('ja', 'JP')], supported),
      const Locale('zh', 'TW'),
    );
  });
}

class _MemoryLocaleStore implements LocalePreferenceStore {
  _MemoryLocaleStore(this.value);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
