import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/translation/data/sqlite_translation_repository.dart';
import 'package:p2p_chat_app/modules/translation/domain/translation_provider.dart';
import 'package:p2p_chat_app/modules/translation/domain/translation_result.dart';
import 'package:p2p_chat_app/modules/translation/domain/translation_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('沒有明確同意時不呼叫 provider', () async {
    final fixture = await _Fixture.open();
    try {
      final provider = _FakeProvider();
      final service = fixture.service(provider);

      await expectLater(
        service.translate(
          messageId: 'message-1',
          sourceText: 'hello',
          targetLanguage: 'zh-TW',
        ),
        throwsA(isA<TranslationConsentRequired>()),
      );
      expect(provider.calls, 0);
    } finally {
      await fixture.close();
    }
  });

  test('翻譯結果快取在本機，原文改變時必須重翻', () async {
    final fixture = await _Fixture.open();
    try {
      final provider = _FakeProvider();
      final service = fixture.service(provider);
      await service.setConsent(true);

      final first = await service.translate(
        messageId: 'message-2',
        sourceText: 'hello',
        targetLanguage: 'zh-TW',
      );
      final second = await service.translate(
        messageId: 'message-2',
        sourceText: 'hello',
        targetLanguage: 'zh-TW',
      );
      final changed = await service.translate(
        messageId: 'message-2',
        sourceText: 'hello again',
        targetLanguage: 'zh-TW',
      );

      expect(first.fromCache, isFalse);
      expect(second.fromCache, isTrue);
      expect(changed.fromCache, isFalse);
      expect(provider.calls, 2);
    } finally {
      await fixture.close();
    }
  });

  test('可清除單則訊息的翻譯快取', () async {
    final fixture = await _Fixture.open();
    try {
      final provider = _FakeProvider();
      final service = fixture.service(provider);
      await service.setConsent(true);
      await service.translate(
        messageId: 'message-3',
        sourceText: 'hello',
        targetLanguage: 'en',
      );
      await service.clearMessageCache('message-3');
      final next = await service.translate(
        messageId: 'message-3',
        sourceText: 'hello',
        targetLanguage: 'en',
      );

      expect(next.fromCache, isFalse);
      expect(provider.calls, 2);
    } finally {
      await fixture.close();
    }
  });
}

class _FakeProvider implements TranslationProvider {
  int calls = 0;

  @override
  String get id => 'fake-v1';

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
  }) async {
    calls++;
    return '$targetLanguage:$text';
  }
}

class _Fixture {
  _Fixture(this.directory, this.database);

  final Directory directory;
  final DatabaseService database;

  static Future<_Fixture> open() async {
    final directory = await Directory.systemTemp.createTemp('p2p_translation_');
    final database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
    );
    await database.open(directoryPath: directory.path);
    return _Fixture(directory, database);
  }

  TranslationService service(TranslationProvider provider) =>
      TranslationService(
        repository: SqliteTranslationRepository(database.db),
        provider: provider,
      );

  Future<void> close() async {
    await database.close();
    await directory.delete(recursive: true);
  }
}
