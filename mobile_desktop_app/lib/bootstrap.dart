import 'package:sqflite/sqflite.dart';

import 'core/config/config_service.dart';
import 'core/database/database_service.dart';
import 'core/di/service_locator.dart';
import 'core/events/event_bus.dart';
import 'core/logging/logging_service.dart';
import 'core/module/module_context.dart';
import 'core/module/module_registry.dart';
import 'core/module/module_lifecycle.dart';
import 'core/resource_policy/resource_policy_service.dart';
import 'core/routing/route_registry.dart';
import 'modules/chat/chat_module.dart';
import 'modules/app_lock/app_lock_module.dart';
import 'modules/crypto/crypto_module.dart';
import 'modules/identity/identity_module.dart';
import 'modules/contacts/contacts_module.dart';
import 'modules/devices/devices_module.dart';
import 'modules/p2p/p2p_module.dart';
import 'modules/mailbox/mailbox_module.dart';
import 'modules/low_power/low_power_module.dart';
import 'modules/presence/presence_module.dart';
import 'modules/push/push_module.dart';
import 'modules/settings/settings_module.dart';
import 'modules/safety_number/safety_number_module.dart';
import 'modules/reaction/reaction_module.dart';
import 'modules/sticker/sticker_module.dart';
import 'modules/storage/storage_module.dart';
import 'modules/smart_notification/smart_notification_module.dart';
import 'modules/translation/translation_module.dart';
import 'modules/attachment/attachment_module.dart';
import 'shared/utils/id_generator.dart';

/// 啟動結果：交給 App 根 Widget 使用。
class Bootstrap {
  Bootstrap(this.registry, this.routes, this.services);
  final ModuleRegistry registry;
  final RouteRegistry routes;
  final ServiceLocator services;
}

/// 組裝 Core 服務、註冊模組並 init（規格 §9）。
///
/// 只 init 基礎模組；高耗能模組（P2P / 通話 / 檔案 / AI）之後以 disabled 註冊，
/// 不在此啟動。[databaseFactory] 由平台入口注入（手機 sqflite / 桌面 ffi），
/// 以便同一段組裝邏輯在不同平台與測試共用。
Future<Bootstrap> bootstrap({
  required DatabaseFactory databaseFactory,
  String? databaseDirectory,
  String? currentUserId,
  String? currentDeviceId,
  Map<String, Object?>? configValues,
}) async {
  final logger = LoggingService();
  final config = ConfigService(initial: configValues);
  final eventBus = EventBus(
    onHandlerError: (e, st) => logger.error('eventbus', 'handler 錯誤: $e', st),
  );
  final resourcePolicy = ResourcePolicyService(config);
  final services = ServiceLocator();

  // 開啟資料庫並註冊到 DI 供各模組取用。
  final database =
      DatabaseService(databaseFactory: databaseFactory, logger: logger);
  await database.open(directoryPath: databaseDirectory);
  services.registerSingleton<DatabaseService>(database);
  services.registerSingleton<IdGenerator>(IdGenerator());

  final routes = RouteRegistry();
  final context = ModuleContext(
    eventBus: eventBus,
    config: config,
    logger: logger,
    resourcePolicy: resourcePolicy,
    services: services,
  );

  final registry = ModuleRegistry(context, routes);
  // 基礎模組（規格 §9 範例的精簡子集，其餘 Sprint 陸續加入）。
  registry.register(IdentityModule());
  // Push 先訂閱 App Lock 狀態，確保初始通知政策不遺漏鎖定狀態。
  registry.register(PushModule());
  registry.register(CryptoModule());
  registry.register(AppLockModule());
  registry.register(ContactsModule());
  registry.register(SafetyNumberModule());
  registry.register(DevicesModule());
  // 先載入持久化低功耗偏好，再初始化會讀取資源策略的模組。
  registry.register(LowPowerModule());
  registry.register(P2pModule());
  registry.register(SettingsModule());
  registry.register(PresenceModule());
  // Experience repositories must be available before Chat captures route
  // dependencies during registerRoutes.
  registry.register(ReactionModule());
  registry.register(StickerModule());
  registry.register(StorageModule());
  registry.register(SmartNotificationModule());
  registry.register(TranslationModule());
  registry.register(AttachmentModule(), initial: ModuleState.disabled);
  registry.register(ChatModule(
    currentUserId: currentUserId,
    currentDeviceId: currentDeviceId,
  ));
  registry.register(MailboxModule());

  await registry.initEnabledModules();
  logger.info('bootstrap', '啟動完成，路由：${routes.routeNames.join(', ')}');
  return Bootstrap(registry, routes, services);
}
