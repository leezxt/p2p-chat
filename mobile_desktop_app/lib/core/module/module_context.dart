import '../config/config_service.dart';
import '../di/service_locator.dart';
import '../events/event_bus.dart';
import '../logging/logging_service.dart';
import '../resource_policy/resource_policy_service.dart';

/// 傳給每個模組 `init` 的核心服務容器。
///
/// Core 只透過此容器把共用服務交給模組；模組不得反向持有其他模組實例，
/// 跨模組溝通一律走 [eventBus]（規格 §26 規則 2、4）。
class ModuleContext {
  const ModuleContext({
    required this.eventBus,
    required this.config,
    required this.logger,
    required this.resourcePolicy,
    required this.services,
  });

  /// 模組間鬆耦合溝通用的事件匯流排。
  final EventBus eventBus;

  /// 全域設定。
  final ConfigService config;

  /// 分級日誌服務。
  final LoggingService logger;

  /// 省電 / 低記憶體 / 連線數策略。
  final ResourcePolicyService resourcePolicy;

  /// 服務定位（DI）；模組可註冊 / 取用共用服務（如資料庫）。
  final ServiceLocator services;
}
