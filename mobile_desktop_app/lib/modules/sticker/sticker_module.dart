import '../../core/events/event_bus.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../../core/routing/route_registry.dart';
import 'data/built_in_sticker_catalog.dart';

class StickerModule implements AppModule {
  @override
  String get name => 'sticker';

  @override
  Future<void> init(ModuleContext context) async {
    final catalog = BuiltInStickerCatalog();
    await catalog.load();
    context.services.registerSingleton<BuiltInStickerCatalog>(catalog);
  }

  @override
  void registerEvents(EventBus eventBus) {}

  @override
  void registerRoutes(RouteRegistry routes) {}

  @override
  Future<void> activate() async {}

  @override
  Future<void> sleep() async {}

  @override
  void dispose() {}
}
