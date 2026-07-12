import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/di/service_locator.dart';

class _ServiceA {
  int calls = 0;
}

void main() {
  group('ServiceLocator', () {
    test('註冊與取用單例', () {
      final locator = ServiceLocator();
      final a = _ServiceA();
      locator.registerSingleton<_ServiceA>(a);

      expect(locator.get<_ServiceA>(), same(a));
      expect(locator.isRegistered<_ServiceA>(), isTrue);
    });

    test('重複註冊拋出', () {
      final locator = ServiceLocator();
      locator.registerSingleton<_ServiceA>(_ServiceA());
      expect(
        () => locator.registerSingleton<_ServiceA>(_ServiceA()),
        throwsStateError,
      );
    });

    test('未註冊取用拋出', () {
      final locator = ServiceLocator();
      expect(() => locator.get<_ServiceA>(), throwsStateError);
    });

    test('lazy 單例首次取用才建立且只建立一次', () {
      final locator = ServiceLocator();
      var built = 0;
      locator.registerLazySingleton<_ServiceA>(() {
        built++;
        return _ServiceA();
      });

      expect(built, 0);
      final first = locator.get<_ServiceA>();
      final second = locator.get<_ServiceA>();
      expect(built, 1);
      expect(first, same(second));
    });
  });
}
