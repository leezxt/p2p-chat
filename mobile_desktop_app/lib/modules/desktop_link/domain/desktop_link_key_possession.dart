import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../crypto/domain/device_key_fingerprint.dart';
import '../../crypto/domain/device_key_material.dart';
import '../../crypto/domain/message_box.dart';
import 'desktop_link_pairing_exception.dart';
import 'desktop_link_pairing_request.dart';

/// 以既有 X25519 [MessageBox] 完成的 Desktop Link 私鑰持有驗證協定。
///
/// QR request 中的公開金鑰只告訴手機「要挑戰哪一把 key」。手機以自己的私鑰與該
/// 公開金鑰加密一個一次性 token；只有持有對應桌面私鑰的一端可以解開它，並再以桌面
/// 私鑰加密相同 token 回覆手機。這個檔案只處理短效、一次性的 protocol state；它不
/// 建立網路連線、不同步訊息，也不保存 challenge token 到 SQLite。

const _keyPossessionSchemaVersion = 1;
const _maxKeyPossessionPayloadLength = 8192;
const _maxKeyPossessionCiphertextLength = 6144;
const _maxKeyPossessionBase64Length = 8192;
const _keyPossessionPublicKeyBytes = 32;
final _keyPossessionIdPattern = RegExp(r'^[A-Za-z0-9_-]{16,128}$');

/// 手機主裝置送給桌面端的 authenticated-encrypted challenge。
///
/// 外層欄位只含 routing、公開金鑰與 ciphertext。一次性 token 位於 ciphertext 內，
/// 不會以明文出現在 QR／貼上資料。
class DesktopLinkKeyPossessionChallenge {
  DesktopLinkKeyPossessionChallenge._({
    required this.challengeId,
    required this.requestId,
    required this.primaryDeviceId,
    required this.desktopDeviceId,
    required this.desktopKeyFingerprint,
    required Uint8List primaryPublicKey,
    required this.issuedAt,
    required this.expiresAt,
    required Uint8List nonce,
    required Uint8List ciphertext,
  })  : _primaryPublicKey = Uint8List.fromList(primaryPublicKey),
        _nonce = Uint8List.fromList(nonce),
        _ciphertext = Uint8List.fromList(ciphertext);

  static const payloadType = 'desktop_link_key_possession_challenge';
  static const _requiredKeys = {
    'schemaVersion',
    'type',
    'challengeId',
    'requestId',
    'primaryDeviceId',
    'desktopDeviceId',
    'desktopKeyFingerprint',
    'primaryPublicKey',
    'issuedAt',
    'expiresAt',
    'nonce',
    'ciphertext',
  };

  factory DesktopLinkKeyPossessionChallenge.create({
    required String challengeId,
    required String requestId,
    required String primaryDeviceId,
    required String desktopDeviceId,
    required String desktopKeyFingerprint,
    required Uint8List primaryPublicKey,
    required int issuedAt,
    required int expiresAt,
    required Uint8List nonce,
    required Uint8List ciphertext,
  }) {
    _validateLifetime(issuedAt: issuedAt, expiresAt: expiresAt);
    return DesktopLinkKeyPossessionChallenge._(
      challengeId: _requireId(challengeId, 'challengeId'),
      requestId: _requireId(requestId, 'requestId'),
      primaryDeviceId: _requireValue(primaryDeviceId, 'primaryDeviceId'),
      desktopDeviceId: _requireValue(desktopDeviceId, 'desktopDeviceId'),
      desktopKeyFingerprint: _requireValue(
          desktopKeyFingerprint, 'desktopKeyFingerprint',
          max: 512),
      primaryPublicKey: _requirePublicKey(primaryPublicKey),
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      nonce: _requireBytes(nonce, 'nonce', max: 128),
      ciphertext: _requireBytes(
        ciphertext,
        'ciphertext',
        max: _maxKeyPossessionCiphertextLength,
      ),
    );
  }

