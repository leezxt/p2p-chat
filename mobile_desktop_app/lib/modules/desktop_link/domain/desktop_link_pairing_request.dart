import 'dart:convert';

/// 可由桌面端顯示為 QR Code 的短效、一次性配對請求。
///
/// 此 payload 只是一個待確認的公開宣告，不是簽章挑戰，也不能單獨證明桌面端
/// 持有對應私鑰。手機端必須先驗證目標主裝置、期限與 request ID，並在使用者明確
/// 確認後才建立 Desktop Link；真正 key possession proof 留待後續 V3 protocol。
class DesktopLinkPairingRequest {
  const DesktopLinkPairingRequest._({
    required this.requestId,
    required this.targetPrimaryDeviceId,
    required this.deviceId,
    required this.displayName,
    required this.publicKeyFingerprint,
    required this.issuedAt,
    required this.expiresAt,
  });

  static const schemaVersion = 1;
  static const payloadType = 'desktop_link_pairing_request';
  static const defaultLifetimeSeconds = 300;
  static const minLifetimeSeconds = 30;
  static const maxLifetimeSeconds = 600;
  static const _maxPayloadLength = 4096;
  static final _requestIdPattern = RegExp(r'^[A-Za-z0-9_-]{16,128}$');
  static const _requiredKeys = {
    'schemaVersion',
    'type',
    'requestId',
    'targetPrimaryDeviceId',
    'deviceId',
    'displayName',
    'publicKeyFingerprint',
    'issuedAt',
    'expiresAt',
  };

  factory DesktopLinkPairingRequest.create({
    required String requestId,
    required String targetPrimaryDeviceId,
    required String deviceId,
    required String displayName,
    required String publicKeyFingerprint,
    required int issuedAt,
    int lifetimeSeconds = defaultLifetimeSeconds,
  }) {
    if (lifetimeSeconds < minLifetimeSeconds ||
        lifetimeSeconds > maxLifetimeSeconds) {
      throw ArgumentError.value(
        lifetimeSeconds,
        'lifetimeSeconds',
        'must be between $minLifetimeSeconds and $maxLifetimeSeconds',
      );
    }
    return _validated(
      requestId: requestId,
      targetPrimaryDeviceId: targetPrimaryDeviceId,
      deviceId: deviceId,
      displayName: displayName,
      publicKeyFingerprint: publicKeyFingerprint,
      issuedAt: issuedAt,
      expiresAt: issuedAt + lifetimeSeconds,
    );
  }

  factory DesktopLinkPairingRequest.fromQrPayload(String rawPayload) {
    if (rawPayload.trim().isEmpty || rawPayload.length > _maxPayloadLength) {
      throw const FormatException('Invalid Desktop Link pairing payload');
    }
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) _invalidPayload();
      final payload = Map<String, Object?>.from(decoded);
      final keys = payload.keys.toSet();
      if (keys.length != _requiredKeys.length ||
          !keys.containsAll(_requiredKeys) ||
          payload['schemaVersion'] != schemaVersion ||
          payload['type'] != payloadType) {
        _invalidPayload();
      }
      return _validated(
        requestId: _readString(payload, 'requestId'),
        targetPrimaryDeviceId: _readString(payload, 'targetPrimaryDeviceId'),
        deviceId: _readString(payload, 'deviceId'),
        displayName: _readString(payload, 'displayName'),
        publicKeyFingerprint: _readString(payload, 'publicKeyFingerprint'),
        issuedAt: _readInt(payload, 'issuedAt'),
        expiresAt: _readInt(payload, 'expiresAt'),
      );
    } on FormatException {
      rethrow;
    } on ArgumentError {
      throw const FormatException('Invalid Desktop Link pairing payload');
    }
  }

  final String requestId;
  final String targetPrimaryDeviceId;
  final String deviceId;
  final String displayName;
  final String publicKeyFingerprint;
  final int issuedAt;
  final int expiresAt;

  bool isExpiredAt(int epochSeconds) => epochSeconds >= expiresAt;

  Map<String, Object?> toWireJson() => {
        'schemaVersion': schemaVersion,
        'type': payloadType,
        'requestId': requestId,
        'targetPrimaryDeviceId': targetPrimaryDeviceId,
        'deviceId': deviceId,
        'displayName': displayName,
        'publicKeyFingerprint': publicKeyFingerprint,
        'issuedAt': issuedAt,
        'expiresAt': expiresAt,
      };

  String toQrPayload() => jsonEncode(toWireJson());

  static DesktopLinkPairingRequest _validated({
    required String requestId,
    required String targetPrimaryDeviceId,
    required String deviceId,
    required String displayName,
    required String publicKeyFingerprint,
    required int issuedAt,
    required int expiresAt,
  }) {
    final normalizedRequestId = _requireValue(requestId, maxLength: 128);
    if (!_requestIdPattern.hasMatch(normalizedRequestId)) {
      throw ArgumentError.value(
          requestId, 'requestId', 'has an invalid format');
    }
    final normalizedTarget =
        _requireValue(targetPrimaryDeviceId, maxLength: 128);
    final normalizedDeviceId = _requireValue(deviceId, maxLength: 128);
    final normalizedName = _requireValue(displayName, maxLength: 80);
    final normalizedFingerprint =
        _requireValue(publicKeyFingerprint, minLength: 8, maxLength: 512);
    final lifetime = expiresAt - issuedAt;
    if (issuedAt < 0 ||
        expiresAt <= issuedAt ||
        lifetime < minLifetimeSeconds ||
        lifetime > maxLifetimeSeconds) {
      throw ArgumentError(
          'Desktop Link pairing request has an invalid lifetime');
    }
    return DesktopLinkPairingRequest._(
      requestId: normalizedRequestId,
      targetPrimaryDeviceId: normalizedTarget,
      deviceId: normalizedDeviceId,
      displayName: normalizedName,
      publicKeyFingerprint: normalizedFingerprint,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
    );
  }

  static String _readString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! String) _invalidPayload();
    return value;
  }

  static int _readInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! int) _invalidPayload();
    return value;
  }

  static String _requireValue(
    String value, {
    int minLength = 1,
    required int maxLength,
  }) {
    final normalized = value.trim();
    if (normalized.length < minLength || normalized.length > maxLength) {
      throw ArgumentError.value(value, 'value', 'has an invalid length');
    }
    return normalized;
  }

  static Never _invalidPayload() =>
      throw const FormatException('Invalid Desktop Link pairing payload');
}
