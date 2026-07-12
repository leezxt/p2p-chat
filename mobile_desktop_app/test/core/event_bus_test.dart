import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/events/app_event.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';

class _PingEvent extends AppEvent {
  const _PingEvent(this.value);
  final int value;
}

class _OtherEvent extends AppEvent {
  const _OtherEvent();
}

void main() {
  group('EventBus', () {
    test('派送給對應型別的訂閱者', () {
      final bus = EventBus();
      final received = <int>[];
      bus.on<_PingEvent>((e) => received.add(e.value));

      bus.emit(const _PingEvent(1));
      bus.emit(const _PingEvent(2));

      expect(received, [1, 2]);
    });

    test('不同型別互不干擾', () {
      final bus = EventBus();
      var pings = 0;
      var others = 0;
      bus.on<_PingEvent>((_) => pings++);
      bus.on<_OtherEvent>((_) => others++);

      bus.emit(const _PingEvent(1));

      expect(pings, 1);
      expect(others, 0);
    });

    test('cancel 後不再收到事件', () {
      final bus = EventBus();
      var count = 0;
      final sub = bus.on<_PingEvent>((_) => count++);

      bus.emit(const _PingEvent(1));
      sub.cancel();
      bus.emit(const _PingEvent(1));

      expect(count, 1);
      expect(bus.listenerCount(_PingEvent), 0);
    });

    test('單一 handler 拋錯不影響其他 handler', () {
      Object? captured;
      final bus = EventBus(onHandlerError: (e, _) => captured = e);
      var reached = false;
      bus.on<_PingEvent>((_) => throw StateError('boom'));
      bus.on<_PingEvent>((_) => reached = true);

      bus.emit(const _PingEvent(1));

      expect(reached, isTrue);
      expect(captured, isA<StateError>());
    });
  });
}
