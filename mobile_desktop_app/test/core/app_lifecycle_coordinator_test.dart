import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/lifecycle/app_lifecycle_coordinator.dart';

void main() {
  test('初始前景與 resumed 會觸發 foreground callback', () async {
    var foregroundCount = 0;
    final coordinator = AppLifecycleCoordinator(
      onBackground: () async {},
      onForeground: () async => foregroundCount++,
    );

    await coordinator.enterForeground();
    await coordinator.handle(AppLifecycleState.resumed);

    expect(foregroundCount, 2);
  });

  test('同一次背景切換只釋放資源一次', () async {
    var calls = 0;
    final coordinator = AppLifecycleCoordinator(
      onBackground: () async => calls += 1,
    );

    await coordinator.handle(AppLifecycleState.inactive);
    await coordinator.handle(AppLifecycleState.hidden);
    await coordinator.handle(AppLifecycleState.paused);
    await coordinator.handle(AppLifecycleState.detached);

    expect(calls, 1);
  });

  test('resumed 不主動重連，但允許下一次背景切換再次釋放', () async {
    var calls = 0;
    final coordinator = AppLifecycleCoordinator(
      onBackground: () async => calls += 1,
    );

    await coordinator.handle(AppLifecycleState.paused);
    await coordinator.handle(AppLifecycleState.resumed);
    expect(calls, 1);

    await coordinator.handle(AppLifecycleState.hidden);
    expect(calls, 2);
  });

  test('背景釋放失敗時可在下一個背景事件重試', () async {
    var calls = 0;
    final coordinator = AppLifecycleCoordinator(
      onBackground: () async {
        calls += 1;
        if (calls == 1) throw StateError('close failed');
      },
    );

    await expectLater(
      coordinator.handle(AppLifecycleState.paused),
      throwsStateError,
    );
    await coordinator.handle(AppLifecycleState.detached);

    expect(calls, 2);
  });
}
