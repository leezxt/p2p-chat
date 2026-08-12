/// 由手機主裝置授權的桌面副端。
///
/// [authorizedAfter] 是保守的同步切點：只有 `createdAt` 嚴格大於此值的
/// `MessageEnvelope` 才可被後續同步 adapter 選出。由於現有訊息時間只有秒級，
/// 同一秒的訊息會被拒絕，避免把配對前資料誤判為新資料。
class DesktopLink {
  const DesktopLink({
    required this.deviceId,
    required this.displayName,
    required this.publicKeyFingerprint,
    required this.authorizedAfter,
    this.revokedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String deviceId;
  final String displayName;
  final String publicKeyFingerprint;

  /// Unix epoch 秒；只同步此時間之後建立的新訊息。
  final int authorizedAfter;
  final int? revokedAt;
  final int createdAt;
  final int updatedAt;

  bool get isActive => revokedAt == null;
}
