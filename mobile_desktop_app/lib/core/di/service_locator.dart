/// 極簡服務定位器（DI）。
///
/// 用於註冊 / 取用跨模組共用的服務（如資料庫）。刻意保持輕量，不引入
/// 大型 DI 框架，符合「最小必要依賴」原則。以型別為鍵，單例。
class ServiceLocator {
  final Map<Type, Object> _singletons = {};
  final Map<Type, Object Function()> _factories = {};

  /// 註冊單例。重複註冊同型別會拋出。
  void registerSingleton<T extends Object>(T instance) {
    if (_singletons.containsKey(T) || _factories.containsKey(T)) {
      throw StateError('服務已註冊：$T');
    }
    _singletons[T] = instance;
  }

  /// 註冊 lazy 單例：首次 get 時才建立。
  void registerLazySingleton<T extends Object>(T Function() factory) {
    if (_singletons.containsKey(T) || _factories.containsKey(T)) {
      throw StateError('服務已註冊：$T');
    }
    _factories[T] = factory;
  }

  /// 取用服務。未註冊會拋出。
  T get<T extends Object>() {
    final existing = _singletons[T];
    if (existing != null) return existing as T;

    final factory = _factories[T];
    if (factory != null) {
      final created = factory() as T;
      _singletons[T] = created;
      _factories.remove(T);
      return created;
    }
    throw StateError('未註冊的服務：$T');
  }

  bool isRegistered<T extends Object>() =>
      _singletons.containsKey(T) || _factories.containsKey(T);

  void clear() {
    _singletons.clear();
    _factories.clear();
  }
}
