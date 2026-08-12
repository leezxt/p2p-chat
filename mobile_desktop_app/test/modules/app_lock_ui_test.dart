import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/modules/app_lock/domain/app_lock_biometric_authenticator.dart';
import 'package:p2p_chat_app/modules/app_lock/domain/app_lock_service.dart';
import 'package:p2p_chat_app/modules/app_lock/presentation/app_lock_gate.dart';
import 'package:p2p_chat_app/modules/app_lock/presentation/app_lock_settings_page.dart';
import 'package:p2p_chat_app/modules/crypto/data/secure_key_value_store.dart';

void main() {
  testWidgets('gate hides content until the correct PIN is entered',
      (tester) async {
    final service = _service();
    await service.enable('123456');
    service.lock();

    await tester.pumpWidget(_app(
      AppLockGate(
        service: service,
        child: const Center(child: Text('private content')),
      ),
    ));

    expect(find.text('private content'), findsNothing);
    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN'), findsOneWidget);
    expect(find.text('private content'), findsNothing);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('private content'), findsOneWidget);
  });

  testWidgets('settings enable and disable app lock with PIN confirmation',
      (tester) async {
    final service = _service();
    await tester.pumpWidget(_app(AppLockSettingsPage(service: service)));

    await tester.tap(find.byKey(const Key('app-lock-enabled-switch')));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Enable'));
    await tester.pumpAndSettle();
    expect(service.enabled, isTrue);
    expect(find.text('App lock is enabled'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-lock-enabled-switch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Disable app lock'));
    await tester.pumpAndSettle();
    expect(service.enabled, isFalse);
    expect(find.text('App lock is disabled'), findsOneWidget);
  });

  testWidgets('biometric cancellation keeps PIN fallback available',
      (tester) async {
    final authenticator = _FakeBiometricAuthenticator();
    final service = _service(biometricAuthenticator: authenticator);
    await service.enable('123456');
    await service.setBiometricsEnabled(true, reason: 'Enable biometrics');
    authenticator.nextResult = AppLockBiometricResult.cancelled;
    service.lock();

    await tester.pumpWidget(_app(
      AppLockGate(
        service: service,
        child: const Center(child: Text('private content')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('private content'), findsNothing);
    expect(find.byKey(const Key('app-lock-biometric-button')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('private content'), findsOneWidget);
  });

  testWidgets('settings enables biometrics only after authentication succeeds',
      (tester) async {
    final authenticator = _FakeBiometricAuthenticator();
    final service = _service(biometricAuthenticator: authenticator);
    await service.enable('123456');
    await tester.pumpWidget(_app(AppLockSettingsPage(service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('app-lock-biometric-switch')));
    await tester.pumpAndSettle();
    expect(service.biometricsEnabled, isTrue);

    await tester.tap(find.byKey(const Key('app-lock-biometric-switch')));
    await tester.pumpAndSettle();
    expect(service.biometricsEnabled, isFalse);
  });

  testWidgets('biometrics can be disabled after enrollment is removed',
      (tester) async {
    final authenticator = _FakeBiometricAuthenticator();
    final service = _service(biometricAuthenticator: authenticator);
    await service.enable('123456');
    await service.setBiometricsEnabled(true, reason: 'Enable biometrics');
    authenticator.available = false;

    await tester.pumpWidget(_app(AppLockSettingsPage(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-lock-biometric-switch')));
    await tester.pumpAndSettle();

    expect(service.biometricsEnabled, isFalse);
  });

  testWidgets('settings persists notification content privacy', (tester) async {
    final service = _service();
    await service.enable('123456');
    await tester.pumpWidget(_app(AppLockSettingsPage(service: service)));
    await tester.pumpAndSettle();

    final privacySwitch =
        find.byKey(const Key('app-lock-notification-privacy-switch'));
    expect(privacySwitch, findsOneWidget);
    expect(service.hideNotificationContent, isTrue);
    await tester.tap(privacySwitch);
    await tester.pumpAndSettle();
    expect(service.hideNotificationContent, isFalse);
  });
}

AppLockService _service({
  AppLockBiometricAuthenticator? biometricAuthenticator,
}) =>
    AppLockService(
      store: _MemorySecureStore(),
      pinHasher: const _FakePinHasher(),
      biometricAuthenticator:
          biometricAuthenticator ?? _FakeBiometricAuthenticator(),
    );

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

class _FakePinHasher implements AppLockPinHasher {
  const _FakePinHasher();

  @override
  Future<String> hash(String pin) async =>
      sha256.convert(utf8.encode(pin)).toString();

  @override
  Future<bool> verify(String encodedHash, String pin) async =>
      encodedHash == await hash(pin);
}

class _FakeBiometricAuthenticator implements AppLockBiometricAuthenticator {
  bool available = true;
  AppLockBiometricResult nextResult = AppLockBiometricResult.success;

  @override
  Future<AppLockBiometricResult> authenticate({required String reason}) async =>
      nextResult;

  @override
  Future<bool> isAvailable() async => available;
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