  factory DesktopLinkKeyPossessionChallenge.fromPayload(String rawPayload) {
    try {
      final payload =
          _decodeOuterPayload(rawPayload, _requiredKeys, payloadType);
      return DesktopLinkKeyPossessionChallenge.create(
        challengeId: _readString(payload, 'challengeId'),
        requestId: _readString(payload, 'requestId'),
        primaryDeviceId: _readString(payload, 'primaryDeviceId'),
        desktopDeviceId: _readString(payload, 'desktopDeviceId'),
        desktopKeyFingerprint: _readString(payload, 'desktopKeyFingerprint'),
        primaryPublicKey: _decodeCanonicalBase64(
          _readString(payload, 'primaryPublicKey'),
          exactLength: _keyPossessionPublicKeyBytes,
        ),
        issuedAt: _readInt(payload, 'issuedAt'),
        expiresAt: _readInt(payload, 'expiresAt'),
        nonce: _decodeCanonicalBase64(_readString(payload, 'nonce'), max: 128),
        ciphertext: _decodeCanonicalBase64(
          _readString(payload, 'ciphertext'),
          max: _maxKeyPossessionCiphertextLength,
        ),
      );
    } on FormatException {
      rethrow;
    } on ArgumentError {
      _invalidKeyPossessionPayload();
    } on TypeError {
      _invalidKeyPossessionPayload();
    }
  }

  final String challengeId;
  final String requestId;
  final String primaryDeviceId;
  final String desktopDeviceId;
  final String desktopKeyFingerprint;
  final Uint8List _primaryPublicKey;
  final int issuedAt;
  final int expiresAt;
  final Uint8List _nonce;
  final Uint8List _ciphertext;

  Uint8List get primaryPublicKey => Uint8List.fromList(_primaryPublicKey);

  Uint8List get nonce => Uint8List.fromList(_nonce);

  Uint8List get ciphertext => Uint8List.fromList(_ciphertext);

  bool isExpiredAt(int epochSeconds) => epochSeconds >= expiresAt;

  Map<String, Object?> toWireJson() => {
        'schemaVersion': _keyPossessionSchemaVersion,
        'type': payloadType,
        'challengeId': challengeId,
        'requestId': requestId,
        'primaryDeviceId': primaryDeviceId,
        'desktopDeviceId': desktopDeviceId,
        'desktopKeyFingerprint': desktopKeyFingerprint,
        'primaryPublicKey': _encodeCanonicalBase64(_primaryPublicKey),
        'issuedAt': issuedAt,
        'expiresAt': expiresAt,
        'nonce': _encodeCanonicalBase64(_nonce),
        'ciphertext': _encodeCanonicalBase64(_ciphertext),
      };

  String toPayload() => jsonEncode(toWireJson());
}

/// 桌面端回給手機主裝置的 authenticated-encrypted proof response。
class DesktopLinkKeyPossessionResponse {
  DesktopLinkKeyPossessionResponse._({
    required this.challengeId,
    required this.requestId,
    required this.primaryDeviceId,
    required this.desktopDeviceId,
    required this.expiresAt,
    required Uint8List nonce,
    required Uint8List ciphertext,
  })  : _nonce = Uint8List.fromList(nonce),
        _ciphertext = Uint8List.fromList(ciphertext);

  static const payloadType = 'desktop_link_key_possession_response';
  static const _requiredKeys = {
    'schemaVersion',
    'type',
    'challengeId',
    'requestId',
    'primaryDeviceId',
    'desktopDeviceId',
    'expiresAt',
    'nonce',
    'ciphertext',
  };

  factory DesktopLinkKeyPossessionResponse.create({
    required String challengeId,
    required String requestId,
    required String primaryDeviceId,
    required String desktopDeviceId,
    required int expiresAt,
    required Uint8List nonce,
    required Uint8List ciphertext,
  }) {
    if (expiresAt < 0) {
      throw ArgumentError.value(expiresAt, 'expiresAt', 'must not be negative');
    }
    return DesktopLinkKeyPossessionResponse._(
      challengeId: _requireId(challengeId, 'challengeId'),
      requestId: _requireId(requestId, 'requestId'),
      primaryDeviceId: _requireValue(primaryDeviceId, 'primaryDeviceId'),
      desktopDeviceId: _requireValue(desktopDeviceId, 'desktopDeviceId'),
      expiresAt: expiresAt,
      nonce: _requireBytes(nonce, 'nonce', max: 128),
      ciphertext: _requireBytes(
        ciphertext,
        'ciphertext',
        max: _maxKeyPossessionCiphertextLength,
      ),
    );
  }

  factory DesktopLinkKeyPossessionResponse.fromPayload(String rawPayload) {
    try {
      final payload =
          _decodeOuterPayload(rawPayload, _requiredKeys, payloadType);
      return DesktopLinkKeyPossessionResponse.create(
        challengeId: _readString(payload, 'challengeId'),
        requestId: _readString(payload, 'requestId'),
        primaryDeviceId: _readString(payload, 'primaryDeviceId'),
        desktopDeviceId: _readString(payload, 'desktopDeviceId'),
        expiresAt: _readInt(payload, 'expiresAt'),
        nonce: _decodeCanonicalBase64(_readString(payload, 'nonce'), max: 128),
        ciphertext: _decodeCanonicalBase64(
          _readString(payload, 'ciphertext'),
          max: _maxKeyPossessionCiphertextLength,
        ),
      );
    } on FormatException {
      rethrow;
    } on ArgumentError {
      _invalidKeyPossessionPayload();
    } on TypeError {
      _invalidKeyPossessionPayload();
    }
  }

