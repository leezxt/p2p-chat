import 'app_event.dart';

/// 訂閱取消控制代碼。呼叫 [cancel] 解除訂閱，避免記憶體洩漏。
class EventSubscription {
  EventSubscription._(this._onCancel);
  final void Function() _onCancel;
  bool _cancelled = false;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel();
  }
}

/// 型別化事件匯流排：模組以事件型別訂閱，彼此不需互相持有實例。
///
/// 採同步派送（依註冊順序）。handler 內若需做 I/O，自行 unawaited 或排入 queue，
/// 避免阻塞派送迴圈。單一 handler 拋錯不影響其他 handler。
class EventBus {
  EventBus({void Function(Object error, StackTrace st)? onHandlerError})
      : _onHandlerError = onHandlerError;

  final void Function(Object error, StackTrace st)? _onHandlerError;

  /// 依事件型別存放 handler。使用 List 保序。
  final Map<Type, List<_Handler>> _handlers = {};

  /// 訂閱型別為 [T] 的事件。回傳可取消的 [EventSubscription]。
  EventSubscription on<T extends AppEvent>(void Function(T event) handler) {
    final entry = _Handler((event) => handler(event as T));
    _handlers.putIfAbsent(T, () => []).add(entry);
    return EventSubscription._(() {
      _handlers[T]?.remove(entry);
    });
  }

  /// 發佈事件，同步派送給所有訂閱者。
  void emit<T extends AppEvent>(T event) {
    final list = _handlers[event.runtimeType];
    if (list == null || list.isEmpty) return;
    // 複製一份，避免 handler 內部再訂閱 / 取消時修改到迭代中的集合。
    for (final h in List<_Handler>.from(list)) {
      try {
        h.callback(event);
      } catch (e, st) {
        _onHandlerError?.call(e, st);
      }
    }
  }

  /// 目前某事件型別的訂閱數（測試 / 診斷用）。
  int listenerCount(Type type) => _handlers[type]?.length ?? 0;

  /// 清空所有訂閱（App 關閉時）。
  void clear() => _handlers.clear();
}

class _Handler {
  _Handler(this.callback);
  final void Function(AppEvent event) callback;
}
