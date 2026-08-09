import 'desktop_link_pairing_request.dart';

enum DesktopLinkPairingState { pending, confirming, confirmed, rejected }

/// 手機端對一次性配對請求的本機處理狀態。
class DesktopLinkPairingRecord {
  const DesktopLinkPairingRecord({
    required this.request,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
  });

  final DesktopLinkPairingRequest request;
  final DesktopLinkPairingState state;
  final int createdAt;
  final int updatedAt;

  bool matches(DesktopLinkPairingRequest other) =>
      request.requestId == other.requestId &&
      request.targetPrimaryDeviceId == other.targetPrimaryDeviceId &&
      request.deviceId == other.deviceId &&
      request.displayName == other.displayName &&
      request.publicKeyFingerprint == other.publicKeyFingerprint &&
      request.issuedAt == other.issuedAt &&
      request.expiresAt == other.expiresAt;
}
