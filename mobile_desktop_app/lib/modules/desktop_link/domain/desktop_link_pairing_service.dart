import '../data/desktop_link_pairing_repository.dart';
import 'desktop_link.dart';
import 'desktop_link_pairing_exception.dart';
import 'desktop_link_pairing_request.dart';
import 'desktop_link_service.dart';

/// 配對頁面需要的使用者動作。
///
/// UI 只依賴這組最小操作，讓掃描／確認互動可在不開啟 SQLite 與原生桌面
/// runner 的情況下測試；正式實作仍是 [DesktopLinkPairingService]。
abstract interface class DesktopLinkPairingActions {
  Future<DesktopLinkPairingRequest> prepareQrPayload(String rawPayload);

  Future<DesktopLink> confirm(DesktopLinkPairingRequest request);

  Future<void> reject(DesktopLinkPairingRequest request);
}

/// 將不可信 QR payload 轉為「使用者可檢閱、可明確同意」的配對流程。
///
/// 服務只在手機端持久化一次性請求的處理狀態。它沒有網路、沒有桌面連線，且
/// 不把 payload 中宣告的 fingerprint 當成私鑰持有證明；後續 transport 必須再做
/// signed challenge 與 per-device key exchange。
class DesktopLinkPairingService implements DesktopLinkPairingActions {
  DesktopLinkPairingService({
    required DesktopLinkPairingRepository repository,
    required DesktopLinkService desktopLinkService,
    required String primaryDeviceId,
    DateTime Function()? clock,
  })  : _repository = repository,
        _desktopLinkService = desktopLinkService,
        _primaryDeviceId = primaryDeviceId,
        _clock = clock ?? DateTime.now;

  final DesktopLinkPairingRepository _repository;
  final DesktopLinkService _desktopLinkService;
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

  /// 只應在 UI 顯示裝置名稱／fingerprint 並取得使用者確認後呼叫。
  @override
  Future<DesktopLink> confirm(DesktopLinkPairingRequest request) async {
    _ensureTargetsThisPrimary(request);
    _ensureNotExpired(request);
    await _repository.claimForConfirmation(request, now: _nowEpochSeconds());
    try {
      final link = await _desktopLinkService.authorize(
        deviceId: request.deviceId,
        displayName: request.displayName,
        publicKeyFingerprint: request.publicKeyFingerprint,
      );
      await _repository.markConfirmed(
        request.requestId,
        now: _nowEpochSeconds(),
      );
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
