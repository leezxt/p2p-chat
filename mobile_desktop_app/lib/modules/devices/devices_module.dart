import '../../core/database/database_service.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import 'data/device_repository.dart';

class DevicesModule extends AppModule {
  @override
  String get name => 'devices';
  @override
  Future<void> init(ModuleContext context) async {
    final db = context.services.get<DatabaseService>().db;
    context.services.registerSingleton<DeviceRepository>(DeviceRepository(db));
  }

  @override
  Future<void> activate() async {}
  @override
  Future<void> sleep() async {}
  @override
  void dispose() {}
}
