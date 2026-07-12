import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/mailbox/domain/mailbox_refresh_service.dart';
import 'package:p2p_chat_app/modules/push/domain/notification_launch_source.dart';
import 'package:p2p_chat_app/modules/push/domain/push_launch_coordinator.dart';
import 'package:p2p_chat_app/modules/push/domain/push_notification_payload.dart';

void main() {
  const validData = <String, Object?>{
    'schemaVersion': 1,
    'type': 'MAILBOX_AVAILABLE',
  };

  test('parser accepts only the versioned privacy-safe mailbox payload', () {
    expect(PushNotificationPayload.tryParse(validData), isNotNull);
    expect(
      PushNotificationPayload.tryParse(const {
        'schemaVersion': '1',
        'type': 'MAILBOX_AVAILABLE',
      }),
      isNotNull,
    );
    expect(
      PushNotificationPayload.tryParse(const {
        'schemaVersion': 2,
        'type': 'MAILBOX_AVAILABLE',
      }),
      isNull,
    );
    expect(
      PushNotificationPayload.tryParse(const {
        'schemaVersion': 1,
        'type': 'MAILBOX_AVAILABLE',
        'conversationId': 'must-not-be-present',
      }),
      isNull,
    );
  });

  test('cold launch refreshes mailbox and opens chat list once', () async {
    final mailbox = _MailboxRefresh();
    final source = _LaunchSource(
      initial: const NotificationLaunch(launchId: 'cold-1', data: validData),
    );
    var opens = 0;
    final coordinator = PushLaunchCoordinator(
      source: source,
      mailbox: mailbox,
      openChatList: () async => opens++,
    );

    await coordinator.start();
    await coordinator.start();

    expect(mailbox.refreshes, 1);
    expect(opens, 1);
    await coordinator.dispose();
  });

  test('warm duplicate launch IDs are serialized and handled once', () async {
    final mailbox = _MailboxRefresh();
    final source = _LaunchSource();
    var opens = 0;
    final coordinator = PushLaunchCoordinator(
      source: source,
      mailbox: mailbox,
      openChatList: () async => opens++,
    );
    await coordinator.start();

    const launch = NotificationLaunch(launchId: 'warm-1', data: validData);
    source.add(launch);
    source.add(launch);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(mailbox.refreshes, 1);
    expect(opens, 1);
    await coordinator.dispose();
  });

  test('failed refresh can retry the same launch ID', () async {
    final mailbox = _MailboxRefresh(failures: 1);
    final coordinator = PushLaunchCoordinator(
      source: _LaunchSource(),
      mailbox: mailbox,
      openChatList: () async {},
    );
    const launch = NotificationLaunch(launchId: 'retry-1', data: validData);

    await expectLater(coordinator.handle(launch), throwsStateError);
    await coordinator.handle(launch);

    expect(mailbox.refreshes, 2);
  });
}

class _LaunchSource implements NotificationLaunchSource {
  _LaunchSource({this.initial});

  final NotificationLaunch? initial;
  final StreamController<NotificationLaunch> _controller =
      StreamController<NotificationLaunch>();

  @override
  Future<NotificationLaunch?> initialLaunch() async => initial;

  @override
  Stream<NotificationLaunch> get launches => _controller.stream;

  void add(NotificationLaunch launch) => _controller.add(launch);
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
