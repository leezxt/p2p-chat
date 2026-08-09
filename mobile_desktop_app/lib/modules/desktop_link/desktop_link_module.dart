import '../../core/database/database_service.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../identity/domain/identity_session.dart';
import 'data/desktop_link_repository.dart';
import 'domain/desktop_link_service.dart';

/// Desktop Link／Device Sync／Revoke 的主機安全核心。
///
/// 模組本身不維持連線，也不在背景工作；真正桌面 transport 會在未來按需啟動。
class DesktopLinkModule extends AppModule {
  @override
  String get name => 'desktop_link';

  @override
  Future<void> init(ModuleContext context) async {
    final repository = DesktopLinkRepository(
      context.services.get<DatabaseService>().db,
    );
    context.services.registerSingleton<DesktopLinkRepository>(repository);
    context.services.registerSingleton<DesktopLinkService>(
      DesktopLinkService(
        repository: repository,
        primaryDeviceId: context.services.get<IdentitySession>().deviceId,
        eventBus: context.eventBus,
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
