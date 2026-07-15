import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../../core/database/database_service.dart';
import '../../core/localization/locale_controller.dart';
import 'data/sqlite_locale_preference_store.dart';

/// 設定模組（Foundation Module，規格 §6）。
///
/// 後續負責低功耗開關、通知、儲存、翻譯等設定 UI。目前為骨架。
class SettingsModule extends AppModule {
  LocaleController? _localeController;

  @override
  String get name => 'settings';

  @override
  Future<void> init(ModuleContext context) async {
    final database = context.services.get<DatabaseService>().db;
    final controller = LocaleController(SqliteLocalePreferenceStore(database));
    await controller.load();
    context.services.registerSingleton<LocaleController>(controller);
    _localeController = controller;
    context.logger.debug('settings', '已載入語言偏好');
  }

  @override
  Future<void> activate() async {}

  @override
  Future<void> sleep() async {}

  @override
  void dispose() {
    _localeController?.dispose();
  }
}
