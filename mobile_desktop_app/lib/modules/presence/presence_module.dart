import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../../core/network/backend_api.dart';
import '../identity/domain/identity_session.dart';
import 'data/http_presence_client.dart';
import 'domain/presence_service.dart';

/// 上線狀態模組（Foundation Module，規格 §6、§16）。
///
/// Sprint 8 實作：前景 60 秒更新 lastSeen、背景不更新 heartbeat、
/// 顯示「在線 / 剛剛在線 / 5 分鐘前在線 / 離線」。不做秒級即時在線狀態。
/// 目前為骨架，預設 low-power。
class PresenceModule extends AppModule {
  PresenceService? _service;
  @override
  String get name => 'presence';

  @override
  Future<void> init(ModuleContext context) async {
    if (!context.services.isRegistered<AccessSession>()) return;
    final baseUrl = context.config.getString('backendUrl', fallback: '');
    if (baseUrl.isEmpty) return;
    final interval = context.resourcePolicy.presenceHeartbeatSeconds;
    final identity = context.services.get<IdentitySession>();
    _service = PresenceService(
      client: HttpPresenceClient(
        baseUrl: baseUrl,
        accessToken: context.services.get<AccessSession>().token,
      ),
      localDeviceId: identity.deviceId,
      interval: Duration(seconds: interval),
    );
    context.services.registerSingleton<PresenceService>(_service!);
    context.logger.debug('presence', 'init（heartbeat=${interval}s）');
  }

  @override
  Future<void> activate() async => _service?.start();

  @override
  Future<void> sleep() async => _service?.stop();

  @override
  void dispose() => _service?.dispose();
}
