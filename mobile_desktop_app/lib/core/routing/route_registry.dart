import 'package:flutter/material.dart';

/// 路由建構器：由路由參數建立頁面 Widget。
typedef RouteBuilder = Widget Function(BuildContext context, Object? args);

/// 路由註冊表：模組在 `registerRoutes` 時把自己的頁面登記進來。
///
/// Core 不需知道各模組有哪些頁面；路由由模組自行宣告（規格 §9）。
class RouteRegistry {
  final Map<String, RouteBuilder> _routes = {};

  /// 已註冊路由名稱（唯讀）。
  Iterable<String> get routeNames => _routes.keys;

  /// 登記一條路由。重複路徑會拋出，避免模組間覆蓋。
  void add(String path, RouteBuilder builder) {
    if (_routes.containsKey(path)) {
      throw StateError('路由重複註冊：$path');
    }
    _routes[path] = builder;
  }

  bool contains(String path) => _routes.containsKey(path);

  RouteBuilder? builderFor(String path) => _routes[path];

  /// 轉為 Flutter [Navigator] 使用的 onGenerateRoute。
  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = _routes[settings.name];
    if (builder == null) return null;
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (context) => builder(context, settings.arguments),
    );
  }
}
