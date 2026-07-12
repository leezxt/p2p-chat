import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../../core/network/backend_api.dart';
import '../identity/domain/identity_session.dart';
import 'data/http_push_token_client.dart';
import 'domain/push_registration_service.dart';
import 'domain/push_token_client.dart';

class PushModule extends AppModule {
  @override
  String get name => 'push';

  @override
  Future<void> init(ModuleContext context) async {
    if (!context.services.isRegistered<AccessSession>()) return;
    final baseUrl = context.config.getString('backendUrl', fallback: '');
    if (baseUrl.isEmpty) return;
    final client = HttpPushTokenClient(
      baseUrl: baseUrl,
      accessToken: context.services.get<AccessSession>().token,
    );
    final service = PushRegistrationService(
      client: client,
      deviceId: context.services.get<IdentitySession>().deviceId,
    );
    context.services.registerSingleton<PushTokenClient>(client);
    context.services.registerSingleton<PushRegistrationService>(service);
  }
}
