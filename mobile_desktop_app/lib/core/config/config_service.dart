/// 全域設定服務。
///
/// Sprint 0–1 先用記憶體實作，之後可換成讀取本機儲存 / 遠端設定，
/// 介面保持不變即可（規格 §26 規則 12：新增功能不改壞 Core）。
class ConfigService {
  ConfigService({Map<String, Object?>? initial}) : _values = {...?initial};

  final Map<String, Object?> _values;

  /// 是否啟用低功耗模式（規格 §19.2）。預設 false。
  bool get lowPowerMode => getBool('lowPowerMode', fallback: false);
  set lowPowerMode(bool value) => set('lowPowerMode', value);

  /// 圖片是否自動下載。依規格 §21 預設關閉。
  bool get autoDownloadImages => getBool('autoDownloadImages', fallback: false);

  /// 聊天室一次載入訊息數（規格 §21：最近 50 則）。
  int get chatPageSize => getInt('chatPageSize', fallback: 50);

  T? get<T>(String key) => _values[key] as T?;

  bool getBool(String key, {required bool fallback}) =>
      (_values[key] as bool?) ?? fallback;

  int getInt(String key, {required int fallback}) =>
      (_values[key] as int?) ?? fallback;

  String getString(String key, {required String fallback}) =>
      (_values[key] as String?) ?? fallback;

  void set(String key, Object? value) => _values[key] = value;
}
