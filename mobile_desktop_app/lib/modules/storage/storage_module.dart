import '../../core/database/database_service.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import 'data/sqlite_storage_repository.dart';
import 'domain/storage_manager_service.dart';

/// Storage Manager 只讀取本機統計，沒有網路或背景常駐工作。
class StorageModule extends AppModule {
  @override
  String get name => 'storage';

  @override
  Future<void> init(ModuleContext context) async {
    final repository = SqliteStorageRepository(
      context.services.get<DatabaseService>().db,
    );
    context.services.registerSingleton<StorageManagerService>(
      StorageManagerService(repository),
    );
  }

  @override
  Future<void> activate() async {}

  @override
  Future<void> sleep() async {}

  @override
  void dispose() {}
}