  final String challengeId;
  final String requestId;
  final String primaryDeviceId;
  final String desktopDeviceId;
  final int expiresAt;
  final Uint8List _nonce;
  final Uint8List _ciphertext;

  Uint8List get nonce => Uint8List.fromList(_nonce);

  Uint8List get ciphertext => Uint8List.fromList(_ciphertext);

  Map<String, Object?> toWireJson() => {
        'schemaVersion': _keyPossessionSchemaVersion,
        'type': payloadType,
        'challengeId': challengeId,
        'requestId': requestId,
        'primaryDeviceId': primaryDeviceId,
        'desktopDeviceId': desktopDeviceId,
        'expiresAt': expiresAt,
        'nonce': _encodeCanonicalBase64(_nonce),
        'ciphertext': _encodeCanonicalBase64(_ciphertext),
      };

  String toPayload() => jsonEncode(toWireJson());
}

/// 手機主端保存 challenge 的短效 RAM state，並只在驗證成功後放行確認授權。
class DesktopLinkKeyPossessionService {
  DesktopLinkKeyPossessionService({
    required MessageBox box,
    required DeviceKeyMaterial primaryKey,
    required String primaryDeviceId,
    DateTime Function()? clock,
    String Function()? challengeIdGenerator,
  })  : _box = box,
        _primaryKey = primaryKey,
        _primaryDeviceId = primaryDeviceId.trim(),
        _clock = clock ?? DateTime.now,
        _challengeIdGenerator = challengeIdGenerator ?? const Uuid().v4 {
    if (_primaryDeviceId.isEmpty) {
      throw ArgumentError.value(
          primaryDeviceId, 'primaryDeviceId', 'must not be empty');
    }
  }

  final MessageBox _box;
  final DeviceKeyMaterial _primaryKey;
  final String _primaryDeviceId;
  final DateTime Function() _clock;
  final String Function() _challengeIdGenerator;
  final _pending = <String, _PendingProof>{};
  final _verified = <String, _VerifiedProof>{};

  /// 產生只可使用一次的 challenge。未送出／未完成的 state 僅保留在 RAM；App 重啟
  /// 後會 fail-closed，必須重新產生 challenge。
  DesktopLinkKeyPossessionChallenge createChallenge(
    DesktopLinkPairingRequest request,
  ) {
    final now = _nowEpochSeconds();
    _purgeExpired(now);
    _ensureRequestTargetsThisPrimary(request);
    if (request.isExpiredAt(now) ||
        request.expiresAt - now <
            DesktopLinkPairingRequest.minLifetimeSeconds) {
      // 不發出只剩幾秒的 challenge，避免桌面端雖成功解密卻無法在相同 request
      // 的安全期限內回覆；使用者應重新取得新的短效 pairing request。
      throw const DesktopLinkPairingProofExpired();
    }

    final desktopPublicKey = request.publicKey;
    final primaryPublicKey = _primaryKey.publicKey;
    if (desktopPublicKey.length != _box.publicKeyBytes ||
        primaryPublicKey.length != _box.publicKeyBytes) {
      throw const DesktopLinkPairingProofInvalid();
    }

    Uint8List? encryptionNonce;
    Uint8List? challengeToken;
    Uint8List? plaintext;
    Uint8List? ciphertext;
    try {
      encryptionNonce = _box.randomNonce();
      challengeToken = _box.randomNonce();
      if (encryptionNonce.length != _box.nonceBytes ||
          challengeToken.length != _box.nonceBytes) {
        throw const DesktopLinkPairingProofInvalid();
      }
      final challengeId = _challengeIdGenerator();
      // 在寫入 RAM state 前先做格式驗證，避免不可回覆的 challenge 佔住 request。
      _requireId(challengeId, 'challengeId');
      plaintext = Uint8List.fromList(utf8.encode(jsonEncode({
        'schemaVersion': _keyPossessionSchemaVersion,
        'type': _ChallengeBody.payloadType,
        'challengeId': challengeId,
        'requestId': request.requestId,
        'primaryDeviceId': _primaryDeviceId,
        'desktopDeviceId': request.deviceId,
        'desktopKeyFingerprint': request.publicKeyFingerprint,
        'primaryPublicKey': _encodeCanonicalBase64(primaryPublicKey),
        'challengeToken': _encodeCanonicalBase64(challengeToken),
        'expiresAt': request.expiresAt,
      })));
      ciphertext = _box.encrypt(
        message: plaintext,
        nonce: encryptionNonce,
        publicKey: desktopPublicKey,
        secretKey: _primaryKey.secretKey,
      );
      final challenge = DesktopLinkKeyPossessionChallenge.create(
        challengeId: challengeId,
        requestId: request.requestId,
        primaryDeviceId: _primaryDeviceId,
        desktopDeviceId: request.deviceId,
        desktopKeyFingerprint: request.publicKeyFingerprint,
        primaryPublicKey: primaryPublicKey,
        issuedAt: now,
        expiresAt: request.expiresAt,
        nonce: encryptionNonce,
        ciphertext: ciphertext,
      );
      _discardForRequest(request);
      _pending[challengeId] = _PendingProof(
        binding: _RequestBinding.fromRequest(request),
        challengeId: challengeId,
        token: Uint8List.fromList(challengeToken),
        expiresAt: request.expiresAt,
      );
      return challenge;
    } on DesktopLinkPairingException {
      rethrow;
    } catch (_) {
      throw const DesktopLinkPairingProofCryptographicFailure();
    } finally {
      _zero(plaintext);
      _zero(encryptionNonce);
      _zero(challengeToken);
      _zero(ciphertext);
    }
  }

