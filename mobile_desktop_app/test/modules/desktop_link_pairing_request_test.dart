import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_fingerprint.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_request.dart';

void main() {
  test('版本化 QR pairing payload 可 round-trip 並綁定裝置公開金鑰', () {
    final request = _request();

    final parsed = DesktopLinkPairingRequest.fromQrPayload(
      request.toQrPayload(),
    );

    expect(parsed.requestId, request.requestId);
    expect(parsed.targetPrimaryDeviceId, 'primary-phone');
    expect(parsed.deviceId, 'desktop-windows');
    expect(parsed.publicKey, orderedEquals(_publicKey));
    expect(
      parsed.publicKeyFingerprint,
      computeDeviceKeyFingerprint('desktop-windows', _publicKey),
    );
    expect(parsed.issuedAt, 100);
    expect(parsed.expiresAt, 400);
  });

  test('拒絕少欄位、額外欄位、錯版本、無效 ID 與不相符金鑰 fingerprint', () {
    final request = _request();
    final valid = Map<String, Object?>.from(
      jsonDecode(request.toQrPayload()) as Map,
    );
    final missing = Map<String, Object?>.from(valid)..remove('expiresAt');
    final extra = Map<String, Object?>.from(valid)..['unexpected'] = true;
    final wrongVersion = Map<String, Object?>.from(valid)
      ..['schemaVersion'] = 1;
    final badRequestId = Map<String, Object?>.from(valid)
      ..['requestId'] = 'short';
    final mismatchedFingerprint = Map<String, Object?>.from(valid)
      ..['publicKeyFingerprint'] = 'NOT A MATCH';
    final mismatchedPublicKey = Map<String, Object?>.from(valid)
      ..['publicKey'] = base64UrlEncode(Uint8List(32)..fillRange(0, 32, 99))
          .replaceAll('=', '');

    for (final payload in [
      missing,
      extra,
      wrongVersion,
      badRequestId,
      mismatchedFingerprint,
      mismatchedPublicKey,
    ]) {
      expect(
        () => DesktopLinkPairingRequest.fromQrPayload(jsonEncode(payload)),
        throwsFormatException,
      );
    }
  });

  test('pairing request 壽命必須是 30 到 600 秒', () {
    expect(
      () => DesktopLinkPairingRequest.create(
        requestId: 'request-0000000002',
        targetPrimaryDeviceId: 'primary-phone',
        deviceId: 'desktop-windows',
        displayName: 'Windows',
        publicKey: _publicKey,
        issuedAt: 100,
        lifetimeSeconds: 10,
      ),
      throwsArgumentError,
    );
    expect(
      () => DesktopLinkPairingRequest.create(
        requestId: 'request-0000000003',
        targetPrimaryDeviceId: 'primary-phone',
        deviceId: 'desktop-windows',
        displayName: 'Windows',
        publicKey: _publicKey,
        issuedAt: 100,
        lifetimeSeconds: 601,
      ),
      throwsArgumentError,
    );
  });
}

final Uint8List _publicKey = Uint8List.fromList(
  List<int>.generate(32, (index) => index + 1),
);

DesktopLinkPairingRequest _request() => DesktopLinkPairingRequest.create(
      requestId: 'request-0000000001',
      targetPrimaryDeviceId: 'primary-phone',
      deviceId: 'desktop-windows',
      displayName: 'Windows',
      publicKey: _publicKey,
      issuedAt: 100,
    );
