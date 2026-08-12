import 'package:flutter/foundation.dart';

import '../../../core/config/config_service.dart';
import '../../../core/events/event_bus.dart';
import 'low_power_mode_changed.dart';
import 'low_power_preference_store.dart';

class LowPowerModeService extends ChangeNotifier {
  LowPowerModeService({
    required LowPowerPreferenceStore store,
    required ConfigService config,
    required EventBus eventBus,
  })  : _store = store,
        _config = config,
        _eventBus = eventBus;

  final LowPowerPreferenceStore _store;
  final ConfigService _config;
  final EventBus _eventBus;

  bool get enabled => _config.lowPowerMode;

  Future<void> load() async {
    _config.lowPowerMode = await _store.read() ?? _config.lowPowerMode;
    _eventBus.emit(LowPowerModeChanged(enabled));
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (enabled == value) return;
    await _store.write(value);
    _config.lowPowerMode = value;
    _eventBus.emit(LowPowerModeChanged(value));
    notifyListeners();
  }
}