  /// 驗證桌面端回覆。任何無效嘗試都會作廢該 challenge，避免攻擊者對同一 token
  /// 重複猜測；使用者可以安全地重新產生一個新的 challenge。
  void verifyResponsePayload(String rawPayload) {
    final now = _nowEpochSeconds();
    final response = _parseResponse(rawPayload);
    final pending = _pending.remove(response.challengeId);
    _purgeExpired(now);
    if (pending == null) throw const DesktopLinkPairingProofNotIssued();

    Uint8List? plaintext;
    _ResponseBody? body;
    try {
      if (now >= pending.expiresAt || response.expiresAt != pending.expiresAt) {
        throw const DesktopLinkPairingProofExpired();
      }
      if (response.requestId != pending.binding.requestId ||
          response.primaryDeviceId != _primaryDeviceId ||
          response.desktopDeviceId != pending.binding.desktopDeviceId ||
          response.nonce.length != _box.nonceBytes) {
        throw const DesktopLinkPairingProofInvalid();
      }
      plaintext = _box.decrypt(
        ciphertext: response.ciphertext,
        nonce: response.nonce,
        publicKey: pending.binding.desktopPublicKey,
        secretKey: _primaryKey.secretKey,
      );
      body = _ResponseBody.fromPlaintext(plaintext);
      if (body.challengeId != pending.challengeId ||
          body.requestId != pending.binding.requestId ||
          body.primaryDeviceId != _primaryDeviceId ||
          body.desktopDeviceId != pending.binding.desktopDeviceId ||
          body.desktopKeyFingerprint != pending.binding.desktopKeyFingerprint ||
          body.expiresAt != pending.expiresAt ||
          !_constantTimeEquals(body.challengeToken, pending.token)) {
        throw const DesktopLinkPairingProofInvalid();
      }
      _verified[pending.binding.requestId] = _VerifiedProof(
        binding: pending.binding,
        expiresAt: pending.expiresAt,
      );
    } on DesktopLinkPairingException {
      rethrow;
    } catch (_) {
      throw const DesktopLinkPairingProofInvalid();
    } finally {
      body?.dispose();
      _zero(plaintext);
      pending.dispose();
    }
  }

  bool isVerified(DesktopLinkPairingRequest request) {
    _purgeExpired(_nowEpochSeconds());
    final verified = _verified[request.requestId];
    return verified != null && verified.binding.matches(request);
  }

  /// [DesktopLinkPairingService.confirm] 在主裝置真正授權前呼叫；沒有本次 request
  /// 的有效 proof 時一律拒絕。
  void requireVerified(DesktopLinkPairingRequest request) {
    if (!isVerified(request)) throw const DesktopLinkPairingProofRequired();
  }

