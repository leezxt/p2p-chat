import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/config/config_service.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/di/service_locator.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/core/module/module_context.dart';
import 'package:p2p_chat_app/core/resource_policy/resource_policy_service.dart';
import 'package:p2p_chat_app/core/routing/route_registry.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_material.dart';
import 'package:p2p_chat_app/modules/crypto/domain/message_box.dart';
import 'package:p2p_chat_app/modules/desktop_link/data/desktop_link_pairing_repository.dart';
import 'package:p2p_chat_app/modules/desktop_link/data/desktop_link_repository.dart';
import 'package:p2p_chat_app/modules/desktop_link/desktop_link_module.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_companion_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_key_possession.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_service.dart';
import 'package:p2p_chat_app/modules/identity/domain/identity_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_message_box.dart';

void main() {
  sqfliteFfiInit();

  test('module 以 IdentitySession 的主裝置身分註冊安全同步 service', () async {
    final directory = await Directory.systemTemp.createTemp('p2p_link_module_');
    final database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
    );
    try {
      await database.open(directoryPath: directory.path);
      final config = ConfigService();
      final primaryPublicKey = Uint8List.fromList(
        List<int>.generate(32, (index) => index + 1),
      );
      final primarySecret = TestSecureKey(
        Uint8List.fromList(List<int>.generate(32, (index) => index + 101)),
      );
      final box = TestMessageBox()
        ..registerKey(publicKey: primaryPublicKey, secretKey: primarySecret);
      final primaryKey = testDeviceKey(
        deviceId: 'primary-phone',
        publicKey: primaryPublicKey,
        secretKey: primarySecret,
      );
      final services = ServiceLocator()
        ..registerSingleton<DatabaseService>(database)
        ..registerSingleton<MessageBox>(box)
        ..registerSingleton<DeviceKeyMaterial>(primaryKey)
        ..registerSingleton<IdentitySession>(
          const IdentitySession(userId: 'user-1', deviceId: 'primary-phone'),
        );
      final context = ModuleContext(
        eventBus: EventBus(),
        config: config,
        logger: LoggingService(minLevel: LogLevel.error),
        resourcePolicy: ResourcePolicyService(config),
        services: services,
      );
      final module = DesktopLinkModule();
      final routes = RouteRegistry();

      await module.init(context);
      module.registerRoutes(routes);

      expect(services.isRegistered<DesktopLinkRepository>(), isTrue);
      expect(services.isRegistered<DesktopLinkService>(), isTrue);
      expect(services.isRegistered<DesktopLinkPairingRepository>(), isTrue);
      expect(services.isRegistered<DesktopLinkKeyPossessionService>(), isTrue);
      expect(services.isRegistered<DesktopLinkPairingService>(), isTrue);
      expect(services.isRegistered<DesktopLinkCompanionService>(), isTrue);
      expect(routes.contains(DesktopLinkModule.route), isTrue);
      expect(routes.contains(DesktopLinkModule.companionRoute), isTrue);
      await expectLater(
        services.get<DesktopLinkService>().authorize(
              deviceId: 'primary-phone',
              displayName: 'Primary phone',
              publicKeyFingerprint: 'primary-fingerprint',
            ),
        throwsA(isA<DesktopLinkPrimaryDeviceRejected>()),
      );
      module.dispose();
      primaryKey.dispose();
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
