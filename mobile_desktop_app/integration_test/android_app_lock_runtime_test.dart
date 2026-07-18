import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:p2p_chat_app/core/lifecycle/app_lifecycle_coordinator.dart';
import 'package:p2p_chat_app/modules/app_lock/data/local_auth_app_lock_biometric_authenticator.dart';
import 'package:p2p_chat_app/modules/app_lock/data/sodium_app_lock_pin_hasher.dart';
import 'package:p2p_chat_app/modules/app_lock/domain/app_lock_biometric_authenticator.dart';
import 'package:p2p_chat_app/modules/app_lock/domain/app_lock_service.dart';
import 'package:p2p_chat_app/modules/crypto/data/flutter_secure_key_value_store.dart';
import 'package:sodium/sodium_sumo.dart';

const _storageKey = 'app_lock_config_v1';
const _pin = '593814';
const _expectUnenrolledBiometrics = bool.fromEnvironment(
  'EXPECT_UNENROLLED_BIOMETRICS',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android App Lock persists Argon2id config and locks on background',
    (tester) async {
      final sodium = await SodiumSumoInit.init();
      final store = FlutterSecureKeyValueStore();
      final authenticator = LocalAuthAppLockBiometricAuthenticator();
      final service = AppLockService(
        store: store,
        pinHasher: SodiumAppLockPinHasher(sodium),
        biometricAuthenticator: authenticator,
      );
      AppLockService? reloaded;

      await store.delete(_storageKey);
      try {
        await service.enable(_pin);
        final persisted = await store.read(_storageKey);
        expect(persisted, isNotNull);
        expect(persisted, contains(r'$argon2id$'));
        expect(persisted, isNot(contains(_pin)));

        service.lock();
        expect(service.locked, isTrue);
        expect(
          await service.unlock('000000'),
          AppLockUnlockResult.invalidPin,
        );
        expect(service.locked, isTrue);
        expect(await service.unlock(_pin), AppLockUnlockResult.success);
        expect(service.locked, isFalse);

        reloaded = AppLockService(
          store: store,
          pinHasher: SodiumAppLockPinHasher(sodium),
          biometricAuthenticator: authenticator,
        );
        await reloaded.load();
        expect(reloaded.enabled, isTrue);
        expect(reloaded.locked, isTrue);
        expect(await reloaded.unlock(_pin), AppLockUnlockResult.success);

        final lifecycle = AppLifecycleCoordinator(
          onBackground: () async => reloaded!.lock(),
        );
        await lifecycle.handle(AppLifecycleState.inactive);
        expect(reloaded.locked, isFalse);
        await lifecycle.handle(AppLifecycleState.paused);
        expect(reloaded.locked, isTrue);
        await lifecycle.handle(AppLifecycleState.resumed);
        expect(reloaded.locked, isTrue);
        expect(await reloaded.unlock(_pin), AppLockUnlockResult.success);
      } finally {
        reloaded?.dispose();
        service.dispose();
        await store.delete(_storageKey);
      }
    },
  );

  testWidgets(
    'Android biometric adapter fails closed without enrollment',
    (tester) async {
      final authenticator = LocalAuthAppLockBiometricAuthenticator();

      expect(await authenticator.isAvailable(), isTrue);
      expect(
        await authenticator.authenticate(reason: 'Verify App Lock runtime'),
        AppLockBiometricResult.notEnrolled,
      );
    },
    skip: !_expectUnenrolledBiometrics,
  );
}