  /// 只在 Desktop Link 授權成功後消耗 proof。若資料庫授權失敗，proof 可在未到期
  /// 的情況下重試，避免因暫時性 SQLite 失敗迫使用者重新掃碼。
  void consumeVerified(DesktopLinkPairingRequest request) {
    // `confirm` 已在開始實際授權前呼叫 requireVerified。此處不再次讀取時鐘，避免
    // SQLite 成功授權剛好跨過到期秒時，留下「link 已建立但 request 仍 pending」的不一致。
    final verified = _verified[request.requestId];
    if (verified == null || !verified.binding.matches(request)) {
      throw const DesktopLinkPairingProofRequired();
    }
    _verified.remove(request.requestId);
  }

  /// 使用者拒絕 request 時一併清除 RAM 中的 challenge／proof。
  void discard(DesktopLinkPairingRequest request) =>
      _discardForRequest(request);

  void dispose() {
    for (final pending in _pending.values) {
      pending.dispose();
    }
    _pending.clear();
    _verified.clear();
  }

  void _ensureRequestTargetsThisPrimary(DesktopLinkPairingRequest request) {
    if (request.targetPrimaryDeviceId != _primaryDeviceId) {
      throw const DesktopLinkPairingWrongPrimaryDevice();
    }
  }

  DesktopLinkKeyPossessionResponse _parseResponse(String rawPayload) {
    try {
      return DesktopLinkKeyPossessionResponse.fromPayload(rawPayload);
    } on FormatException {
      throw const DesktopLinkPairingProofInvalid();
    }
  }

  void _discardForRequest(DesktopLinkPairingRequest request) {
    final binding = _RequestBinding.fromRequest(request);
    final pendingIds = _pending.entries
        .where((entry) => entry.value.binding.matches(request))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final id in pendingIds) {
      _pending.remove(id)?.dispose();
    }
    final verified = _verified[request.requestId];
    if (verified != null && verified.binding == binding) {
      _verified.remove(request.requestId);
    }
  }

  void _purgeExpired(int now) {
    final pendingIds = _pending.entries
        .where((entry) => now >= entry.value.expiresAt)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final id in pendingIds) {
      _pending.remove(id)?.dispose();
    }
    _verified.removeWhere((_, value) => now >= value.expiresAt);
  }

  int _nowEpochSeconds() => _clock().millisecondsSinceEpoch ~/ 1000;
}

/// 桌面端可重用的 responder。Desktop Companion 或未來 transport 只需把手機傳來的
/// [DesktopLinkKeyPossessionChallenge] payload 交給它；本身不持久化、不建立連線。
class DesktopLinkKeyPossessionResponder {
  DesktopLinkKeyPossessionResponder({
    required MessageBox box,
    required DeviceKeyMaterial desktopKey,
    required String desktopDeviceId,
    DateTime Function()? clock,
  })  : _box = box,
        _desktopKey = desktopKey,
        _desktopDeviceId = desktopDeviceId.trim(),
        _clock = clock ?? DateTime.now {
    if (_desktopDeviceId.isEmpty) {
      throw ArgumentError.value(
          desktopDeviceId, 'desktopDeviceId', 'must not be empty');
    }
  }

  final MessageBox _box;
  final DeviceKeyMaterial _desktopKey;
  final String _desktopDeviceId;
  final DateTime Function() _clock;

