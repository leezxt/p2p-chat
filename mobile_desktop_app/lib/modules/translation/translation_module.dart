import '../../core/database/database_service.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import 'data/sqlite_translation_repository.dart';
import 'domain/translation_service.dart';

/// 翻譯 provider 預設未設定；這個 module 不會自行傳送任何聊天內容。
class TranslationModule extends AppModule {
  @override
  String get name => 'translation';

  @override
  Future<void> init(ModuleContext context) async {
    context.services.registerSingleton<TranslationService>(
      TranslationService(
        repository: SqliteTranslationRepository(
          context.services.get<DatabaseService>().db,
        ),
      ),
    );
  }

  @override
  Future<void> activate() async {}

  @override
  Future<void> sleep() async {}

  @override
  void dispose() {}
}
