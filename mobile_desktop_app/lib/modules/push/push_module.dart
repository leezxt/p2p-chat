import '../../core/events/event_bus.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../../core/network/backend_api.dart';
import '../app_lock/events/app_lock_state_changed.dart';
import '../identity/domain/identity_session.dart';
import 'data/http_push_token_client.dart';
import 'domain/notification_presentation_policy.dart';
import 'domain/push_registration_service.dart';
import 'domain/push_token_client.dart';

class PushModule extends AppModule {
  NotificationPresentationPolicy? _presentationPolicy;
  EventSubscription? _appLockSubscription;

  @override
  String get name => 'push';

  @override
  Future<void> init(ModuleContext context) async {
    final presentationPolicy = NotificationPresentationPolicy();
    context.services.registerSingleton<NotificationPresentationPolicy>(
      presentationPolicy,
    );
    _presentationPolicy = presentationPolicy;

    if (!context.services.isRegistered<AccessSession>()) return;
    final baseUrl = context.config.getString('backendUrl', fallback: '');
    if (baseUrl.isEmpty) return;
    final client = HttpPushTokenClient(
      baseUrl: baseUrl,
      accessToken: context.services.get<AccessSession>().token,
    );
    final service = PushRegistrationService(
      client: client,
      deviceId: context.services.get<IdentitySession>().deviceId,
    );
    context.services.registerSingleton<PushTokenClient>(client);
    context.services.registerSingleton<PushRegistrationService>(service);
  }

  @override
  void registerEvents(EventBus eventBus) {
    _appLockSubscription = eventBus.on<AppLockStateChanged>((event) {
      _presentationPolicy?.updateAppLockState(
        enabled: event.enabled,
        locked: event.locked,
        hideNotificationContent: event.hideNotificationContent,
      );
    });
  }

  @override
  void dispose() {
    _appLockSubscription?.cancel();
    _appLockSubscription = null;
    _presentationPolicy = null;
  }
}
