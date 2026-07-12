/// 所有事件的基底型別。
///
/// 事件是模組間唯一的溝通管道（規格 §26 規則 4）。定義新事件時繼承此類，
/// 建議事件命名見 docs/architecture 與規格 §11。
abstract class AppEvent {
  const AppEvent();

  /// 事件建立時間（Unix epoch 毫秒），方便除錯與排序。
  int get occurredAt => DateTime.now().millisecondsSinceEpoch;
}
