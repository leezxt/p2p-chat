import 'dart:convert';
import 'dart:typed_data';

import '../../crypto/domain/device_key_fingerprint.dart';

/// 可由桌面端顯示為 QR Code 的短效、一次性配對請求。
///
/// request 內的 [publicKey] 是桌面副端後續用於加密的 X25519 公鑰；
/// [publicKeyFingerprint] 必須由裝置 ID 與該公鑰重新推導，不能由 QR 任意宣告。
/// 它仍不是私鑰持有證明：手機端必須在後續雙向 challenge-response 成功，且使用者明確
/// 確認後，才可把它視為可用的 Desktop Link。
class DesktopLinkPairingRequest {
  const DesktopLinkPairingRequest._({
    required this.requestId,
    required this.targetPrimaryDeviceId,
    required this.deviceId,
    required this.displayName,
    required Uint8List publicKey,
    required this.publicKeyFingerprint,
    required this.issuedAt,
    required this.expiresAt,
  }) : _publicKey = publicKey;

  static const schemaVersion = 2;
  static const payloadType = 'desktop_link_pairing_request';
  static const defaultLifetimeSeconds = 300;
  static const minLifetimeSeconds = 30;
  static const maxLifetimeSeconds = 600;
  static const _maxPayloadLength = 4096;
  static const _publicKeyBytes = 32;
  static final _requestIdPattern = RegExp(r'^[A-Za-z0-9_-]{16,128}$');
  static const _requiredKeys = {
    'schemaVersion',
    'type',
    'requestId',
    'targetPrimaryDeviceId',
    'deviceId',
    'displayName',
    'publicKey',
    'publicKeyFingerprint',
    'issuedAt',
    'expiresAt',
  };

  factory DesktopLinkPairingRequest.create({
    required String requestId,
    required String targetPrimaryDeviceId,
    required String deviceId,
    required String displayName,
    required Uint8List publicKey,
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
    final normalizedDeviceId = _requireValue(deviceId, maxLength: 128);
    return _validated(
      requestId: requestId,
      targetPrimaryDeviceId: targetPrimaryDeviceId,
      deviceId: normalizedDeviceId,
      displayName: displayName,
      publicKey: publicKey,
      publicKeyFingerprint: computeDeviceKeyFingerprint(
        normalizedDeviceId,
        publicKey,
      ),
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
        publicKey: _readPublicKey(payload),
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
  final Uint8List _publicKey;
  final String publicKeyFingerprint;
  final int issuedAt;
  final int expiresAt;

  /// 只回傳 copy，避免呼叫端意外改寫用於 fingerprint 驗證的公開資料。
  Uint8List get publicKey => Uint8List.fromList(_publicKey);

  String get publicKeyBase64Url => _encodePublicKey(_publicKey);

  bool isExpiredAt(int epochSeconds) => epochSeconds >= expiresAt;

  Map<String, Object?> toWireJson() => {
        'schemaVersion': schemaVersion,
        'type': payloadType,
        'requestId': requestId,
        'targetPrimaryDeviceId': targetPrimaryDeviceId,
        'deviceId': deviceId,
        'displayName': displayName,
        'publicKey': publicKeyBase64Url,
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
    required Uint8List publicKey,
    required String publicKeyFingerprint,
    required int issuedAt,
    required int expiresAt,
  }) {
    final normalizedRequestId = _requireValue(requestId, maxLength: 128);
    if (!_requestIdPattern.hasMatch(normalizedRequestId)) {
      throw ArgumentError.value(
        requestId,
        'requestId',
        'has an invalid format',
      );
    }
    final normalizedTarget =
        _requireValue(targetPrimaryDeviceId, maxLength: 128);
    final normalizedDeviceId = _requireValue(deviceId, maxLength: 128);
    final normalizedName = _requireValue(displayName, maxLength: 80);
    final normalizedFingerprint =
        _requireValue(publicKeyFingerprint, minLength: 8, maxLength: 512);
    final copiedPublicKey = Uint8List.fromList(publicKey);
    if (copiedPublicKey.length != _publicKeyBytes) {
      throw ArgumentError.value(
        publicKey,
        'publicKey',
        'must be a $_publicKeyBytes-byte X25519 public key',
      );
    }
    final expectedFingerprint =
        computeDeviceKeyFingerprint(normalizedDeviceId, copiedPublicKey);
    if (normalizedFingerprint != expectedFingerprint) {
      throw ArgumentError.value(
        publicKeyFingerprint,
        'publicKeyFingerprint',
        'does not match deviceId and publicKey',
      );
    }
    final lifetime = expiresAt - issuedAt;
    if (issuedAt < 0 ||
        expiresAt <= issuedAt ||
        lifetime < minLifetimeSeconds ||
        lifetime > maxLifetimeSeconds) {
      throw ArgumentError(
        'Desktop Link pairing request has an invalid lifetime',
      );
    }
    return DesktopLinkPairingRequest._(
      requestId: normalizedRequestId,
      targetPrimaryDeviceId: normalizedTarget,
      deviceId: normalizedDeviceId,
      displayName: normalizedName,
      publicKey: copiedPublicKey,
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

  static Uint8List _readPublicKey(Map<String, Object?> payload) {
    final encoded = _readString(payload, 'publicKey');
    if (encoded.isEmpty || encoded.length > 128) _invalidPayload();
    try {
      final decoded = base64Url.decode(base64Url.normalize(encoded));
      if (_encodePublicKey(decoded) != encoded) _invalidPayload();
      return decoded;
    } on FormatException {
      _invalidPayload();
    }
  }

  static String _encodePublicKey(Uint8List publicKey) =>
      base64UrlEncode(publicKey).replaceAll('=', '');

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
