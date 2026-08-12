import '../../core/database/database_service.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../contacts/data/contact_repository.dart';
import '../crypto/domain/device_key_material.dart';
import '../identity/domain/identity_session.dart';
import 'data/safety_number_verification_repository.dart';
import 'domain/safety_number_service.dart';

class SafetyNumberModule extends AppModule {
  @override
  String get name => 'safety_number';

  @override
  Future<void> init(ModuleContext context) async {
    final repository = SafetyNumberVerificationRepository(
      context.services.get<DatabaseService>().db,
    );
    context.services.registerSingleton<SafetyNumberVerificationRepository>(
      repository,
    );
    context.services.registerSingleton<SafetyNumberService>(
      SafetyNumberService(
        identity: context.services.get<IdentitySession>(),
        localPublicKey: context.services.get<DeviceKeyMaterial>().publicKey,
        contacts: context.services.get<ContactRepository>(),
        verifications: repository,
      ),
    );
  }
}
