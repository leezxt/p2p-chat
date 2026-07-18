import '../../../core/events/app_event.dart';

class AppLockStateChanged extends AppEvent {
  const AppLockStateChanged({
    required this.enabled,
    required this.locked,
    required this.hideNotificationContent,
  });

  final bool enabled;
  final bool locked;
  final bool hideNotificationContent;
}
