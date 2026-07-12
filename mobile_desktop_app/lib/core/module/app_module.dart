import '../events/event_bus.dart';
import '../routing/route_registry.dart';
import 'module_context.dart';

/// 所有功能模組的統一介面（規格 §9）。
///
/// 每個模組都必須支援完整生命週期：
/// `init → registerRoutes / registerEvents → activate ⇄ sleep → dispose`。
///
/// 設計約束：
/// - Core 不依賴任何單一功能模組（規格 §0 規則 2）。
/// - 模組之間不直接呼叫彼此內部實作，只透過 EventBus 溝通。
/// - 高耗能模組預設不在啟動時 activate（規格 §9）。
abstract class AppModule {
  /// 模組唯一名稱（如 'chat'、'p2p'）。ModuleRegistry 以此為鍵。
  String get name;

  /// 初始化：建立資料表、Repository、Controller 等。
  /// 只做輕量準備，不得在此開啟長連線或相機 / 麥克風等重資源。
  Future<void> init(ModuleContext context);

  /// 註冊本模組的路由（可選，無畫面模組可留空）。
  void registerRoutes(RouteRegistry routes) {}

  /// 訂閱 / 準備發出的事件（可選）。
  void registerEvents(EventBus eventBus) {}

  /// 進入 active：開始使用、可持有資源。
  Future<void> activate() async {}

  /// 進入 sleeping：釋放大部分資源，保留可快速喚醒的最小狀態。
  Future<void> sleep() async {}

  /// 徹底釋放資源（App 關閉 / 模組卸載）。
  void dispose() {}
}
