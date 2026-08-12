import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_material.dart';
import 'package:p2p_chat_app/modules/desktop_link/data/desktop_link_pairing_repository.dart';
import 'package:p2p_chat_app/modules/desktop_link/data/desktop_link_repository.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_exception.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_key_possession.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_record.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_request.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_message_box.dart';

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

      await fixture.prove(prepared);
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

  test('未完成桌面私鑰 proof 時不能 confirm，但 request 保持可重試', () async {
    final fixture = await _Fixture.open();
    try {
      final request = fixture.request();
      final prepared = await fixture.service.prepareQrPayload(
        request.toQrPayload(),
      );

      await expectLater(
        fixture.service.confirm(prepared),
        throwsA(isA<DesktopLinkPairingProofRequired>()),
      );
      final record = await fixture.pairingRepository.findByRequestId(
        request.requestId,
      );
      expect(record!.state, DesktopLinkPairingState.pending);
      expect(await fixture.linkRepository.findByDeviceId(request.deviceId),
          isNull);
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
        publicKey: _desktopPublicKey,
        issuedAt: 100,
      );
      final expired = DesktopLinkPairingRequest.create(
        requestId: 'request-0000000003',
        targetPrimaryDeviceId: 'primary-phone',
        deviceId: 'desktop-linux',
        displayName: 'Linux',
        publicKey: _desktopPublicKey,
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
    box = TestMessageBox();
    primarySecret = TestSecureKey(_bytes(80));
    desktopSecret = TestSecureKey(_bytes(120));
    box
      ..registerKey(publicKey: _primaryPublicKey, secretKey: primarySecret)
      ..registerKey(publicKey: _desktopPublicKey, secretKey: desktopSecret);
    primaryKey = testDeviceKey(
      deviceId: 'primary-phone',
      publicKey: _primaryPublicKey,
      secretKey: primarySecret,
    );
    desktopKey = testDeviceKey(
      deviceId: 'desktop-windows',
      publicKey: _desktopPublicKey,
      secretKey: desktopSecret,
    );
    linkService = DesktopLinkService(
      repository: linkRepository,
      primaryDeviceId: 'primary-phone',
      eventBus: EventBus(),
      clock: () => _now,
    );
    keyPossession = DesktopLinkKeyPossessionService(
      box: box,
      primaryKey: primaryKey,
      primaryDeviceId: 'primary-phone',
      clock: () => _now,
      challengeIdGenerator: () => 'challenge-0000000001',
    );
    responder = DesktopLinkKeyPossessionResponder(
      box: box,
      desktopKey: desktopKey,
      desktopDeviceId: 'desktop-windows',
      clock: () => _now,
    );
    service = DesktopLinkPairingService(
      repository: pairingRepository,
      desktopLinkService: linkService,
      keyPossessionService: keyPossession,
      primaryDeviceId: 'primary-phone',
      clock: () => _now,
    );
  }

  final Directory directory;
  final DatabaseService database;
  final DateTime _now;
  final DesktopLinkRepository linkRepository;
  final DesktopLinkPairingRepository pairingRepository;
  late final TestMessageBox box;
  late final TestSecureKey primarySecret;
  late final TestSecureKey desktopSecret;
  late final DeviceKeyMaterial primaryKey;
  late final DeviceKeyMaterial desktopKey;
  late final DesktopLinkService linkService;
  late final DesktopLinkKeyPossessionService keyPossession;
  late final DesktopLinkKeyPossessionResponder responder;
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
        publicKey: _desktopPublicKey,
        issuedAt: 100,
      );

  Future<void> prove(DesktopLinkPairingRequest request) async {
    final challenge = await service.createKeyPossessionChallenge(request);
    final response = responder.respondToChallengePayload(challenge.toPayload());
    await service.verifyKeyPossessionResponse(response.toPayload());
  }

  Future<void> close() async {
    keyPossession.dispose();
    primaryKey.dispose();
    desktopKey.dispose();
    await database.close();
    await directory.delete(recursive: true);
  }
}

final Uint8List _desktopPublicKey = Uint8List.fromList(
  List<int>.generate(32, (index) => index + 1),
);

final Uint8List _primaryPublicKey = Uint8List.fromList(
  List<int>.generate(32, (index) => index + 101),
);

Uint8List _bytes(int seed) => Uint8List.fromList(
      List<int>.generate(32, (index) => (seed + index) & 0xff),
    );