  DesktopLinkKeyPossessionResponse respondToChallengePayload(
      String rawPayload) {
    final challenge = _parseChallenge(rawPayload);
    final now = _clock().millisecondsSinceEpoch ~/ 1000;
    if (challenge.isExpiredAt(now) ||
        challenge.desktopDeviceId != _desktopDeviceId ||
        challenge.primaryPublicKey.length != _box.publicKeyBytes ||
        challenge.nonce.length != _box.nonceBytes) {
      throw const DesktopLinkPairingProofInvalid();
    }

    final desktopPublicKey = _desktopKey.publicKey;
    if (desktopPublicKey.length != _box.publicKeyBytes ||
        computeDeviceKeyFingerprint(_desktopDeviceId, desktopPublicKey) !=
            challenge.desktopKeyFingerprint) {
      throw const DesktopLinkPairingProofInvalid();
    }

    Uint8List? plaintext;
    _ChallengeBody? body;
    Uint8List? responseNonce;
    Uint8List? responsePlaintext;
    Uint8List? ciphertext;
    try {
      plaintext = _box.decrypt(
        ciphertext: challenge.ciphertext,
        nonce: challenge.nonce,
        publicKey: challenge.primaryPublicKey,
        secretKey: _desktopKey.secretKey,
      );
      body = _ChallengeBody.fromPlaintext(plaintext);
      if (body.challengeId != challenge.challengeId ||
          body.requestId != challenge.requestId ||
          body.primaryDeviceId != challenge.primaryDeviceId ||
          body.desktopDeviceId != _desktopDeviceId ||
          body.desktopKeyFingerprint != challenge.desktopKeyFingerprint ||
          body.expiresAt != challenge.expiresAt ||
          !_constantTimeEquals(
              body.primaryPublicKey, challenge.primaryPublicKey) ||
          body.challengeToken.length != _box.nonceBytes) {
        throw const DesktopLinkPairingProofInvalid();
      }
      responseNonce = _box.randomNonce();
      if (responseNonce.length != _box.nonceBytes) {
        throw const DesktopLinkPairingProofInvalid();
      }
      responsePlaintext = Uint8List.fromList(utf8.encode(jsonEncode({
        'schemaVersion': _keyPossessionSchemaVersion,
        'type': _ResponseBody.payloadType,
        'challengeId': challenge.challengeId,
        'requestId': challenge.requestId,
        'primaryDeviceId': challenge.primaryDeviceId,
        'desktopDeviceId': _desktopDeviceId,
        'desktopKeyFingerprint': challenge.desktopKeyFingerprint,
        'challengeToken': _encodeCanonicalBase64(body.challengeToken),
        'expiresAt': challenge.expiresAt,
      })));
      ciphertext = _box.encrypt(
        message: responsePlaintext,
        nonce: responseNonce,
        publicKey: challenge.primaryPublicKey,
        secretKey: _desktopKey.secretKey,
      );
      return DesktopLinkKeyPossessionResponse.create(
        challengeId: challenge.challengeId,
        requestId: challenge.requestId,
        primaryDeviceId: challenge.primaryDeviceId,
        desktopDeviceId: _desktopDeviceId,
        expiresAt: challenge.expiresAt,
        nonce: responseNonce,
        ciphertext: ciphertext,
      );
    } on DesktopLinkPairingException {
      rethrow;
    } catch (_) {
      throw const DesktopLinkPairingProofInvalid();
    } finally {
      body?.dispose();
      _zero(plaintext);
      _zero(responseNonce);
      _zero(responsePlaintext);
      _zero(ciphertext);
    }
  }

  DesktopLinkKeyPossessionChallenge _parseChallenge(String rawPayload) {
    try {
      return DesktopLinkKeyPossessionChallenge.fromPayload(rawPayload);
    } on FormatException {
      throw const DesktopLinkPairingProofInvalid();
    }
  }
}

class _RequestBinding {
  const _RequestBinding({
    required this.requestId,
    required this.desktopDeviceId,
    required this.desktopPublicKeyBase64,
    required this.desktopKeyFingerprint,
    required this.targetPrimaryDeviceId,
  });

  factory _RequestBinding.fromRequest(DesktopLinkPairingRequest request) =>
      _RequestBinding(
        requestId: request.requestId,
        desktopDeviceId: request.deviceId,
        desktopPublicKeyBase64: request.publicKeyBase64Url,
        desktopKeyFingerprint: request.publicKeyFingerprint,
        targetPrimaryDeviceId: request.targetPrimaryDeviceId,
      );

  final String requestId;
  final String desktopDeviceId;
  final String desktopPublicKeyBase64;
  final String desktopKeyFingerprint;
  final String targetPrimaryDeviceId;

  Uint8List get desktopPublicKey => _decodeCanonicalBase64(
        desktopPublicKeyBase64,
        exactLength: _keyPossessionPublicKeyBytes,
      );

  bool matches(DesktopLinkPairingRequest request) =>
      requestId == request.requestId &&
      desktopDeviceId == request.deviceId &&
      desktopPublicKeyBase64 == request.publicKeyBase64Url &&
      desktopKeyFingerprint == request.publicKeyFingerprint &&
      targetPrimaryDeviceId == request.targetPrimaryDeviceId;

  @override
  bool operator ==(Object other) =>
      other is _RequestBinding &&
      requestId == other.requestId &&
      desktopDeviceId == other.desktopDeviceId &&
      desktopPublicKeyBase64 == other.desktopPublicKeyBase64 &&
      desktopKeyFingerprint == other.desktopKeyFingerprint &&
      targetPrimaryDeviceId == other.targetPrimaryDeviceId;

  @override
  int get hashCode => Object.hash(
        requestId,
        desktopDeviceId,
        desktopPublicKeyBase64,
        desktopKeyFingerprint,
        targetPrimaryDeviceId,
      );
}

class _PendingProof {
  _PendingProof({
    required this.binding,
    required this.challengeId,
    required Uint8List token,
    required this.expiresAt,
  }) : token = Uint8List.fromList(token);

  final _RequestBinding binding;
  final String challengeId;
  final Uint8List token;
  final int expiresAt;

