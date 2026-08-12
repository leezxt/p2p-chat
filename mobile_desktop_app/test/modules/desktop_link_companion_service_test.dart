import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_material.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_companion_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_exception.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_request.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_key_possession.dart';

import 'fake_message_box.dart';

void main() {
  test('Desktop Companion 以本機公開金鑰發出 QR，並回覆手機 challenge', () {
    final fixture = _Fixture();
    final request = fixture.companion.issuePairingRequest(
      targetPrimaryDeviceId: 'primary-phone',
      displayName: 'Windows desktop',
    );

    expect(request.targetPrimaryDeviceId, 'primary-phone');
    expect(request.deviceId, 'desktop-windows');
    expect(request.displayName, 'Windows desktop');
    expect(request.publicKey, orderedEquals(fixture.desktopPublicKey));

    final challenge = fixture.primary.createChallenge(request);
    final response = fixture.companion.respondToChallengePayload(
      challenge.toPayload(),
    );
    fixture.primary.verifyResponsePayload(response.toPayload());

    expect(fixture.primary.isVerified(request), isTrue);
    fixture.dispose();
  });

  test('Desktop Companion 對無效手動輸入與非本機 challenge fail-closed', () {
    final fixture = _Fixture();
    expect(
      () => fixture.companion.issuePairingRequest(
        targetPrimaryDeviceId: ' ',
        displayName: 'Windows desktop',
      ),
      throwsA(isA<DesktopLinkPairingInvalidPayload>()),
    );

    final otherPublicKey = _bytes(190);
    final otherSecret = TestSecureKey(_bytes(220));
    fixture.box.registerKey(publicKey: otherPublicKey, secretKey: otherSecret);
    final otherRequest = DesktopLinkPairingRequest.create(
      requestId: 'request-0000000002',
      targetPrimaryDeviceId: 'primary-phone',
      deviceId: 'another-desktop',
      displayName: 'Another desktop',
      publicKey: otherPublicKey,
      issuedAt: 100,
    );
    final challenge = fixture.primary.createChallenge(otherRequest);

    expect(
      () => fixture.companion.respondToChallengePayload(challenge.toPayload()),
      throwsA(isA<DesktopLinkPairingProofInvalid>()),
    );
    fixture.dispose();
    otherSecret.dispose();
  });
}

class _Fixture {
  _Fixture()
      : primarySecret = TestSecureKey(_bytes(40)),
        desktopSecret = TestSecureKey(_bytes(80)),
        primaryPublicKey = _bytes(1),
        desktopPublicKey = _bytes(120) {
    box
      ..registerKey(publicKey: primaryPublicKey, secretKey: primarySecret)
      ..registerKey(publicKey: desktopPublicKey, secretKey: desktopSecret);
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
    primary = DesktopLinkKeyPossessionService(
      box: box,
      primaryKey: primaryKey,
      primaryDeviceId: 'primary-phone',
      clock: () => now,
      challengeIdGenerator: () => 'challenge-0000000001',
    );
    companion = DesktopLinkCompanionService(
      box: box,
      desktopKey: desktopKey,
      desktopDeviceId: 'desktop-windows',
      clock: () => now,
    );
  }

  final TestMessageBox box = TestMessageBox();
  final TestSecureKey primarySecret;
  final TestSecureKey desktopSecret;
  final Uint8List primaryPublicKey;
  final Uint8List desktopPublicKey;
  late final DeviceKeyMaterial primaryKey;
  late final DeviceKeyMaterial desktopKey;
  late final DesktopLinkKeyPossessionService primary;
  late final DesktopLinkCompanionService companion;
  final DateTime now =
      DateTime.fromMillisecondsSinceEpoch(100 * 1000, isUtc: true);

  void dispose() {
    primary.dispose();
    primaryKey.dispose();
    desktopKey.dispose();
  }
}

Uint8List _bytes(int start) => Uint8List.fromList(
      List<int>.generate(32, (index) => (start + index) & 0xff),
    );
