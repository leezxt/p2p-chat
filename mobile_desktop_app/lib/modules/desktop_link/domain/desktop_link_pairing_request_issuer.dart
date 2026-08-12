import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'desktop_link_pairing_request.dart';

/// 桌面副端建立 canonical pairing request 的純 domain helper。
///
/// 它只使用副端的公開 X25519 金鑰，因此不讀取、不輸出也不保存私鑰。產生的 QR 請求
/// 能讓手機端重新計算 fingerprint，排除 QR 任意聲稱一個不相符 fingerprint 的情況；
/// 私鑰持有證明仍必須由後續 challenge-response 完成。
class DesktopLinkPairingRequestIssuer {
  DesktopLinkPairingRequestIssuer({
    required this.deviceId,
    required Uint8List publicKey,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _publicKey = Uint8List.fromList(publicKey),
        _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final String deviceId;
  final Uint8List _publicKey;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// 產生只可使用一次的短效 request；V3-05 的 Desktop Companion 畫面會把它呈現為 QR。
  /// 這個 helper 本身仍不建立連線或交付 payload。
  DesktopLinkPairingRequest issue({
    required String targetPrimaryDeviceId,
    required String displayName,
    int lifetimeSeconds = DesktopLinkPairingRequest.defaultLifetimeSeconds,
  }) {
    return DesktopLinkPairingRequest.create(
      requestId: _uuid.v4(),
      targetPrimaryDeviceId: targetPrimaryDeviceId,
      deviceId: deviceId,
      displayName: displayName,
      publicKey: _publicKey,
      issuedAt: _clock().millisecondsSinceEpoch ~/ 1000,
      lifetimeSeconds: lifetimeSeconds,
    );
  }
}
