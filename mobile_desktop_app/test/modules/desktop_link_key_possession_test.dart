import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_material.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_key_possession.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_exception.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_request.dart';

import 'fake_message_box.dart';

void main() {
  test('雙向 authenticated challenge-response 後才驗證桌面端私鑰持有', () {
    final fixture = _Fixture();
    final challenge = fixture.primary.createChallenge(fixture.request);

    expect(
      challenge.toPayload(),
      isNot(contains('challengeToken')),
    );
    expect(fixture.primary.isVerified(fixture.request), isFalse);

    final response = fixture.desktop.respondToChallengePayload(
      challenge.toPayload(),
    );
    fixture.primary.verifyResponsePayload(response.toPayload());

    expect(fixture.primary.isVerified(fixture.request), isTrue);
    fixture.primary.consumeVerified(fixture.request);
    expect(fixture.primary.isVerified(fixture.request), isFalse);
    fixture.dispose();
  });

  test('無有效 proof 時 fail-closed，且 response 不能重放', () {
    final fixture = _Fixture();
    expect(
      () => fixture.primary.requireVerified(fixture.request),
      throwsA(isA<DesktopLinkPairingProofRequired>()),
    );

    final challenge = fixture.primary.createChallenge(fixture.request);
    final response = fixture.desktop.respondToChallengePayload(
      challenge.toPayload(),
    );
    fixture.primary.verifyResponsePayload(response.toPayload());
    expect(
      () => fixture.primary.verifyResponsePayload(response.toPayload()),
      throwsA(isA<DesktopLinkPairingProofNotIssued>()),
    );
    fixture.dispose();
  });

  test('竄改 response 或使用錯誤桌面 key 都不能通過 proof', () {
    final fixture = _Fixture();
    final challenge = fixture.primary.createChallenge(fixture.request);
    final response = fixture.desktop.respondToChallengePayload(
      challenge.toPayload(),
    );
    final tampered = Map<String, Object?>.from(
      jsonDecode(response.toPayload()) as Map,
    );
    final ciphertext = base64Url.decode(
      base64Url.normalize(tampered['ciphertext']! as String),
    );
    ciphertext[0] ^= 1;
    tampered['ciphertext'] = base64UrlEncode(ciphertext).replaceAll('=', '');

    expect(
      () => fixture.primary.verifyResponsePayload(jsonEncode(tampered)),
      throwsA(isA<DesktopLinkPairingProofInvalid>()),
    );
    expect(fixture.primary.isVerified(fixture.request), isFalse);

    final anotherChallenge = fixture.primary.createChallenge(fixture.request);
    final wrongResponder = DesktopLinkKeyPossessionResponder(
      box: fixture.box,
      desktopKey: fixture.wrongDesktopKey,
      desktopDeviceId: fixture.request.deviceId,
      clock: () => fixture.now,
    );
    expect(
      () => wrongResponder
          .respondToChallengePayload(anotherChallenge.toPayload()),
      throwsA(isA<DesktopLinkPairingProofInvalid>()),
    );
    fixture.dispose();
  });

  test('過期 challenge 會被拒絕，且 request 內容不可被替換後沿用 proof', () {
    final fixture = _Fixture();
    final challenge = fixture.primary.createChallenge(fixture.request);
    final response = fixture.desktop.respondToChallengePayload(
      challenge.toPayload(),
    );
    fixture.advanceTo(401);
    expect(
      () => fixture.primary.verifyResponsePayload(response.toPayload()),
      throwsA(isA<DesktopLinkPairingProofExpired>()),
    );

    fixture.advanceTo(100);
    final freshChallenge = fixture.primary.createChallenge(fixture.request);
    final freshResponse = fixture.desktop.respondToChallengePayload(
      freshChallenge.toPayload(),
    );
    fixture.primary.verifyResponsePayload(freshResponse.toPayload());
    final replacement = DesktopLinkPairingRequest.create(
      requestId: fixture.request.requestId,
      targetPrimaryDeviceId: fixture.request.targetPrimaryDeviceId,
      deviceId: fixture.request.deviceId,
      displayName: fixture.request.displayName,
      publicKey: fixture.replacementDesktopPublicKey,
      issuedAt: fixture.request.issuedAt,
    );
    expect(fixture.primary.isVerified(replacement), isFalse);
    fixture.dispose();
  });
}

class _Fixture {
  _Fixture()
      : primarySecret = TestSecureKey(_bytes(40)),
        desktopSecret = TestSecureKey(_bytes(80)),
        wrongDesktopSecret = TestSecureKey(_bytes(120)),
        primaryPublicKey = _bytes(1),
        desktopPublicKey = _bytes(161),
        replacementDesktopPublicKey = _bytes(201),
        wrongDesktopPublicKey = _bytes(231) {
    box
      ..registerKey(publicKey: primaryPublicKey, secretKey: primarySecret)
      ..registerKey(publicKey: desktopPublicKey, secretKey: desktopSecret)
      ..registerKey(
        publicKey: wrongDesktopPublicKey,
        secretKey: wrongDesktopSecret,
      );
    primaryKey = testDeviceKey(
      deviceId: 'primary-phone',
      publicKey: primaryPublicKey,
      secretKey: primarySecret,
    );
    desktopKey = testDeviceKey(
      deviceId: 'desktop-windows',
      publicKey: desktopPublicKey,
      secretKey: desktopSecret,
    );
    wrongDesktopKey = testDeviceKey(
      deviceId: 'desktop-windows',
      publicKey: wrongDesktopPublicKey,
      secretKey: wrongDesktopSecret,
    );
    request = DesktopLinkPairingRequest.create(
      requestId: 'request-0000000001',
      targetPrimaryDeviceId: 'primary-phone',
      deviceId: 'desktop-windows',
      displayName: 'Windows',
      publicKey: desktopPublicKey,
      issuedAt: 100,
    );
    primary = DesktopLinkKeyPossessionService(
      box: box,
      primaryKey: primaryKey,
      primaryDeviceId: 'primary-phone',
      clock: () => now,
      challengeIdGenerator: () => 'challenge-0000000001',
    );
    desktop = DesktopLinkKeyPossessionResponder(
      box: box,
      desktopKey: desktopKey,
      desktopDeviceId: 'desktop-windows',
      clock: () => now,
    );
  }

  final TestMessageBox box = TestMessageBox();
  final TestSecureKey primarySecret;
  final TestSecureKey desktopSecret;
  final TestSecureKey wrongDesktopSecret;
  final Uint8List primaryPublicKey;
  final Uint8List desktopPublicKey;
  final Uint8List replacementDesktopPublicKey;
  final Uint8List wrongDesktopPublicKey;
  late final DeviceKeyMaterial primaryKey;
  late final DeviceKeyMaterial desktopKey;
  late final DeviceKeyMaterial wrongDesktopKey;
  late final DesktopLinkPairingRequest request;
  late final DesktopLinkKeyPossessionService primary;
  late final DesktopLinkKeyPossessionResponder desktop;
  DateTime now = DateTime.fromMillisecondsSinceEpoch(100 * 1000, isUtc: true);

  void advanceTo(int epochSeconds) {
    now = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000, isUtc: true);
  }

  void dispose() {
    primary.dispose();
    primaryKey.dispose();
    desktopKey.dispose();
    wrongDesktopKey.dispose();
  }
}

Uint8List _bytes(int start) => Uint8List.fromList(
      List<int>.generate(32, (index) => (start + index) & 0xff),
    );
