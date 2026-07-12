import '../../core/database/database_service.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import 'data/contact_repository.dart';
import 'domain/contact_service.dart';
import '../../core/network/backend_api.dart';
import '../crypto/data/remote_key_trust_repository.dart';

class ContactsModule extends AppModule {
  @override
  String get name => 'contacts';
  @override
  Future<void> init(ModuleContext context) async {
    final db = context.services.get<DatabaseService>().db;
    final repository = ContactRepository(db);
    context.services.registerSingleton<ContactRepository>(repository);
    if (context.services.isRegistered<BackendApi>() &&
        context.services.isRegistered<AccessSession>()) {
      context.services.registerSingleton<ContactService>(ContactService(
          context.services.get<BackendApi>(),
          context.services.get<AccessSession>(),
          repository,
          keyTrust: context.services.get<RemoteKeyTrustRepository>(),
          eventBus: context.eventBus));
    }
  }

  @override
  Future<void> activate() async {}
  @override
  Future<void> sleep() async {}
  @override
  void dispose() {}
}
