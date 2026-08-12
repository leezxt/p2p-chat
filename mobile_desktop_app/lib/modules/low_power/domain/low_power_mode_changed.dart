import '../../../core/events/app_event.dart';

class LowPowerModeChanged extends AppEvent {
  const LowPowerModeChanged(this.enabled);

  final bool enabled;
}
