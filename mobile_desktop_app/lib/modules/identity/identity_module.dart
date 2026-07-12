import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../../core/database/database_service.dart';
import 'data/identity_repository.dart';
import 'domain/identity_session.dart';
import '../../shared/utils/id_generator.dart';
import '../../core/network/backend_api.dart';
import '../../core/network/http_backend_api.dart';

/// 身份模組（Foundation Module，規格 §6）。
///
/// 負責本機主身份資料；ID 產生與後端註冊由後續 S4-02、S4-03 完成。
class IdentityModule extends AppModule {
  @override
  String get name => 'identity';

  @override
  Future<void> init(ModuleContext context) async {
    final db = context.services.get<DatabaseService>().db;
    final repository = IdentityRepository(db);
    context.services.registerSingleton<IdentityRepository>(repository);
    final ids = context.services.get<IdGenerator>();
    final session = await repository.getOrCreateLocalIdentity(ids);
    context.services.registerSingleton<IdentitySession>(session);
    final backendUrl = context.config.getString('backendUrl', fallback: '');
    final devKey = context.config.getString('localDevKey', fallback: '');
    if (backendUrl.isNotEmpty && devKey.isNotEmpty) {
      final api = HttpBackendApi(baseUrl: backendUrl, localDevKey: devKey);
      context.services.registerSingleton<BackendApi>(api);
    }
    context.logger.debug('identity', '本機身份 repository 已初始化');
  }

  @override
  Future<void> activate() async {}

  @override
  Future<void> sleep() async {}

  @override
  void dispose() {}
}
