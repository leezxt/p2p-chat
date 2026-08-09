import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:p2p_chat_app/core/config/config_service.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/di/service_locator.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/core/module/module_context.dart';
import 'package:p2p_chat_app/core/module/module_lifecycle.dart';
import 'package:p2p_chat_app/core/module/module_registry.dart';
import 'package:p2p_chat_app/core/resource_policy/resource_policy_service.dart';
import 'package:p2p_chat_app/core/routing/route_registry.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_fingerprint.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_material.dart';
import 'package:p2p_chat_app/modules/crypto/domain/message_box.dart';
import 'package:p2p_chat_app/modules/desktop_link/desktop_link_module.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_companion_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/presentation/desktop_link_companion_page.dart';
import 'package:p2p_chat_app/modules/desktop_link/presentation/desktop_link_pairing_page.dart';
import 'package:p2p_chat_app/modules/identity/domain/identity_session.dart';
import 'package:sodium/sodium.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets(
    'Windows Desktop Link module routes Navigator to the Companion page',
    (tester) async {
      // 若原生測試意外改由非 Windows target 執行，平台選擇必須 fail-closed。
      expect(defaultTargetPlatform, TargetPlatform.windows);

      final directory =
          await Directory.systemTemp.createTemp('p2p_link_module_runtime_');
      final database = DatabaseService(
        databaseFactory: databaseFactoryFfi,
        logger: LoggingService(minLevel: LogLevel.error),
      );
      DeviceKeyMaterial? desktopKey;
      ModuleRegistry? registry;

      try {
        await database.open(directoryPath: directory.path);
        final sodium = await SodiumInit.init();
        final desktopPair = sodium.crypto.box.keyPair();
        late final DeviceKeyMaterial material;
        try {
          material = DeviceKeyMaterial(
            publicKey: desktopPair.publicKey,
            secretKey: desktopPair.secretKey.copy(),
            keyId: 'desktop-route-runtime-key',
            fingerprint: computeDeviceKeyFingerprint(
              'desktop-windows-route-runtime',
              desktopPair.publicKey,
            ),
          );
        } finally {
          desktopPair.dispose();
        }
        desktopKey = material;

        final config = ConfigService();
        final services = ServiceLocator()
          ..registerSingleton<DatabaseService>(database)
          ..registerSingleton<MessageBox>(SodiumMessageBox(sodium))
          ..registerSingleton<DeviceKeyMaterial>(material)
          ..registerSingleton<IdentitySession>(
            const IdentitySession(
              userId: 'runtime-user',
              deviceId: 'desktop-windows-route-runtime',
            ),
          );
        final context = ModuleContext(
          eventBus: EventBus(),
          config: config,
          logger: LoggingService(minLevel: LogLevel.error),
          resourcePolicy: ResourcePolicyService(config),
          services: services,
        );
        final routes = RouteRegistry();
        final moduleRegistry = ModuleRegistry(context, routes)
          ..register(DesktopLinkModule());
        registry = moduleRegistry;

        await moduleRegistry.initEnabledModules();

        expect(moduleRegistry.stateOf('desktop_link'), ModuleState.enabled);
        expect(
          services.isRegistered<DesktopLinkCompanionService>(),
          isTrue,
        );
        expect(routes.contains(DesktopLinkModule.route), isTrue);

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateRoute: routes.onGenerateRoute,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamed(DesktopLinkModule.route),
                    child: const Text('Open Desktop Link'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Desktop Link'));
        await tester.pumpAndSettle();

        expect(find.byType(DesktopLinkCompanionPage), findsOneWidget);
        expect(find.byType(DesktopLinkPairingPage), findsNothing);
      } finally {
        registry?.disposeAll();
        desktopKey?.dispose();
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
