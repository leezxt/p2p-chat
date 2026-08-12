import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/sqlite_translation_repository.dart';
import 'translation_provider.dart';
import 'translation_result.dart';

/// 只在使用者明確 opt-in 後呼叫 provider，且永遠不改寫聊天室原文。
class TranslationService {
  TranslationService({
    required SqliteTranslationRepository repository,
    TranslationProvider? provider,
  })  : _repository = repository,
        _provider = provider;

  final SqliteTranslationRepository _repository;
  final TranslationProvider? _provider;

  bool get isProviderConfigured => _provider != null;

  Future<bool> hasConsent() => _repository.hasConsent();

  Future<void> setConsent(bool enabled) => _repository.saveConsent(enabled);

  Future<TranslationResult> translate({
    required String messageId,
    required String sourceText,
    required String targetLanguage,
  }) async {
    if (!await hasConsent()) throw const TranslationConsentRequired();
    final provider = _provider;
    if (provider == null) throw const TranslationProviderUnavailable();
    final sourceHash = sha256.convert(utf8.encode(sourceText)).toString();
    final cached = await _repository.find(
      messageId: messageId,
      providerId: provider.id,
      targetLanguage: targetLanguage,
    );
    if (cached != null && cached.sourceHash == sourceHash) {
      return TranslationResult(text: cached.text, fromCache: true);
    }
    final translated = await provider.translate(
      text: sourceText,
      targetLanguage: targetLanguage,
    );
    await _repository.save(
      messageId: messageId,
      providerId: provider.id,
      targetLanguage: targetLanguage,
      sourceHash: sourceHash,
      translatedText: translated,
    );
    return TranslationResult(text: translated, fromCache: false);
  }

  Future<void> clearMessageCache(String messageId) async {
    await _repository.clearMessage(messageId);
  }
}