  void dispose() => _zero(token);
}

class _VerifiedProof {
  const _VerifiedProof({required this.binding, required this.expiresAt});

  final _RequestBinding binding;
  final int expiresAt;
}

class _ChallengeBody {
  _ChallengeBody({
    required this.challengeId,
    required this.requestId,
    required this.primaryDeviceId,
    required this.desktopDeviceId,
    required this.desktopKeyFingerprint,
    required Uint8List primaryPublicKey,
    required Uint8List challengeToken,
    required this.expiresAt,
  })  : primaryPublicKey = Uint8List.fromList(primaryPublicKey),
        challengeToken = Uint8List.fromList(challengeToken);

  static const payloadType = 'desktop_link_key_possession_challenge_body';
  static const _requiredKeys = {
    'schemaVersion',
    'type',
    'challengeId',
    'requestId',
    'primaryDeviceId',
    'desktopDeviceId',
    'desktopKeyFingerprint',
    'primaryPublicKey',
    'challengeToken',
    'expiresAt',
  };

  factory _ChallengeBody.fromPlaintext(Uint8List plaintext) {
    final payload = _decodeInnerPayload(plaintext, _requiredKeys, payloadType);
    return _ChallengeBody(
      challengeId:
          _requireId(_readString(payload, 'challengeId'), 'challengeId'),
      requestId: _requireId(_readString(payload, 'requestId'), 'requestId'),
      primaryDeviceId: _requireValue(
        _readString(payload, 'primaryDeviceId'),
        'primaryDeviceId',
      ),
      desktopDeviceId: _requireValue(
        _readString(payload, 'desktopDeviceId'),
        'desktopDeviceId',
      ),
      desktopKeyFingerprint: _requireValue(
        _readString(payload, 'desktopKeyFingerprint'),
        'desktopKeyFingerprint',
        max: 512,
      ),
      primaryPublicKey: _decodeCanonicalBase64(
        _readString(payload, 'primaryPublicKey'),
        exactLength: _keyPossessionPublicKeyBytes,
      ),
      challengeToken: _decodeCanonicalBase64(
        _readString(payload, 'challengeToken'),
        max: 128,
      ),
      expiresAt: _readInt(payload, 'expiresAt'),
    );
  }

  final String challengeId;
  final String requestId;
  final String primaryDeviceId;
  final String desktopDeviceId;
  final String desktopKeyFingerprint;
  final Uint8List primaryPublicKey;
  final Uint8List challengeToken;
  final int expiresAt;

  void dispose() {
    _zero(primaryPublicKey);
    _zero(challengeToken);
  }
}

class _ResponseBody {
  _ResponseBody({
    required this.challengeId,
    required this.requestId,
    required this.primaryDeviceId,
    required this.desktopDeviceId,
    required this.desktopKeyFingerprint,
    required Uint8List challengeToken,
    required this.expiresAt,
  }) : challengeToken = Uint8List.fromList(challengeToken);

  static const payloadType = 'desktop_link_key_possession_response_body';
  static const _requiredKeys = {
    'schemaVersion',
    'type',
    'challengeId',
    'requestId',
    'primaryDeviceId',
    'desktopDeviceId',
    'desktopKeyFingerprint',
    'challengeToken',
    'expiresAt',
  };

  factory _ResponseBody.fromPlaintext(Uint8List plaintext) {
    final payload = _decodeInnerPayload(plaintext, _requiredKeys, payloadType);
    return _ResponseBody(
      challengeId:
          _requireId(_readString(payload, 'challengeId'), 'challengeId'),
      requestId: _requireId(_readString(payload, 'requestId'), 'requestId'),
      primaryDeviceId: _requireValue(
        _readString(payload, 'primaryDeviceId'),
        'primaryDeviceId',
      ),
      desktopDeviceId: _requireValue(
        _readString(payload, 'desktopDeviceId'),
        'desktopDeviceId',
      ),
      desktopKeyFingerprint: _requireValue(
        _readString(payload, 'desktopKeyFingerprint'),
        'desktopKeyFingerprint',
        max: 512,
      ),
      challengeToken: _decodeCanonicalBase64(
        _readString(payload, 'challengeToken'),
        max: 128,
      ),
      expiresAt: _readInt(payload, 'expiresAt'),
    );
  }

  final String challengeId;
  final String requestId;
  final String primaryDeviceId;
  final String desktopDeviceId;
  final String desktopKeyFingerprint;
  final Uint8List challengeToken;
  final int expiresAt;

  void dispose() => _zero(challengeToken);
}

