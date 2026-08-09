import '../../core/database/database_service.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../push/domain/notification_presentation_policy.dart';
import 'data/sqlite_notification_preference_repository.dart';
import 'domain/smart_notification_service.dart';

class SmartNotificationModule extends AppModule {
  @override
  String get name => 'smart_notification';

  @override
  Future<void> init(ModuleContext context) async {
    final policy = context.services.get<NotificationPresentationPolicy>();
    final repository = SqliteNotificationPreferenceRepository(
      context.services.get<DatabaseService>().db,
    );
    context.services.registerSingleton<SmartNotificationService>(
      SmartNotificationService(
        preferences: repository,
        presentationPolicy: policy,
      ),
    );
  }

  @override
  Future<void> activate() async {}

  @override
  Future<void> sleep() async {}

  @override
  void dispose() {}
}
