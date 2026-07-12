import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';

/// 設定模組（Foundation Module，規格 §6）。
///
/// 後續負責低功耗開關、通知、儲存、翻譯等設定 UI。目前為骨架。
class SettingsModule extends AppModule {
  @override
  String get name => 'settings';

  @override
  Future<void> init(ModuleContext context) async {
    context.logger.debug('settings', 'init（骨架）');
  }

  @override
  Future<void> activate() async {}

  @override
  Future<void> sleep() async {}

  @override
  void dispose() {}
}
