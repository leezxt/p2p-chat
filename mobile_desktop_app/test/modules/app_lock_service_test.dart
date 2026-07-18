import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/app_lock/domain/app_lock_biometric_authenticator.dart';
import 'package:p2p_chat_app/modules/app_lock/domain/app_lock_service.dart';
import 'package:p2p_chat_app/modules/crypto/data/secure_key_value_store.dart';

void main() {
  test('stores an encoded verifier without storing the PIN', () async {
    final store = _MemorySecureStore();
    final service = _service(store);

    await service.enable('123456');

    final encoded = store.values.values.single;
    final config = jsonDecode(encoded) as Map<String, dynamic>;
    expect(encoded, isNot(contains('123456')));
    expect(
      config['encodedHash'],
      sha256.convert(utf8.encode('123456')).toString(),
    );
    expect(service.enabled, isTrue);
    expect(service.locked, isFalse);
    expect(service.hideNotificationContent, isTrue);
  });

  test('persists the verifier and starts locked after restart', () async {
    final store = _MemorySecureStore();
    final first = _service(store);
    await first.enable('123456');
    first.lock();

    expect(await first.unlock('654321'), AppLockUnlockResult.invalidPin);
    expect(first.locked, isTrue);
    expect(await first.unlock('123456'), AppLockUnlockResult.success);

    final restarted = _service(store);
    await restarted.load();
    expect(restarted.enabled, isTrue);
    expect(restarted.locked, isTrue);
    expect(await restarted.unlock('123456'), AppLockUnlockResult.success);
  });

  test('locks out after five failures and persists the cooldown', () async {
    final store = _MemorySecureStore();
    var now = DateTime.utc(2026, 7, 18);
    final service = _service(store, now: () => now);
    await service.enable('123456');
    service.lock();

    for (var attempt = 0; attempt < 4; attempt++) {
      expect(await service.unlock('000000'), AppLockUnlockResult.invalidPin);
    }
    expect(await service.unlock('000000'), AppLockUnlockResult.lockedOut);
    expect(await service.unlock('123456'), AppLockUnlockResult.lockedOut);

    final restarted = _service(store, now: () => now);
    await restarted.load();
    expect(await restarted.unlock('123456'), AppLockUnlockResult.lockedOut);

    now = now.add(const Duration(seconds: 31));
    expect(await restarted.unlock('123456'), AppLockUnlockResult.success);
  });

  test('requires the current PIN to disable and fails closed on corrupt data',
      () async {
    final store = _MemorySecureStore();
    final service = _service(store);
    await service.enable('123456');

    expect(await service.disable('000000'), AppLockUnlockResult.invalidPin);
    expect(service.enabled, isTrue);
    expect(await service.disable('123456'), AppLockUnlockResult.success);
    expect(service.enabled, isFalse);
    expect(store.values, isEmpty);

    store.values['app_lock_config_v1'] = '{invalid';
    final corrupt = _service(store);
    await corrupt.load();
    expect(corrupt.enabled, isTrue);
    expect(corrupt.locked, isTrue);
    expect(corrupt.configurationError, isTrue);
    expect(
      await corrupt.unlock('123456'),
      AppLockUnlockResult.configurationError,
    );
  });

  test('persists biometric opt-in and unlocks only after trusted local auth',
      () async {
    final store = _MemorySecureStore();
    final authenticator = _FakeBiometricAuthenticator();
    final service = _service(store, biometricAuthenticator: authenticator);
    await service.enable('123456');

    authenticator.nextResult = AppLockBiometricResult.cancelled;
    expect(
      await service.setBiometricsEnabled(true, reason: 'Enable biometrics'),
      AppLockBiometricResult.cancelled,
    );
    expect(service.biometricsEnabled, isFalse);

    authenticator.nextResult = AppLockBiometricResult.success;
    expect(
      await service.setBiometricsEnabled(true, reason: 'Enable biometrics'),
      AppLockBiometricResult.success,
    );
    expect(service.biometricsEnabled, isTrue);

    final restarted = _service(
      store,
      biometricAuthenticator: authenticator,
    );
    await restarted.load();
    expect(restarted.biometricsEnabled, isTrue);
    authenticator.nextResult = AppLockBiometricResult.failed;
    expect(
      await restarted.unlockWithBiometrics(reason: 'Unlock'),
      AppLockBiometricResult.failed,
    );
    expect(restarted.locked, isTrue);

    authenticator.nextResult = AppLockBiometricResult.success;
    expect(
      await restarted.unlockWithBiometrics(reason: 'Unlock'),
      AppLockBiometricResult.success,
    );
    expect(restarted.locked, isFalse);
  });

  test('notification content privacy defaults on and persists opt-out',
      () async {
    final store = _MemorySecureStore();
    final service = _service(store);
    await service.enable('123456');
    expect(service.hideNotificationContent, isTrue);

    await service.setHideNotificationContent(false);
    expect(service.hideNotificationContent, isFalse);

    final restarted = _service(store);
    await restarted.load();
    expect(restarted.hideNotificationContent, isFalse);
  });
}

AppLockService _service(
  SecureKeyValueStore store, {
  DateTime Function()? now,
  AppLockBiometricAuthenticator? biometricAuthenticator,
}) =>
    AppLockService(
      store: store,
      pinHasher: const _FakePinHasher(),
      biometricAuthenticator:
          biometricAuthenticator ?? _FakeBiometricAuthenticator(),
      now: now,
    );

class _FakeBiometricAuthenticator implements AppLockBiometricAuthenticator {
  bool available = true;
  AppLockBiometricResult nextResult = AppLockBiometricResult.success;

  @override
  Future<AppLockBiometricResult> authenticate({required String reason}) async =>
      nextResult;

  @override
  Future<bool> isAvailable() async => available;
}

class _FakePinHasher implements AppLockPinHasher {
  const _FakePinHasher();

  @override
  Future<String> hash(String pin) async =>
      sha256.convert(utf8.encode(pin)).toString();

  @override
  Future<bool> verify(String encodedHash, String pin) async =>
      encodedHash == await hash(pin);
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
