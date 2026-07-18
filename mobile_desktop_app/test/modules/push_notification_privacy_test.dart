import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/config/config_service.dart';
import 'package:p2p_chat_app/core/di/service_locator.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/core/module/module_context.dart';
import 'package:p2p_chat_app/core/resource_policy/resource_policy_service.dart';
import 'package:p2p_chat_app/modules/app_lock/events/app_lock_state_changed.dart';
import 'package:p2p_chat_app/modules/push/domain/notification_presentation_policy.dart';
import 'package:p2p_chat_app/modules/push/push_module.dart';

void main() {
  test('redacts local details until app lock state is known', () {
    final policy = NotificationPresentationPolicy();

    final presentation = policy.resolve(
      genericTitle: 'New message',
      genericBody: 'Open the app to view it',
      localSenderName: 'Alice',
      localMessagePreview: 'Secret text',
    );

    expect(presentation.redacted, isTrue);
    expect(presentation.title, 'New message');
    expect(presentation.body, 'Open the app to view it');
  });

  test('reveals only local details after an explicit unlocked policy', () {
    final policy = NotificationPresentationPolicy()
      ..updateAppLockState(
        enabled: true,
        locked: false,
        hideNotificationContent: false,
      );

    final presentation = policy.resolve(
      genericTitle: 'New message',
      genericBody: 'Open the app to view it',
      localSenderName: ' Alice ',
      localMessagePreview: ' Secret text ',
    );

    expect(presentation.redacted, isFalse);
    expect(presentation.title, 'Alice');
    expect(presentation.body, 'Secret text');
  });

  test('locked app always redacts even when the preference is disabled', () {
    final policy = NotificationPresentationPolicy()
      ..updateAppLockState(
        enabled: true,
        locked: true,
        hideNotificationContent: false,
      );

    final presentation = policy.resolve(
      genericTitle: 'New message',
      genericBody: 'Open the app to view it',
      localSenderName: 'Alice',
      localMessagePreview: 'Secret text',
    );

    expect(presentation.redacted, isTrue);
  });

  test('push module wires and disposes app lock state events without backend',
      () async {
    final eventBus = EventBus();
    final config = ConfigService();
    final services = ServiceLocator();
    final context = ModuleContext(
      eventBus: eventBus,
      config: config,
      logger: LoggingService(minLevel: LogLevel.error),
      resourcePolicy: ResourcePolicyService(config),
      services: services,
    );
    final module = PushModule();
    await module.init(context);
    module.registerEvents(eventBus);

    expect(services.isRegistered<NotificationPresentationPolicy>(), isTrue);
    expect(eventBus.listenerCount(AppLockStateChanged), 1);
    eventBus.emit(const AppLockStateChanged(
      enabled: false,
      locked: false,
      hideNotificationContent: true,
    ));
    final presentation = services.get<NotificationPresentationPolicy>().resolve(
          genericTitle: 'New message',
          genericBody: 'Open the app to view it',
          localSenderName: 'Alice',
          localMessagePreview: 'Local preview',
        );
    expect(presentation.redacted, isFalse);

    module.dispose();
    expect(eventBus.listenerCount(AppLockStateChanged), 0);
  });
}
