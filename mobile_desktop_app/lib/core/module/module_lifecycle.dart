/// 模組生命週期狀態（規格 §10）。
///
/// 高耗能模組（語音 / 視訊 / 檔案 / AI）預設應為 [disabled] 或 [sleeping]，
/// 需要時才 activate，用完立即釋放資源回到 sleeping。
enum ModuleState {
  /// 已安裝，尚未啟用。
  installed,

  /// 已啟用，隨 App 啟動 init。
  enabled,

  /// 目前正在使用，持有資源。
  active,

  /// 休眠：釋放大部分資源，可快速喚醒。
  sleeping,

  /// 停用：不 init（高耗能模組預設值）。
  disabled,
}
