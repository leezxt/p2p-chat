import 'dart:ui';

enum AppLanguage {
  system('system'),
  traditionalChinese('zh_TW'),
  english('en');

  const AppLanguage(this.storageValue);

  final String storageValue;

  Locale? get locale => switch (this) {
        AppLanguage.system => null,
        AppLanguage.traditionalChinese => const Locale('zh', 'TW'),
        AppLanguage.english => const Locale('en'),
      };

  static AppLanguage fromStorage(String? value) => switch (value) {
        'zh_TW' => AppLanguage.traditionalChinese,
        'en' => AppLanguage.english,
        _ => AppLanguage.system,
      };
}

Locale resolveSupportedLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  final supported = supportedLocales.toList(growable: false);
  const fallback = Locale('zh', 'TW');
  for (final preferred in preferredLocales ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == preferred.languageCode &&
          candidate.countryCode == preferred.countryCode) {
        return candidate;
      }
    }
    for (final candidate in supported) {
      if (candidate.languageCode == preferred.languageCode) return candidate;
    }
  }
  return supported.contains(fallback) ? fallback : supported.first;
}
