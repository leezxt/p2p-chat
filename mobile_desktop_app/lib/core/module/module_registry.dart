import '../logging/logging_service.dart';
import '../routing/route_registry.dart';
import 'app_module.dart';
import 'module_context.dart';
import 'module_lifecycle.dart';

/// 模組註冊表：集中管理模組的註冊、初始化與生命週期轉換（規格 §6、§10）。
///
/// Core 只認識 [AppModule] 介面，不認識任何具體模組型別，
/// 因此新增功能模組不需修改 Core（規格 §26 規則 12）。
class ModuleRegistry {
  ModuleRegistry(this._context, this._routes) : _logger = _context.logger;

  final ModuleContext _context;
  final RouteRegistry _routes;
  final LoggingService _logger;

  final Map<String, AppModule> _modules = {};
  final Map<String, ModuleState> _states = {};

  /// 已註冊模組（唯讀）。
  Iterable<AppModule> get modules => _modules.values;

  ModuleState? stateOf(String name) => _states[name];

  /// 註冊模組並設定初始狀態。重複名稱會拋出，避免覆蓋。
  void register(AppModule module, {ModuleState initial = ModuleState.enabled}) {
    if (_modules.containsKey(module.name)) {
      throw StateError('模組名稱重複註冊：${module.name}');
    }
    _modules[module.name] = module;
    _states[module.name] = initial;
    _logger.debug('module', '註冊 ${module.name}（初始狀態 $initial）');
  }

  /// 初始化所有非 disabled 模組，並註冊其路由與事件。
  /// 高耗能模組應以 disabled 註冊，不會在此被 init（規格 §9）。
  Future<void> initEnabledModules() async {
    for (final module in _modules.values) {
      if (_states[module.name] == ModuleState.disabled) {
        _logger.debug('module', '略過 disabled 模組 ${module.name}');
        continue;
      }
      await _initOne(module);
    }
  }

  Future<void> _initOne(AppModule module) async {
    try {
      await module.init(_context);
      module.registerRoutes(_routes);
      module.registerEvents(_context.eventBus);
      _logger.info('module', '已 init ${module.name}');
    } catch (e, st) {
      // init 失敗不應讓整個 App 崩潰；標記 disabled 並記錄。
      _states[module.name] = ModuleState.disabled;
      _logger.error('module', 'init 失敗 ${module.name}: $e', st);
    }
  }

  /// 喚醒模組到 active。sleeping / enabled → active。
  Future<void> activate(String name) async {
    final module = _require(name);
    await module.activate();
    _states[name] = ModuleState.active;
    _logger.info('module', 'activate $name');
  }

  /// 讓模組進入 sleeping，釋放資源。
  Future<void> sleep(String name) async {
    final module = _require(name);
    await module.sleep();
    _states[name] = ModuleState.sleeping;
    _logger.info('module', 'sleep $name');
  }

  /// App 關閉時逐一 dispose。
  void disposeAll() {
    for (final module in _modules.values) {
      try {
        module.dispose();
      } catch (e, st) {
        _logger.error('module', 'dispose 失敗 ${module.name}: $e', st);
      }
    }
    _modules.clear();
    _states.clear();
  }

  AppModule _require(String name) {
    final module = _modules[name];
    if (module == null) throw StateError('未註冊的模組：$name');
    return module;
  }
}
