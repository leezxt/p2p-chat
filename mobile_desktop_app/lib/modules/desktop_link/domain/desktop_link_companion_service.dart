import 'package:uuid/uuid.dart';

import '../../crypto/domain/device_key_material.dart';
import '../../crypto/domain/message_box.dart';
import 'desktop_link_key_possession.dart';
import 'desktop_link_pairing_exception.dart';
import 'desktop_link_pairing_request.dart';
import 'desktop_link_pairing_request_issuer.dart';

/// Desktop Companion 畫面需要的最小動作。
///
/// 這個介面刻意不含連線、訊息選取或同步 API；桌面端在 V3-05 只能產生短效 QR request，
/// 並回覆手機端手動交付的 encrypted challenge。
abstract interface class DesktopLinkCompanionActions {
  DesktopLinkPairingRequest issuePairingRequest({
    required String targetPrimaryDeviceId,
    required String displayName,
  });

  DesktopLinkKeyPossessionResponse respondToChallengePayload(
    String rawPayload,
  );
}

/// 將目前 desktop installation 的裝置金鑰接到 pairing presentation。
///
/// [DeviceKeyMaterial] 的生命週期仍由 Crypto Module 管理；此 service 不複製或輸出私鑰，
/// 不保存 challenge token，也不建立任何 transport。手機端最終是否授權仍完全由
/// [DesktopLinkPairingService] 的明確確認與 proof gate 決定。
class DesktopLinkCompanionService implements DesktopLinkCompanionActions {
  DesktopLinkCompanionService({
    required MessageBox box,
    required DeviceKeyMaterial desktopKey,
    required String desktopDeviceId,
    DateTime Function()? clock,
    Uuid? uuid,
  })  : _issuer = DesktopLinkPairingRequestIssuer(
          deviceId: desktopDeviceId,
          publicKey: desktopKey.publicKey,
          clock: clock,
          uuid: uuid,
        ),
        _responder = DesktopLinkKeyPossessionResponder(
          box: box,
          desktopKey: desktopKey,
          desktopDeviceId: desktopDeviceId,
          clock: clock,
        );

  final DesktopLinkPairingRequestIssuer _issuer;
  final DesktopLinkKeyPossessionResponder _responder;

  @override
  DesktopLinkPairingRequest issuePairingRequest({
    required String targetPrimaryDeviceId,
    required String displayName,
  }) {
    try {
      return _issuer.issue(
        targetPrimaryDeviceId: targetPrimaryDeviceId,
        displayName: displayName,
      );
    } on ArgumentError {
      // 手動輸入是信任邊界；不將原始 device ID 或名稱帶進例外／log。
      throw const DesktopLinkPairingInvalidPayload();
    }
  }

  @override
  DesktopLinkKeyPossessionResponse respondToChallengePayload(
    String rawPayload,
  ) =>
      _responder.respondToChallengePayload(rawPayload);
}
