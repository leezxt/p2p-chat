import '../config/config_service.dart';

/// 資源政策服務：集中管理省電 / 低記憶體 / 連線數策略（規格 §21）。
///
/// 所有模組都必須遵守 Resource Policy（規格 §6.2 規則 8）。模組在建立連線、
/// 載入資料、啟動音訊 / 相機前，應向此服務查詢上限與策略。
class ResourcePolicyService {
  ResourcePolicyService(this._config);

  final ConfigService _config;

  /// 同時 P2P 連線上限（規格 §21：1～3 條）。低功耗時收斂為 1。
  int get maxConcurrentP2pConnections => _config.lowPowerMode ? 1 : 3;

  /// 前景 presence heartbeat 間隔秒數（規格 §16、§21：60 秒）。
  int get presenceHeartbeatSeconds => 60;

  /// 背景是否維持 P2P。永遠 false（規格 §5.2、§26 規則 6）。
  bool get keepP2pInBackground => false;

  /// 聊天室單次載入訊息數（規格 §21：最近 50 則）。
  int get chatInitialPageSize => _config.chatPageSize;

  /// 聊天室閒置多久後斷開 P2P（規格 §9：1～3 分鐘）。
  Duration get idleDisconnectAfter => const Duration(minutes: 2);

  /// 圖片是否自動下載（預設關閉）。
  bool get autoDownloadImages => _config.autoDownloadImages;

  /// 高耗能模組是否允許在目前狀態啟動。
  /// 低功耗模式下拒絕自動啟動，需使用者明確操作。
  bool allowHeavyModuleAutoActivate() => !_config.lowPowerMode;
}
