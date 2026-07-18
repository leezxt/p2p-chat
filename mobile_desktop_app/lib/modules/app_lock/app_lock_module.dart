import 'package:flutter/foundation.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../crypto/data/secure_key_value_store.dart';
import 'data/local_auth_app_lock_biometric_authenticator.dart';
import 'data/sodium_app_lock_pin_hasher.dart';
import 'domain/app_lock_biometric_authenticator.dart';
import 'domain/app_lock_service.dart';
import 'events/app_lock_state_changed.dart';

class AppLockModule extends AppModule {
  AppLockService? _service;
  VoidCallback? _stateListener;

  @override
  String get name => 'app_lock';

  @override
  Future<void> init(ModuleContext context) async {
    final biometricAuthenticator = LocalAuthAppLockBiometricAuthenticator();
    context.services.registerSingleton<AppLockBiometricAuthenticator>(
      biometricAuthenticator,
    );
    final service = AppLockService(
      store: context.services.get<SecureKeyValueStore>(),
      pinHasher: SodiumAppLockPinHasher(
        context.services.get<SodiumSumo>(),
      ),
      biometricAuthenticator: biometricAuthenticator,
    );
    void emitState() {
      context.eventBus.emit(AppLockStateChanged(
        enabled: service.enabled,
        locked: service.locked,
        hideNotificationContent: service.hideNotificationContent,
      ));
    }

    await service.load();
    _service = service;
    service.addListener(emitState);
    _stateListener = emitState;
    emitState();
    context.services.registerSingleton<AppLockService>(service);
  }

  @override
  void dispose() {
    final listener = _stateListener;
    if (listener != null) _service?.removeListener(listener);
    _service?.dispose();
    _stateListener = null;
    _service = null;
  }
}
