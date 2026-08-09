import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_request.dart';

void main() {
  test('版本化 QR pairing payload 可 round-trip 並保留目標主裝置', () {
    final request = _request();

    final parsed = DesktopLinkPairingRequest.fromQrPayload(
      request.toQrPayload(),
    );

    expect(parsed.requestId, request.requestId);
    expect(parsed.targetPrimaryDeviceId, 'primary-phone');
    expect(parsed.deviceId, 'desktop-windows');
    expect(parsed.publicKeyFingerprint, 'desktop-fingerprint-1234');
    expect(parsed.issuedAt, 100);
    expect(parsed.expiresAt, 400);
  });

  test('拒絕少欄位、額外欄位、錯版本與無效 request ID', () {
    final request = _request();
    final valid = Map<String, Object?>.from(
      jsonDecode(request.toQrPayload()) as Map,
    );
    final missing = Map<String, Object?>.from(valid)..remove('expiresAt');
    final extra = Map<String, Object?>.from(valid)..['unexpected'] = true;
    final wrongVersion = Map<String, Object?>.from(valid)
      ..['schemaVersion'] = 2;
    final badRequestId = Map<String, Object?>.from(valid)
      ..['requestId'] = 'short';

    for (final payload in [missing, extra, wrongVersion, badRequestId]) {
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
        publicKeyFingerprint: 'desktop-fingerprint-1234',
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
        publicKeyFingerprint: 'desktop-fingerprint-1234',
        issuedAt: 100,
        lifetimeSeconds: 601,
      ),
      throwsArgumentError,
    );
  });
}

DesktopLinkPairingRequest _request() => DesktopLinkPairingRequest.create(
      requestId: 'request-0000000001',
      targetPrimaryDeviceId: 'primary-phone',
      deviceId: 'desktop-windows',
      displayName: 'Windows',
      publicKeyFingerprint: 'desktop-fingerprint-1234',
      issuedAt: 100,
    );
