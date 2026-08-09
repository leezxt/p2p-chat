import '../../core/database/database_service.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../../core/routing/route_registry.dart';
import '../crypto/domain/device_key_material.dart';
import '../crypto/domain/message_box.dart';
import '../identity/domain/identity_session.dart';
import 'data/desktop_link_pairing_repository.dart';
import 'data/desktop_link_repository.dart';
import 'domain/desktop_link_key_possession.dart';
import 'domain/desktop_link_pairing_service.dart';
import 'domain/desktop_link_service.dart';
import 'presentation/desktop_link_pairing_page.dart';

/// Desktop Link／Device Sync／Revoke 的主機安全核心。
///
/// 模組本身不維持連線，也不在背景工作；真正桌面 transport 會在未來按需啟動。
class DesktopLinkModule extends AppModule {
  static const route = '/desktop-link';

  late final DesktopLinkService _desktopLinkService;
  late final DesktopLinkKeyPossessionService _keyPossessionService;
  late final DesktopLinkPairingService _pairingService;

  @override
  String get name => 'desktop_link';

  @override
  Future<void> init(ModuleContext context) async {
    final primaryDeviceId = context.services.get<IdentitySession>().deviceId;
    final repository = DesktopLinkRepository(
      context.services.get<DatabaseService>().db,
    );
    context.services.registerSingleton<DesktopLinkRepository>(repository);
    _desktopLinkService = DesktopLinkService(
      repository: repository,
      primaryDeviceId: primaryDeviceId,
      eventBus: context.eventBus,
    );
    context.services.registerSingleton<DesktopLinkService>(_desktopLinkService);

    final pairingRepository = DesktopLinkPairingRepository(
      context.services.get<DatabaseService>().db,
    );
    context.services.registerSingleton<DesktopLinkPairingRepository>(
      pairingRepository,
    );
    _keyPossessionService = DesktopLinkKeyPossessionService(
      box: context.services.get<MessageBox>(),
      primaryKey: context.services.get<DeviceKeyMaterial>(),
      primaryDeviceId: primaryDeviceId,
    );
    context.services.registerSingleton<DesktopLinkKeyPossessionService>(
      _keyPossessionService,
    );
    _pairingService = DesktopLinkPairingService(
      repository: pairingRepository,
      desktopLinkService: _desktopLinkService,
      keyPossessionService: _keyPossessionService,
      primaryDeviceId: primaryDeviceId,
    );
    context.services.registerSingleton<DesktopLinkPairingService>(
      _pairingService,
    );
  }

  @override
  void registerRoutes(RouteRegistry routes) {
    routes.add(
      route,
      (context, args) => DesktopLinkPairingPage(
        pairingService: _pairingService,
        desktopLinkService: _desktopLinkService,
      ),
    );
  }

  @override
  Future<void> activate() async {}

  @override
  Future<void> sleep() async {}

  @override
  void dispose() => _keyPossessionService.dispose();
}
