import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/presence/domain/presence_client.dart';
import 'package:p2p_chat_app/modules/presence/domain/presence_service.dart';

void main() {
  test('前景立即並週期 heartbeat，stop 後不再更新', () async {
    final client = _FakePresenceClient();
    final service = PresenceService(
      client: client,
      localDeviceId: 'local-device',
      interval: const Duration(milliseconds: 20),
    );

    await service.start();
    await Future<void>.delayed(const Duration(milliseconds: 55));
    expect(client.heartbeats, greaterThanOrEqualTo(3));
    expect(client.devices, everyElement('local-device'));

    service.stop();
    final stoppedAt = client.heartbeats;
    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(client.heartbeats, stoppedAt);
    service.dispose();
  });

  test('lastSeen 只顯示粗粒度在線狀態', () async {
    final now = DateTime.utc(2026, 7, 12, 8);
    final client = _FakePresenceClient()
      ..contacts = [
        ContactPresence(
          userId: 'online',
          deviceId: 'd1',
          lastSeenAt: now.subtract(const Duration(seconds: 90)),
        ),
        ContactPresence(
          userId: 'recent',
          deviceId: 'd2',
          lastSeenAt: now.subtract(const Duration(minutes: 3)),
        ),
        ContactPresence(
          userId: 'offline',
          deviceId: 'd3',
          lastSeenAt: now.subtract(const Duration(minutes: 6)),
        ),
      ];
    final service = PresenceService(
      client: client,
      localDeviceId: 'local-device',
      interval: const Duration(minutes: 1),
      clock: () => now,
    );

    await service.refresh();

    expect(service.stateFor('online'), ContactPresenceState.online);
    expect(service.stateFor('recent'), ContactPresenceState.recentlyOnline);
    expect(service.stateFor('offline'), ContactPresenceState.offline);
    expect(service.stateFor('unknown'), ContactPresenceState.offline);
    service.dispose();
  });

  test('heartbeat 等待網路時進背景不會在 stop 後建立 timer', () async {
    final gate = Completer<void>();
    final client = _FakePresenceClient()..heartbeatGate = gate.future;
    final service = PresenceService(
      client: client,
      localDeviceId: 'local-device',
      interval: const Duration(milliseconds: 10),
    );

    final starting = service.start();
    await Future<void>.delayed(Duration.zero);
    service.stop();
    gate.complete();
    await starting;
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(service.active, isFalse);
    expect(client.heartbeats, 1);
    service.dispose();
  });

  test('active 時更新 interval 會立即重排 heartbeat timer', () async {
    final client = _FakePresenceClient();
    final service = PresenceService(
      client: client,
      localDeviceId: 'local-device',
      interval: const Duration(seconds: 1),
    );

    await service.start();
    service.updateInterval(const Duration(milliseconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 35));

    expect(service.interval, const Duration(milliseconds: 10));
    expect(client.heartbeats, greaterThanOrEqualTo(3));
    service.dispose();
  });
}

class _FakePresenceClient implements PresenceClient {
  int heartbeats = 0;
  final List<String> devices = [];
  List<ContactPresence> contacts = const [];
  Future<void>? heartbeatGate;

  @override
  Future<void> heartbeat(String deviceId) async {
    heartbeats++;
    devices.add(deviceId);
    await heartbeatGate;
  }

  @override
  Future<List<ContactPresence>> fetchContacts() async => contacts;
}
