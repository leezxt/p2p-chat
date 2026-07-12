import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/config/config_service.dart';
import 'package:p2p_chat_app/core/di/service_locator.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/core/module/app_module.dart';
import 'package:p2p_chat_app/core/module/module_context.dart';
import 'package:p2p_chat_app/core/module/module_lifecycle.dart';
import 'package:p2p_chat_app/core/module/module_registry.dart';
import 'package:p2p_chat_app/core/resource_policy/resource_policy_service.dart';
import 'package:p2p_chat_app/core/routing/route_registry.dart';

/// 記錄生命週期呼叫順序的假模組。
class _FakeModule implements AppModule {
  _FakeModule(this.name);
  @override
  final String name;
  final List<String> calls = [];

  @override
  Future<void> init(ModuleContext context) async => calls.add('init');
  @override
  void registerRoutes(RouteRegistry routes) => calls.add('routes');
  @override
  void registerEvents(EventBus eventBus) => calls.add('events');
  @override
  Future<void> activate() async => calls.add('activate');
  @override
  Future<void> sleep() async => calls.add('sleep');
  @override
  void dispose() => calls.add('dispose');
}

ModuleContext _context() => ModuleContext(
      eventBus: EventBus(),
      config: ConfigService(),
      logger: LoggingService(minLevel: LogLevel.error),
      resourcePolicy: ResourcePolicyService(ConfigService()),
      services: ServiceLocator(),
    );

void main() {
  group('ModuleRegistry', () {
    test('可註冊並 init 多個模組', () async {
      final registry = ModuleRegistry(_context(), RouteRegistry());
      final a = _FakeModule('a');
      final b = _FakeModule('b');
      final c = _FakeModule('c');
      registry
        ..register(a)
        ..register(b)
        ..register(c);

      await registry.initEnabledModules();

      expect(a.calls, ['init', 'routes', 'events']);
      expect(registry.stateOf('a'), ModuleState.enabled);
      expect(registry.modules.length, 3);
    });

    test('disabled 模組不被 init', () async {
      final registry = ModuleRegistry(_context(), RouteRegistry());
      final heavy = _FakeModule('video_call');
      registry.register(heavy, initial: ModuleState.disabled);

      await registry.initEnabledModules();

      expect(heavy.calls, isEmpty);
    });

    test('activate / sleep 轉換狀態並呼叫生命週期', () async {
      final registry = ModuleRegistry(_context(), RouteRegistry());
      final m = _FakeModule('p2p');
      registry.register(m, initial: ModuleState.sleeping);
      await registry.initEnabledModules();

      await registry.activate('p2p');
      expect(registry.stateOf('p2p'), ModuleState.active);
      expect(m.calls, contains('activate'));

      await registry.sleep('p2p');
      expect(registry.stateOf('p2p'), ModuleState.sleeping);
      expect(m.calls, contains('sleep'));
    });

    test('重複名稱註冊拋出', () {
      final registry = ModuleRegistry(_context(), RouteRegistry());
      registry.register(_FakeModule('dup'));
      expect(() => registry.register(_FakeModule('dup')), throwsStateError);
    });

    test('init 失敗的模組被標記 disabled 而不中斷其他模組', () async {
      final registry = ModuleRegistry(_context(), RouteRegistry());
      registry.register(_ThrowingModule());
      final ok = _FakeModule('ok');
      registry.register(ok);

      await registry.initEnabledModules();

      expect(registry.stateOf('bad'), ModuleState.disabled);
      expect(ok.calls, contains('init'));
    });
  });
}

class _ThrowingModule implements AppModule {
  @override
  String get name => 'bad';
  @override
  Future<void> init(ModuleContext context) async => throw StateError('boom');
  @override
  void registerRoutes(RouteRegistry routes) {}
  @override
  void registerEvents(EventBus eventBus) {}
  @override
  Future<void> activate() async {}
  @override
  Future<void> sleep() async {}
  @override
  void dispose() {}
}
