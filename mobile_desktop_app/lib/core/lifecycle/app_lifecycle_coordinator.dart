import 'package:flutter/widgets.dart';

/// 將平台生命週期轉成一次性的背景資源釋放動作。
///
/// 同一次背景切換可能依序收到 hidden、paused、detached；只執行一次，
/// resumed 後才允許下一次背景切換再次執行。
class AppLifecycleCoordinator {
  AppLifecycleCoordinator({required this.onBackground, this.onForeground});

  final Future<void> Function() onBackground;
  final Future<void> Function()? onForeground;
  bool _backgrounded = false;

  Future<void> handle(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      _backgrounded = false;
      await enterForeground();
      return;
    }
    if (!_isBackground(state) || _backgrounded) return;
    _backgrounded = true;
    try {
      await onBackground();
    } catch (_) {
      _backgrounded = false;
      rethrow;
    }
  }

  Future<void> enterForeground() async {
    await onForeground?.call();
  }

  bool _isBackground(AppLifecycleState state) =>
      state == AppLifecycleState.hidden ||
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached;
}