Map<String, Object?> _decodeOuterPayload(
  String rawPayload,
  Set<String> requiredKeys,
  String type,
) {
  if (rawPayload.trim().isEmpty ||
      rawPayload.length > _maxKeyPossessionPayloadLength) {
    _invalidKeyPossessionPayload();
  }
  try {
    final decoded = jsonDecode(rawPayload);
    if (decoded is! Map) _invalidKeyPossessionPayload();
    final payload = Map<String, Object?>.from(decoded);
    final keys = payload.keys.toSet();
    if (keys.length != requiredKeys.length ||
        !keys.containsAll(requiredKeys) ||
        payload['schemaVersion'] != _keyPossessionSchemaVersion ||
        payload['type'] != type) {
      _invalidKeyPossessionPayload();
    }
    return payload;
  } on FormatException {
    _invalidKeyPossessionPayload();
  } on TypeError {
    _invalidKeyPossessionPayload();
  }
}

Map<String, Object?> _decodeInnerPayload(
  Uint8List plaintext,
  Set<String> requiredKeys,
  String type,
) {
  try {
    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! Map) _invalidKeyPossessionPayload();
    final payload = Map<String, Object?>.from(decoded);
    final keys = payload.keys.toSet();
    if (keys.length != requiredKeys.length ||
        !keys.containsAll(requiredKeys) ||
        payload['schemaVersion'] != _keyPossessionSchemaVersion ||
        payload['type'] != type) {
      _invalidKeyPossessionPayload();
    }
    return payload;
  } on FormatException {
    _invalidKeyPossessionPayload();
  } on TypeError {
    _invalidKeyPossessionPayload();
  }
}

String _readString(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is! String) _invalidKeyPossessionPayload();
  return value;
}

int _readInt(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is! int) _invalidKeyPossessionPayload();
  return value;
}

String _requireId(String value, String field) {
  final normalized = _requireValue(value, field);
  if (!_keyPossessionIdPattern.hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'has invalid format');
  }
  return normalized;
}

String _requireValue(String value, String field, {int max = 128}) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > max) {
    throw ArgumentError.value(value, field, 'has invalid length');
  }
  return normalized;
}

Uint8List _requirePublicKey(Uint8List value) {
  final copied = Uint8List.fromList(value);
  if (copied.length != _keyPossessionPublicKeyBytes) {
    throw ArgumentError.value(
        value, 'publicKey', 'must be a 32-byte X25519 key');
  }
  return copied;
}

Uint8List _requireBytes(Uint8List value, String field, {required int max}) {
  final copied = Uint8List.fromList(value);
  if (copied.isEmpty || copied.length > max) {
    throw ArgumentError.value(value, field, 'has invalid length');
  }
  return copied;
}

void _validateLifetime({required int issuedAt, required int expiresAt}) {
  final lifetime = expiresAt - issuedAt;
  if (issuedAt < 0 ||
      expiresAt <= issuedAt ||
      lifetime < DesktopLinkPairingRequest.minLifetimeSeconds ||
      lifetime > DesktopLinkPairingRequest.maxLifetimeSeconds) {
    throw ArgumentError(
        'Desktop Link key possession challenge has invalid lifetime');
  }
}

Uint8List _decodeCanonicalBase64(
  String value, {
  int? exactLength,
  int max = _maxKeyPossessionBase64Length,
}) {
  if (value.isEmpty || value.length > max) _invalidKeyPossessionPayload();
  try {
    final decoded = base64Url.decode(base64Url.normalize(value));
    if (_encodeCanonicalBase64(decoded) != value ||
        (exactLength != null && decoded.length != exactLength)) {
      _invalidKeyPossessionPayload();
    }
    return decoded;
  } on FormatException {
    _invalidKeyPossessionPayload();
  }
}

String _encodeCanonicalBase64(Uint8List bytes) =>
    base64UrlEncode(bytes).replaceAll('=', '');

bool _constantTimeEquals(Uint8List left, Uint8List right) {
  var difference = left.length ^ right.length;
  final maxLength = left.length >= right.length ? left.length : right.length;
  for (var index = 0; index < maxLength; index++) {
    final leftByte = index < left.length ? left[index] : 0;
    final rightByte = index < right.length ? right[index] : 0;
    difference |= leftByte ^ rightByte;
  }
  return difference == 0;
}

void _zero(Uint8List? bytes) {
  if (bytes != null) bytes.fillRange(0, bytes.length, 0);
}

Never _invalidKeyPossessionPayload() =>
    throw const FormatException('Invalid Desktop Link key possession payload');
