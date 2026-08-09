abstract interface class TranslationProvider {
  /// 穩定 ID 會成為本機 cache key 的一部分，避免不同供應商混用結果。
  String get id;

  Future<String> translate({
    required String text,
    required String targetLanguage,
  });
}
