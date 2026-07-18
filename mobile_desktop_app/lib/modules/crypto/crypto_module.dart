import 'dart:convert';

import 'package:sodium/sodium_sumo.dart';

import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../../core/database/database_service.dart';
import '../../core/network/backend_api.dart';
import '../identity/domain/identity_session.dart';
import 'data/flutter_secure_key_value_store.dart';
import 'data/remote_key_trust_repository.dart';
import 'data/secure_key_value_store.dart';
import 'data/sqlite_replay_protection.dart';
import 'domain/device_key_material.dart';
import 'domain/device_key_service.dart';
import 'domain/message_box.dart';
import 'domain/replay_protection.dart';

class CryptoModule extends AppModule {
  DeviceKeyMaterial? _deviceKey;

  @override
  String get name => 'crypto';

  @override
  Future<void> init(ModuleContext context) async {
    final sodium = await SodiumSumoInit.init();
    final store = FlutterSecureKeyValueStore();
    final service = DeviceKeyService(sodium: sodium, store: store);
    final identity = context.services.get<IdentitySession>();
    _deviceKey = await service.getOrCreate(identity.deviceId);

    context.services.registerSingleton<Sodium>(sodium);
    context.services.registerSingleton<SodiumSumo>(sodium);
    context.services.registerSingleton<SecureKeyValueStore>(store);
    context.services.registerSingleton<DeviceKeyService>(service);
    context.services.registerSingleton<DeviceKeyMaterial>(_deviceKey!);
    context.services.registerSingleton<MessageBox>(SodiumMessageBox(sodium));
    context.services.registerSingleton<ReplayProtection>(
      SqliteReplayProtection(context.services.get<DatabaseService>().db),
    );
    context.services.registerSingleton<RemoteKeyTrustRepository>(
      RemoteKeyTrustRepository(context.services.get<DatabaseService>().db),
    );
    if (context.services.isRegistered<BackendApi>()) {
      final api = context.services.get<BackendApi>();
      final publicKey =
          base64UrlEncode(_deviceKey!.publicKey).replaceAll('=', '');
      final access = await api.register(
        identity,
        'New User',
        publicKey: publicKey,
        publicKeyFingerprint: _deviceKey!.fingerprint,
      );
      await api.initializeDeviceKey(
        access.token,
        identity.deviceId,
        publicKey: publicKey,
        publicKeyFingerprint: _deviceKey!.fingerprint,
      );
      context.services.registerSingleton<AccessSession>(access);
    }
  }

  @override
  void dispose() {
    _deviceKey?.dispose();
    _deviceKey = null;
  }
}
