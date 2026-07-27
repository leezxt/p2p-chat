import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/foreground_mailbox_sync_scheduler.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_refresh_service.dart';

void main() {
  test('進入前景時立即同步並以指定週期排程', () async {
    final mailbox = _MailboxRefresh();
    final timers = _TimerFactory();
    final scheduler = ForegroundMailboxSyncScheduler(
      mailbox: mailbox,
      interval: const Duration(minutes: 1),
      timerFactory: timers.call,
    );

    await scheduler.start();

    expect(mailbox.refreshes, 1);
    expect(scheduler.isRunning, isTrue);
    expect(timers.intervals, [const Duration(minutes: 1)]);

    timers.fire();
    await Future<void>.delayed(Duration.zero);
    expect(mailbox.refreshes, 2);
  });

  test('低功耗切換會重設前景週期，且不額外同步', () async {
    final mailbox = _MailboxRefresh();
    final timers = _TimerFactory();
    final scheduler = ForegroundMailboxSyncScheduler(
      mailbox: mailbox,
      interval: const Duration(minutes: 1),
      timerFactory: timers.call,
    );
    await scheduler.start();

    scheduler.updateInterval(const Duration(minutes: 5));

    expect(mailbox.refreshes, 1);
    expect(timers.intervals, [
      const Duration(minutes: 1),
      const Duration(minutes: 5),
    ]);
    expect(timers.timers.first.isActive, isFalse);
  });

  test('進背景後停止排程並忽略已排入的同步', () async {
    final mailbox = _MailboxRefresh();
    final timers = _TimerFactory();
    final scheduler = ForegroundMailboxSyncScheduler(
      mailbox: mailbox,
      interval: const Duration(minutes: 1),
      timerFactory: timers.call,
    );
    await scheduler.start();

    scheduler.stop();
    timers.fire(force: true);
    await Future<void>.delayed(Duration.zero);

    expect(scheduler.isRunning, isFalse);
    expect(timers.timers.single.isActive, isFalse);
    expect(mailbox.refreshes, 1);
  });

  test('同步錯誤會記錄並允許下一次週期重試', () async {
    final mailbox = _MailboxRefresh(failures: 1);
    final timers = _TimerFactory();
    Object? error;
    final scheduler = ForegroundMailboxSyncScheduler(
      mailbox: mailbox,
      interval: const Duration(minutes: 1),
      timerFactory: timers.call,
      onError: (value, _) => error = value,
    );

    await scheduler.start();
    expect(error, isA<StateError>());

    timers.fire();
    await Future<void>.delayed(Duration.zero);
    expect(mailbox.refreshes, 2);
  });
}

class _MailboxRefresh implements MailboxRefreshService {
  _MailboxRefresh({this.failures = 0});

  int failures;
  int refreshes = 0;

  @override
  Future<void> refresh() async {
    refreshes++;
    if (failures > 0) {
      failures--;
      throw StateError('offline');
    }
  }
}

class _TimerFactory {
  final List<Duration> intervals = [];
  final List<_FakeTimer> timers = [];
  final List<void Function(Timer)> _callbacks = [];

  Timer call(Duration interval, void Function(Timer) callback) {
    intervals.add(interval);
    final timer = _FakeTimer();
    timers.add(timer);
    _callbacks.add(callback);
    return timer;
  }

  void fire({bool force = false}) {
    final timer = timers.last;
    if (force || timer.isActive) _callbacks.last(timer);
  }
}

class _FakeTimer implements Timer {
  bool _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => 0;

  @override
  void cancel() => _isActive = false;
}
