import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/data/desktop_link_repository.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/events/desktop_link_changed.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('主裝置授權後只選出嚴格晚於同步切點的新訊息', () async {
    final fixture = await _Fixture.open();
    try {
      final events = <DesktopLinkChanged>[];
      fixture.eventBus.on<DesktopLinkChanged>(events.add);

      final link = await fixture.service.authorize(
        deviceId: 'desktop-1',
        displayName: 'Lee Windows',
        publicKeyFingerprint: 'desktop-fingerprint-1',
      );
      final selected = await fixture.service.selectNewMessages(
        deviceId: link.deviceId,
        candidates: [
          _message('old', 99),
          _message('same-second', 100),
          _message('new', 101)
        ],
      );

      expect(link.authorizedAfter, 100);
      expect(selected.map((message) => message.messageId), ['new']);
      expect(events, hasLength(1));
      expect(events.single.kind, DesktopLinkChangeKind.authorized);
    } finally {
      await fixture.close();
    }
  });

  test('撤銷後 fail-closed，不能再選取任何新訊息', () async {
    final fixture = await _Fixture.open();
    try {
      await fixture.service.authorize(
        deviceId: 'desktop-2',
        displayName: 'Lee Mac',
        publicKeyFingerprint: 'desktop-fingerprint-2',
      );
      fixture.setEpochSeconds(200);
      final revoked = await fixture.service.revoke('desktop-2');

      expect(revoked.isActive, isFalse);
      expect(
        await fixture.service.canSyncMessage(
          deviceId: 'desktop-2',
          message: _message('after-revoke', 201),
        ),
        isFalse,
      );
      await expectLater(
        fixture.service.selectNewMessages(
          deviceId: 'desktop-2',
          candidates: [_message('after-revoke', 201)],
        ),
        throwsA(isA<DesktopLinkRevoked>()),
      );
    } finally {
      await fixture.close();
    }
  });

  test('撤銷後必須明確重新授權，且取得新的同步切點', () async {
    final fixture = await _Fixture.open();
    try {
      await fixture.service.authorize(
        deviceId: 'desktop-3',
        displayName: 'Lee Linux',
        publicKeyFingerprint: 'desktop-fingerprint-3',
      );
      fixture.setEpochSeconds(200);
      await fixture.service.revoke('desktop-3');
      fixture.setEpochSeconds(300);
      final relinked = await fixture.service.authorize(
        deviceId: 'desktop-3',
        displayName: 'Lee Linux',
        publicKeyFingerprint: 'desktop-fingerprint-3',
      );
      final selected = await fixture.service.selectNewMessages(
        deviceId: 'desktop-3',
        candidates: [
          _message('before-relink', 250),
          _message('same-second', 300),
          _message('new', 301)
        ],
      );

      expect(relinked.authorizedAfter, 300);
      expect(relinked.isActive, isTrue);
      expect(selected.map((message) => message.messageId), ['new']);
    } finally {
      await fixture.close();
    }
  });

  test('不能把手機主裝置或 fingerprint 已變更的裝置靜默授權', () async {
    final fixture = await _Fixture.open();
    try {
      await expectLater(
        fixture.service.authorize(
          deviceId: 'primary-phone',
          displayName: 'Primary phone',
          publicKeyFingerprint: 'primary-fingerprint',
        ),
        throwsA(isA<DesktopLinkPrimaryDeviceRejected>()),
      );

      await fixture.service.authorize(
        deviceId: 'desktop-4',
        displayName: 'Lee Windows',
        publicKeyFingerprint: 'desktop-fingerprint-4',
      );
      await expectLater(
        fixture.service.authorize(
          deviceId: 'desktop-4',
          displayName: 'Lee Windows',
          publicKeyFingerprint: 'unexpected-new-fingerprint',
        ),
        throwsA(isA<DesktopLinkFingerprintMismatch>()),
      );
    } finally {
      await fixture.close();
    }
  });
}

MessageEnvelope _message(String id, int createdAt) => MessageEnvelope(
      messageId: id,
      conversationId: 'conversation-1',
      senderUserId: 'user-1',
      senderDeviceId: 'phone-1',
      type: MessageType.text,
      payload: {'text': id},
      createdAt: createdAt,
    );

class _Fixture {
  _Fixture(this.directory, this.database, this.eventBus, this._now);

  final Directory directory;
  final DatabaseService database;
  final EventBus eventBus;
  DateTime _now;

  late final DesktopLinkService service = DesktopLinkService(
    repository: DesktopLinkRepository(database.db),
    primaryDeviceId: 'primary-phone',
    eventBus: eventBus,
    clock: () => _now,
  );

  static Future<_Fixture> open() async {
    final directory =
        await Directory.systemTemp.createTemp('p2p_desktop_link_');
    final database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
    );
    await database.open(directoryPath: directory.path);
    return _Fixture(
      directory,
      database,
      EventBus(),
      DateTime.fromMillisecondsSinceEpoch(100 * 1000, isUtc: true),
    );
  }

  void setEpochSeconds(int seconds) {
    _now = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  Future<void> close() async {
    await database.close();
    await directory.delete(recursive: true);
  }
}
