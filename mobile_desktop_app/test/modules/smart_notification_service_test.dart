import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/push/domain/notification_presentation_policy.dart';
import 'package:p2p_chat_app/modules/smart_notification/data/sqlite_notification_preference_repository.dart';
import 'package:p2p_chat_app/modules/smart_notification/domain/notification_preference.dart';
import 'package:p2p_chat_app/modules/smart_notification/domain/smart_notification_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('靜音聊天室不會產生通知', () async {
    final fixture = await _Fixture.open();
    try {
      final service = fixture.service();
      await service.savePreference(const NotificationPreference(
        conversationId: 'chat-1',
        muted: true,
      ));

      final result = await service.resolve(
        conversationId: 'chat-1',
        genericTitle: 'New message',
        genericBody: 'Open the app',
        localSenderName: 'Alice',
        localMessagePreview: 'secret',
      );

      expect(result, isNull);
    } finally {
      await fixture.close();
    }
  });

  test('聊天室未明確允許時，通知只顯示通用文字', () async {
    final fixture = await _Fixture.open();
    try {
      final service = fixture.service(
        appLockEnabled: false,
        appLocked: false,
        hideContent: false,
      );

      final result = await service.resolve(
        conversationId: 'chat-2',
        genericTitle: 'New message',
        genericBody: 'Open the app',
        localSenderName: 'Alice',
        localMessagePreview: 'secret',
      );

      expect(result!.redacted, isTrue);
      expect(result.title, 'New message');
    } finally {
      await fixture.close();
    }
  });

  test('App Lock 仍可遮蔽已允許的聊天室預覽', () async {
    final fixture = await _Fixture.open();
    try {
      final service = fixture.service(
        appLockEnabled: true,
        appLocked: true,
        hideContent: false,
      );
      await service.savePreference(const NotificationPreference(
        conversationId: 'chat-3',
        allowPreview: true,
      ));

      final result = await service.resolve(
        conversationId: 'chat-3',
        genericTitle: 'New message',
        genericBody: 'Open the app',
        localSenderName: 'Alice',
        localMessagePreview: 'secret',
      );

      expect(result!.redacted, isTrue);
      expect(result.body, 'Open the app');
    } finally {
      await fixture.close();
    }
  });
}

class _Fixture {
  _Fixture(this.directory, this.database);

  final Directory directory;
  final DatabaseService database;

  static Future<_Fixture> open() async {
    final directory =
        await Directory.systemTemp.createTemp('p2p_notification_');
    final database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
    );
    await database.open(directoryPath: directory.path);
    return _Fixture(directory, database);
  }

  SmartNotificationService service({
    bool appLockEnabled = false,
    bool appLocked = false,
    bool hideContent = false,
  }) {
    final policy = NotificationPresentationPolicy()
      ..updateAppLockState(
        enabled: appLockEnabled,
        locked: appLocked,
        hideNotificationContent: hideContent,
      );
    return SmartNotificationService(
      preferences: SqliteNotificationPreferenceRepository(database.db),
      presentationPolicy: policy,
    );
  }

  Future<void> close() async {
    await database.close();
    await directory.delete(recursive: true);
  }
}
