/// QR 配對請求的安全邊界錯誤。
///
/// 例外文字刻意不回傳 QR 原文、fingerprint 或裝置資料，避免不可信輸入進入日誌。
abstract class DesktopLinkPairingException implements Exception {
  const DesktopLinkPairingException(this.message);

  final String message;

  @override
  String toString() => 'DesktopLinkPairingException: $message';
}

class DesktopLinkPairingInvalidPayload extends DesktopLinkPairingException {
  const DesktopLinkPairingInvalidPayload()
      : super('Desktop Link pairing payload is invalid');
}

class DesktopLinkPairingExpired extends DesktopLinkPairingException {
  const DesktopLinkPairingExpired()
      : super('Desktop Link pairing request has expired');
}

class DesktopLinkPairingWrongPrimaryDevice extends DesktopLinkPairingException {
  const DesktopLinkPairingWrongPrimaryDevice()
      : super('Desktop Link pairing request targets another primary device');
}

class DesktopLinkPairingAlreadyHandled extends DesktopLinkPairingException {
  const DesktopLinkPairingAlreadyHandled()
      : super('Desktop Link pairing request was already handled');
}

class DesktopLinkPairingInProgress extends DesktopLinkPairingException {
  const DesktopLinkPairingInProgress()
      : super('Desktop Link pairing request is already being confirmed');
}

class DesktopLinkPairingNotPrepared extends DesktopLinkPairingException {
  const DesktopLinkPairingNotPrepared()
      : super('Desktop Link pairing request was not prepared locally');
}

class DesktopLinkPairingRequestIdCollision extends DesktopLinkPairingException {
  const DesktopLinkPairingRequestIdCollision()
      : super('Desktop Link pairing request ID conflicts with existing data');
}

/// challenge-response 尚未完成時不得建立 Desktop Link，避免把 QR 公鑰 binding
/// 誤當成桌面端已持有對應私鑰。
class DesktopLinkPairingProofRequired extends DesktopLinkPairingException {
  const DesktopLinkPairingProofRequired()
      : super('Desktop Link private-key possession proof is required');
}

class DesktopLinkPairingProofNotIssued extends DesktopLinkPairingException {
  const DesktopLinkPairingProofNotIssued()
      : super('Desktop Link key possession challenge was not issued locally');
}

class DesktopLinkPairingProofExpired extends DesktopLinkPairingException {
  const DesktopLinkPairingProofExpired()
      : super('Desktop Link key possession challenge has expired');
}

class DesktopLinkPairingProofInvalid extends DesktopLinkPairingException {
  const DesktopLinkPairingProofInvalid()
      : super('Desktop Link key possession proof is invalid');
}

class DesktopLinkPairingProofCryptographicFailure
    extends DesktopLinkPairingException {
  const DesktopLinkPairingProofCryptographicFailure()
      : super('Desktop Link key possession cryptographic operation failed');
}
