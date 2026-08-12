import '../../core/database/database_service.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import 'data/sqlite_low_power_preference_store.dart';
import 'domain/low_power_mode_service.dart';

class LowPowerModule extends AppModule {
  LowPowerModeService? _service;

  @override
  String get name => 'low_power';

  @override
  Future<void> init(ModuleContext context) async {
    final service = LowPowerModeService(
      store: SqliteLowPowerPreferenceStore(
        context.services.get<DatabaseService>().db,
      ),
      config: context.config,
      eventBus: context.eventBus,
    );
    await service.load();
    context.services.registerSingleton<LowPowerModeService>(service);
    _service = service;
    context.logger.debug(
      'low_power',
      '已載入低功耗偏好（enabled=${service.enabled}）',
    );
  }

  @override
  Future<void> activate() async {}

  @override
  Future<void> sleep() async {}

  @override
  void dispose() {
    _service?.dispose();
    _service = null;
  }
}
