import 'dart:async';

import '../../core/database/database_service.dart';
import '../../core/events/event_bus.dart';
import '../../core/logging/logging_service.dart';
import '../../core/module/app_module.dart';
import '../../core/module/module_context.dart';
import '../../core/routing/route_registry.dart';
import '../../shared/models/message_type.dart';
import '../../shared/models/message_envelope.dart';
import '../chat/events/chat_events.dart';
import 'data/reaction_repository.dart';

class ReactionModule implements AppModule {
  EventSubscription? _messageStoredSubscription;
  late LoggingService _logger;

  @override
  String get name => 'reaction';

  @override
  Future<void> init(ModuleContext context) async {
    final db = context.services.get<DatabaseService>().db;
    _repository = ReactionRepository(db);
    _logger = context.logger;
    context.services.registerSingleton<ReactionRepository>(_repository);
  }

  @override
  void registerEvents(EventBus eventBus) {
    _messageStoredSubscription = eventBus.on<MessageStored>((event) {
      if (event.message.type != MessageType.reaction) return;
      unawaited(_apply(event.message));
    });
  }

  Future<void> _apply(MessageEnvelope message) async {
    try {
      await _repository.applyEnvelope(message);
    } catch (_, stackTrace) {
      _logger.error('reaction', 'reaction event 套用失敗', stackTrace);
    }
  }

  late ReactionRepository _repository;

  @override
  void registerRoutes(RouteRegistry routes) {}

  @override
  Future<void> activate() async {}

  @override
  Future<void> sleep() async {}

  @override
  void dispose() {
    _messageStoredSubscription?.cancel();
  }
}
