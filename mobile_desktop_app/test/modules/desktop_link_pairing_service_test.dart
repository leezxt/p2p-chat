import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/data/desktop_link_pairing_repository.dart';
import 'package:p2p_chat_app/modules/desktop_link/data/desktop_link_repository.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_exception.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_record.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_request.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('檢閱 QR 不會授權，只有明確 confirm 才建立 Desktop Link', () async {
    final fixture = await _Fixture.open();
    try {
      final request = fixture.request();

      final prepared = await fixture.service.prepareQrPayload(
        request.toQrPayload(),
      );
      expect(
        await fixture.linkRepository.findByDeviceId(request.deviceId),
        isNull,
      );

      final link = await fixture.service.confirm(prepared);
      final record = await fixture.pairingRepository.findByRequestId(
        request.requestId,
      );

      expect(link.deviceId, request.deviceId);
      expect(link.isActive, isTrue);
      expect(record!.state, DesktopLinkPairingState.confirmed);
    } finally {
      await fixture.close();
    }
  });

  test('不同主裝置與過期請求在寫入前就被拒絕', () async {
    final fixture = await _Fixture.open();
    try {
      final otherPhone = DesktopLinkPairingRequest.create(
        requestId: 'request-0000000002',
        targetPrimaryDeviceId: 'another-primary-phone',
        deviceId: 'desktop-windows',
        displayName: 'Windows',
        publicKeyFingerprint: 'desktop-fingerprint-1234',
        issuedAt: 100,
      );
      final expired = DesktopLinkPairingRequest.create(
        requestId: 'request-0000000003',
        targetPrimaryDeviceId: 'primary-phone',
        deviceId: 'desktop-linux',
        displayName: 'Linux',
        publicKeyFingerprint: 'desktop-fingerprint-5678',
        issuedAt: 0,
        lifetimeSeconds: 30,
      );

      await expectLater(
        fixture.service.prepareQrPayload(otherPhone.toQrPayload()),
        throwsA(isA<DesktopLinkPairingWrongPrimaryDevice>()),
      );
      await expectLater(
        fixture.service.prepareQrPayload(expired.toQrPayload()),
        throwsA(isA<DesktopLinkPairingExpired>()),
      );
      expect(
        await fixture.pairingRepository.findByRequestId(otherPhone.requestId),
        isNull,
      );
      expect(
        await fixture.pairingRepository.findByRequestId(expired.requestId),
        isNull,
      );
    } finally {
      await fixture.close();
    }
  });

  test('拒絕後同一個一次性 request 不能再被確認', () async {
    final fixture = await _Fixture.open();
    try {
      final request = fixture.request();
      final prepared = await fixture.service.prepareQrPayload(
        request.toQrPayload(),
      );
      await fixture.service.reject(prepared);

      await expectLater(
        fixture.service.confirm(prepared),
        throwsA(isA<DesktopLinkPairingAlreadyHandled>()),
      );
      final record = await fixture.pairingRepository.findByRequestId(
        request.requestId,
      );
      expect(record!.state, DesktopLinkPairingState.rejected);
      expect(
        await fixture.linkRepository.findByDeviceId(request.deviceId),
        isNull,
      );
    } finally {
      await fixture.close();
    }
  });
}

class _Fixture {
  _Fixture(this.directory, this.database, this._now)
      : linkRepository = DesktopLinkRepository(database.db),
        pairingRepository = DesktopLinkPairingRepository(database.db) {
    linkService = DesktopLinkService(
      repository: linkRepository,
      primaryDeviceId: 'primary-phone',
      eventBus: EventBus(),
      clock: () => _now,
    );
    service = DesktopLinkPairingService(
      repository: pairingRepository,
      desktopLinkService: linkService,
      primaryDeviceId: 'primary-phone',
      clock: () => _now,
    );
  }

  final Directory directory;
  final DatabaseService database;
  final DateTime _now;
  final DesktopLinkRepository linkRepository;
  final DesktopLinkPairingRepository pairingRepository;
  late final DesktopLinkService linkService;
  late final DesktopLinkPairingService service;

  static Future<_Fixture> open() async {
    final directory = await Directory.systemTemp.createTemp('p2p_pairing_');
    final database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
    );
    await database.open(directoryPath: directory.path);
    return _Fixture(
      directory,
      database,
      DateTime.fromMillisecondsSinceEpoch(100 * 1000, isUtc: true),
    );
  }

  DesktopLinkPairingRequest request() => DesktopLinkPairingRequest.create(
        requestId: 'request-0000000001',
        targetPrimaryDeviceId: 'primary-phone',
        deviceId: 'desktop-windows',
        displayName: 'Windows',
        publicKeyFingerprint: 'desktop-fingerprint-1234',
        issuedAt: 100,
      );

  Future<void> close() async {
    await database.close();
    await directory.delete(recursive: true);
  }
}
