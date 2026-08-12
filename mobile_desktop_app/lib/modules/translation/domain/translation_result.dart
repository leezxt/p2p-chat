class TranslationResult {
  const TranslationResult({
    required this.text,
    required this.fromCache,
  });

  final String text;
  final bool fromCache;
}

class TranslationConsentRequired implements Exception {
  const TranslationConsentRequired();
}

class TranslationProviderUnavailable implements Exception {
  const TranslationProviderUnavailable();
}
