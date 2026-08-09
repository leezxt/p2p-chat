import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_fingerprint.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_request_issuer.dart';

void main() {
  test('issuer 以本機裝置公開金鑰建立短效 canonical pairing request', () {
    final publicKey = Uint8List.fromList(
      List<int>.generate(32, (index) => index + 1),
    );
    final issuer = DesktopLinkPairingRequestIssuer(
      deviceId: 'desktop-windows',
      publicKey: publicKey,
      clock: () => DateTime.fromMillisecondsSinceEpoch(100 * 1000, isUtc: true),
    );

    final request = issuer.issue(
      targetPrimaryDeviceId: 'primary-phone',
      displayName: 'Windows desktop',
    );

    expect(request.requestId, matches(RegExp(r'^[A-Za-z0-9_-]{16,128}$')));
    expect(request.targetPrimaryDeviceId, 'primary-phone');
    expect(request.deviceId, 'desktop-windows');
    expect(request.publicKey, orderedEquals(publicKey));
    expect(
      request.publicKeyFingerprint,
      computeDeviceKeyFingerprint('desktop-windows', publicKey),
    );
    expect(request.issuedAt, 100);
    expect(request.expiresAt, 400);
  });

  test('issuer defensive-copies caller public key and each request ID is fresh',
      () {
    final publicKey = Uint8List.fromList(
      List<int>.generate(32, (index) => index + 1),
    );
    final issuer = DesktopLinkPairingRequestIssuer(
      deviceId: 'desktop-windows',
      publicKey: publicKey,
      clock: () => DateTime.fromMillisecondsSinceEpoch(100 * 1000, isUtc: true),
    );
    publicKey.fillRange(0, publicKey.length, 0);

    final first = issuer.issue(
      targetPrimaryDeviceId: 'primary-phone',
      displayName: 'Windows desktop',
    );
    final second = issuer.issue(
      targetPrimaryDeviceId: 'primary-phone',
      displayName: 'Windows desktop',
    );

    expect(first.publicKey, isNot(orderedEquals(publicKey)));
    expect(second.requestId, isNot(first.requestId));
  });
}
