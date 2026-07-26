import 'package:sqflite/sqflite.dart';

import '../../core/database/database_service.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/events/event_bus.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../../core/routing/route_registry.dart';
import '../../shared/utils/id_generator.dart';
import 'data/chat_repository.dart';
import 'data/chat_sqflite_dao.dart';
import 'events/chat_events.dart';
import 'presentation/conversation_list_page.dart';
import '../identity/domain/identity_session.dart';
import '../contacts/data/contact_repository.dart';
import '../contacts/domain/contact_service.dart';
import '../mailbox/domain/message_transport_coordinator.dart';
import '../mailbox/domain/mailbox_sync_service.dart';
import '../mailbox/domain/mailbox_refresh_service.dart';
import '../../core/di/service_locator.dart';
import '../presence/domain/presence_service.dart';
import '../safety_number/domain/safety_number_service.dart';
import '../app_lock/domain/app_lock_service.dart';
import '../low_power/domain/low_power_mode_service.dart';
import '../reaction/data/reaction_repository.dart';

/// 聊天模組（規格 §6 Foundation Module）。
///
/// 平常狀態 enabled，隨 App 啟動 init（規格 §10）。負責建立聊天資料存取、
/// 註冊聊天路由，並監聽收到的訊息事件寫入本機。
class ChatModule implements AppModule {
  ChatModule({
    this.currentUserId,
    this.currentDeviceId,
  });

  String? currentUserId;
  String? currentDeviceId;

  static const route = '/chat';

  late final ChatRepository _repository;
  late final IdGenerator _ids;
  EventSubscription? _incomingSub;
  late ServiceLocator _services;

  @override
  String get name => 'chat';

  @override
  Future<void> init(ModuleContext context) async {
    final Database db = context.services.get<DatabaseService>().db;
    _services = context.services;
    final identity = context.services.get<IdentitySession>();
    currentUserId ??= identity.userId;
    currentDeviceId ??= identity.deviceId;
    _ids = context.services.isRegistered<IdGenerator>()
        ? context.services.get<IdGenerator>()
        : IdGenerator();
    _repository = ChatRepository(ChatSqfliteDao(db), context.eventBus);
    context.services.registerSingleton<ChatRepository>(_repository);
  }

  @override
  void registerEvents(EventBus eventBus) {
    // 收到對方訊息（Sprint 5+ 由 P2P / Mailbox 發出）→ 寫入本機。
    _incomingSub = eventBus.on<MessageReceived>((event) {
      _repository.saveIncomingMessage(event.message);
    });
  }

  @override
  void registerRoutes(RouteRegistry routes) {
    routes.add(
        route,
        (context, args) => ConversationListPage(
              repository: _repository,
              ids: _ids,
              currentUserId: currentUserId!,
              currentDeviceId: currentDeviceId!,
              transport: _services.isRegistered<MessageTransportCoordinator>()
                  ? _services.get<MessageTransportCoordinator>()
                  : null,
              resolveTargetDevice: (userId) async {
                if (!_services.isRegistered<ContactRepository>()) return null;
                return (await _services
                        .get<ContactRepository>()
                        .findByUserId(userId))
                    ?.deviceId;
              },
              markRead: _services.isRegistered<MailboxSyncService>()
                  ? _services.get<MailboxSyncService>().markRead
                  : null,
              syncMailbox: _services.isRegistered<MailboxSyncService>()
                  ? _services.get<MailboxRefreshService>().refresh
                  : null,
              contactService: _services.isRegistered<ContactService>()
                  ? _services.get<ContactService>()
                  : null,
              presenceService: _services.isRegistered<PresenceService>()
                  ? _services.get<PresenceService>()
                  : null,
              safetyNumberService: _services.isRegistered<SafetyNumberService>()
                  ? _services.get<SafetyNumberService>()
                  : null,
              appLockService: _services.isRegistered<AppLockService>()
                  ? _services.get<AppLockService>()
                  : null,
              lowPowerModeService: _services.isRegistered<LowPowerModeService>()
                  ? _services.get<LowPowerModeService>()
                  : null,
              localeController: _services.get<LocaleController>(),
              reactionRepository: _services.isRegistered<ReactionRepository>()
                  ? _services.get<ReactionRepository>()
                  : null,
            ));
  }

  @override
  Future<void> activate() async {}

  @override
  Future<void> sleep() async {}

  @override
  void dispose() {
    _incomingSub?.cancel();
  }
}
