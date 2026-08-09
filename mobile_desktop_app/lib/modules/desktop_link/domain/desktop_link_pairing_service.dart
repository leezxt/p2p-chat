import '../data/desktop_link_pairing_repository.dart';
import 'desktop_link.dart';
import 'desktop_link_pairing_exception.dart';
import 'desktop_link_key_possession.dart';
import 'desktop_link_pairing_request.dart';
import 'desktop_link_service.dart';

/// 配對頁面需要的使用者動作。
///
/// UI 只依賴這組最小操作，讓掃描／確認互動可在不開啟 SQLite 與原生桌面
/// runner 的情況下測試；正式實作仍是 [DesktopLinkPairingService]。
abstract interface class DesktopLinkPairingActions {
  Future<DesktopLinkPairingRequest> prepareQrPayload(String rawPayload);

  Future<DesktopLinkKeyPossessionChallenge> createKeyPossessionChallenge(
    DesktopLinkPairingRequest request,
  );

  Future<void> verifyKeyPossessionResponse(String rawPayload);

  bool isKeyPossessionVerified(DesktopLinkPairingRequest request);

  Future<DesktopLink> confirm(DesktopLinkPairingRequest request);

  Future<void> reject(DesktopLinkPairingRequest request);
}

/// 將不可信 QR payload 轉為「使用者可檢閱、可明確同意」的配對流程。
///
/// 服務只在手機端持久化一次性請求的處理狀態。它沒有網路、沒有桌面連線；QR payload
/// 的 fingerprint binding 本身不算 proof，而是由 [DesktopLinkKeyPossessionService] 的
/// X25519 challenge-response 在 confirm 前建立 protocol-level proof。後續 transport 仍必須
/// 建立每副端 key exchange、加密封裝與 runtime 驗收。
class DesktopLinkPairingService implements DesktopLinkPairingActions {
  DesktopLinkPairingService({
    required DesktopLinkPairingRepository repository,
    required DesktopLinkService desktopLinkService,
    required DesktopLinkKeyPossessionService keyPossessionService,
    required String primaryDeviceId,
    DateTime Function()? clock,
  })  : _repository = repository,
        _desktopLinkService = desktopLinkService,
        _keyPossessionService = keyPossessionService,
        _primaryDeviceId = primaryDeviceId,
        _clock = clock ?? DateTime.now;

  final DesktopLinkPairingRepository _repository;
  final DesktopLinkService _desktopLinkService;
  final DesktopLinkKeyPossessionService _keyPossessionService;
  final String _primaryDeviceId;
  final DateTime Function() _clock;

  /// 僅驗證並暫存請求以供 UI 預覽；此方法絕不建立 Desktop Link。
  @override
  Future<DesktopLinkPairingRequest> prepareQrPayload(String rawPayload) async {
    final request = _parse(rawPayload);
    _ensureTargetsThisPrimary(request);
    _ensureNotExpired(request);
    await _repository.prepare(request, now: _nowEpochSeconds());
    return request;
  }

  /// 產生給桌面端的 encrypted challenge；此時仍不會授權 Desktop Link。challenge
  /// state 只存在記憶體，App 重啟或過期時會 fail-closed。
  @override
  Future<DesktopLinkKeyPossessionChallenge> createKeyPossessionChallenge(
    DesktopLinkPairingRequest request,
  ) async {
    _ensureTargetsThisPrimary(request);
    _ensureNotExpired(request);
    await _repository.prepare(request, now: _nowEpochSeconds());
    return _keyPossessionService.createChallenge(request);
  }

  /// 接收未來 desktop presentation／transport 交付的 response。成功後只標記本次
  /// request 已完成 proof；使用者仍必須明確按下確認才會進入授權。
  @override
  Future<void> verifyKeyPossessionResponse(String rawPayload) async {
    _keyPossessionService.verifyResponsePayload(rawPayload);
  }

  @override
  bool isKeyPossessionVerified(DesktopLinkPairingRequest request) =>
      _keyPossessionService.isVerified(request);

  /// 只應在 UI 顯示裝置名稱／fingerprint 並取得使用者確認後呼叫。
  @override
  Future<DesktopLink> confirm(DesktopLinkPairingRequest request) async {
    _ensureTargetsThisPrimary(request);
    _ensureNotExpired(request);
    await _repository.claimForConfirmation(request, now: _nowEpochSeconds());
    try {
      _keyPossessionService.requireVerified(request);
      final link = await _desktopLinkService.authorize(
        deviceId: request.deviceId,
        displayName: request.displayName,
        publicKeyFingerprint: request.publicKeyFingerprint,
      );
      await _repository.markConfirmed(
        request.requestId,
        now: _nowEpochSeconds(),
      );
      _keyPossessionService.consumeVerified(request);
      return link;
    } catch (_) {
      // 如果授權或最後寫入失敗，保留可重試的 pending 狀態；`authorize` 本身
      // 對活動中相同 fingerprint 的 link 是 idempotent，不會放寬同步切點。
      await _repository.releaseConfirmation(
        request.requestId,
        now: _nowEpochSeconds(),
      );
      rethrow;
    }
  }

  /// 使用者拒絕後將 request ID 標為已處理，避免同一 QR 再次觸發確認畫面。
  @override
  Future<void> reject(DesktopLinkPairingRequest request) async {
    _ensureTargetsThisPrimary(request);
    await _repository.reject(request, now: _nowEpochSeconds());
    _keyPossessionService.discard(request);
  }

  DesktopLinkPairingRequest _parse(String rawPayload) {
    try {
      return DesktopLinkPairingRequest.fromQrPayload(rawPayload);
    } on FormatException {
      throw const DesktopLinkPairingInvalidPayload();
    }
  }

  void _ensureTargetsThisPrimary(DesktopLinkPairingRequest request) {
    if (request.targetPrimaryDeviceId != _primaryDeviceId) {
      throw const DesktopLinkPairingWrongPrimaryDevice();
    }
  }

  void _ensureNotExpired(DesktopLinkPairingRequest request) {
    if (request.isExpiredAt(_nowEpochSeconds())) {
      throw const DesktopLinkPairingExpired();
    }
  }

  int _nowEpochSeconds() => _clock().millisecondsSinceEpoch ~/ 1000;
}
