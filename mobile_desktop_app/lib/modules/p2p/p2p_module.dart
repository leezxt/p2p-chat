import 'dart:async';

import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../../core/network/backend_api.dart';
import '../../shared/utils/id_generator.dart';
import '../contacts/data/contact_repository.dart';
import '../crypto/data/stored_remote_device_key_resolver.dart';
import '../crypto/data/remote_key_trust_repository.dart';
import '../crypto/domain/device_key_material.dart';
import '../crypto/domain/encrypted_message_service.dart';
import '../crypto/domain/message_box.dart';
import '../crypto/domain/replay_protection.dart';
import '../devices/data/device_repository.dart';
import '../identity/domain/identity_session.dart';
import '../signaling/data/websocket_signaling_client.dart';
import 'data/flutter_webrtc_peer_adapter.dart';
import 'domain/p2p_session_manager.dart';

class P2pModule extends AppModule {
  P2pSessionManager? _manager;
  String? _url;
  String? _token;
  String? _deviceId;
  @override
  String get name => 'p2p';

  @override
  Future<void> init(ModuleContext context) async {
    if (!context.services.isRegistered<AccessSession>()) {
      context.logger.debug('p2p', '尚無 backend access session，保持 sleeping');
      return;
    }
    final identity = context.services.get<IdentitySession>();
    final signaling = WebSocketSignalingClient();
    final cipher = EncryptedMessageService(
      box: context.services.get<MessageBox>(),
      localKey: context.services.get<DeviceKeyMaterial>(),
      localDeviceId: identity.deviceId,
      remoteKeys: StoredRemoteDeviceKeyResolver(
        context.services.get<DeviceRepository>(),
        context.services.get<ContactRepository>(),
        context.services.get<RemoteKeyTrustRepository>(),
      ),
      replayProtection: context.services.get<ReplayProtection>(),
    );
    _manager = P2pSessionManager(
        signaling: signaling,
        peerFactory: (_, initiator) =>
            FlutterWebRtcPeerAdapter.create(initiator),
        eventBus: context.eventBus,
        ids: context.services.get<IdGenerator>(),
        localDeviceId: identity.deviceId,
        messageCipher: cipher,
        onMessageRejected: (error) =>
            context.logger.info('p2p', '拒絕無效 encrypted envelope'))
      ..start();
    context.services.registerSingleton<MessageCipher>(cipher);
    context.services.registerSingleton<P2pSessionManager>(_manager!);
    _url = context.config.getString('signalingUrl', fallback: '');
    _token = context.services.get<AccessSession>().token;
    _deviceId = identity.deviceId;
  }

  @override
  Future<void> activate() async {
    if (_manager != null && _url!.isNotEmpty) {
      await _manager!.signaling
          .connect(url: _url!, token: _token!, deviceId: _deviceId!);
    }
  }

  @override
  Future<void> sleep() async {
    await _manager?.sleep();
  }

  @override
  void dispose() {
    unawaited(_manager?.dispose());
    _manager = null;
  }
}
