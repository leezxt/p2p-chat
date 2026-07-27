import 'dart:async';

import 'mailbox_refresh_service.dart';

typedef PeriodicTimerFactory = Timer Function(
  Duration interval,
  void Function(Timer timer) callback,
);

/// 僅在 App 前景執行的 mailbox 同步排程。
///
/// 背景不維持 Timer 或長連線，避免和 Push／省電策略衝突；每次 refresh
/// 仍由 [MailboxRefreshService] 執行冪等的聯絡人、收件與狀態同步。
class ForegroundMailboxSyncScheduler {
  ForegroundMailboxSyncScheduler({
    required MailboxRefreshService mailbox,
    required Duration interval,
    void Function(Object error, StackTrace stackTrace)? onError,
    PeriodicTimerFactory? timerFactory,
  })  : _mailbox = mailbox,
        _interval = interval,
        _onError = onError,
        _timerFactory = timerFactory ?? Timer.periodic;

  final MailboxRefreshService _mailbox;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  final PeriodicTimerFactory _timerFactory;
  Timer? _timer;
  Future<void> _pending = Future<void>.value();
  Duration _interval;
  bool _foreground = false;

  bool get isRunning => _foreground;
  Duration get interval => _interval;

  /// 進入前景時立即同步一次，並開始低頻輪詢。
  Future<void> start() {
    if (!_foreground) {
      _foreground = true;
      _startTimer();
    }
    return _refresh();
  }

  /// App 進背景時停止輪詢；不取消已開始的短暫同步。
  void stop() {
    _foreground = false;
    _timer?.cancel();
    _timer = null;
  }

  /// 低功耗模式切換時套用新週期，不額外製造一次網路請求。
  void updateInterval(Duration interval) {
    if (_interval == interval) return;
    _interval = interval;
    if (_foreground) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void dispose() => stop();

  void _startTimer() {
    _timer = _timerFactory(_interval, (_) {
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() {
    _pending = _pending.then((_) async {
      // Timer callback 可能剛好與進背景交錯；真正送出網路請求前再確認一次。
      if (_foreground) await _mailbox.refresh();
    }).catchError((Object error, StackTrace stackTrace) {
      _onError?.call(error, stackTrace);
    });
    return _pending;
  }
}
