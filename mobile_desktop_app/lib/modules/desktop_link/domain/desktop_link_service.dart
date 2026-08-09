import '../../../core/events/event_bus.dart';
import '../../../shared/models/message_envelope.dart';
import '../data/desktop_link_repository.dart';
import '../events/desktop_link_changed.dart';
import 'desktop_link.dart';

/// UI 與後續 adapter 需要的 Desktop Link 管理能力。
///
/// 將頁面依賴限制在此介面，可讓 UI 測試不必啟動 SQLite 或桌面原生資產；
/// 實際的授權與撤銷規則仍由 [DesktopLinkService] 強制執行。
abstract interface class DesktopLinkManager {
  Future<List<DesktopLink>> listLinks();

  Future<DesktopLink> revoke(String deviceId);
}

/// Desktop Link 的主裝置授權與本機同步閘門。
///
/// 這個 service 不會建立桌面連線、不會解密或傳送聊天內容。它只提供後續
/// transport adapter 必須先遵守的安全決策：主裝置明確授權、只選出授權後
/// 的新訊息，且撤銷後立即拒絕任何新的同步選取。
class DesktopLinkService implements DesktopLinkManager {
  DesktopLinkService({
    required DesktopLinkRepository repository,
    required String primaryDeviceId,
    required EventBus eventBus,
    DateTime Function()? clock,
  })  : _repository = repository,
        _primaryDeviceId = primaryDeviceId,
        _eventBus = eventBus,
        _clock = clock ?? DateTime.now;

  final DesktopLinkRepository _repository;
  final String _primaryDeviceId;
  final EventBus _eventBus;
  final DateTime Function() _clock;

  @override
  Future<List<DesktopLink>> listLinks() => _repository.list();

  /// 由手機上的明確使用者操作完成授權。
  ///
  /// 對已啟用且同 fingerprint 的 link 保持 idempotent，避免重掃 QR 時靜默
  /// 重設同步切點。已撤銷的相同副端只能經此方法重新授權，且會取得新的切點。
  Future<DesktopLink> authorize({
    required String deviceId,
    required String displayName,
    required String publicKeyFingerprint,
  }) async {
    final normalizedDeviceId = _requireValue(deviceId, field: 'deviceId');
    final normalizedDisplayName =
        _requireValue(displayName, field: 'displayName');
    final normalizedFingerprint =
        _requireValue(publicKeyFingerprint, field: 'publicKeyFingerprint');

    if (normalizedDeviceId == _primaryDeviceId) {
      throw DesktopLinkPrimaryDeviceRejected(normalizedDeviceId);
    }

    final existing = await _repository.findByDeviceId(normalizedDeviceId);
    if (existing != null &&
        existing.publicKeyFingerprint != normalizedFingerprint) {
      // 同一 device ID 的 key fingerprint 改變不能被 UI 靜默接受；後續協定需
      // 以新的裝置身份重新配對，避免把 key rotation 當成原裝置延續。
      throw DesktopLinkFingerprintMismatch(normalizedDeviceId);
    }
    if (existing != null && existing.isActive) return existing;

    final now = _nowEpochSeconds();
    // 重新授權若剛好與撤銷落在同秒，保守地把切點推到既有狀態之後，確保舊
    // link 不會因 timestamp 解析度不足而取得歷史訊息。
    final authorizedAfter =
        existing == null ? now : _max(now, existing.updatedAt + 1);
    final link = DesktopLink(
      deviceId: normalizedDeviceId,
      displayName: normalizedDisplayName,
      publicKeyFingerprint: normalizedFingerprint,
      authorizedAfter: authorizedAfter,
      createdAt: existing?.createdAt ?? now,
      // 將狀態時間與保守同步切點保持單調，避免本機時鐘倒退時放寬既有閘門。
      updatedAt: authorizedAfter,
    );
    await _repository.save(link);
    _eventBus.emit(
      DesktopLinkChanged(
        link: link,
        kind: DesktopLinkChangeKind.authorized,
      ),
    );
    return link;
  }

  /// 將副端標為撤銷。重複撤銷保持 idempotent，確保呼叫端可安全重試。
  @override
  Future<DesktopLink> revoke(String deviceId) async {
    final normalizedDeviceId = _requireValue(deviceId, field: 'deviceId');
    final existing = await _repository.findByDeviceId(normalizedDeviceId);
    if (existing == null) throw DesktopLinkNotFound(normalizedDeviceId);
    if (!existing.isActive) return existing;

    final revokedAt = _max(_nowEpochSeconds(), existing.updatedAt);
    final link = DesktopLink(
      deviceId: existing.deviceId,
      displayName: existing.displayName,
      publicKeyFingerprint: existing.publicKeyFingerprint,
      authorizedAfter: existing.authorizedAfter,
      revokedAt: revokedAt,
      createdAt: existing.createdAt,
      updatedAt: revokedAt,
    );
    await _repository.save(link);
    _eventBus.emit(
      DesktopLinkChanged(link: link, kind: DesktopLinkChangeKind.revoked),
    );
    return link;
  }

  /// 單則訊息是否可送入指定副端的「新訊息」同步候選集。
  ///
  /// 未授權、已撤銷、授權前與同秒訊息均回傳 false；這是方便呼叫端快速
  /// 判定用的 fail-closed API。需要取得候選清單時使用 [selectNewMessages]。
  Future<bool> canSyncMessage({
    required String deviceId,
    required MessageEnvelope message,
  }) async {
    final link = await _repository.findByDeviceId(deviceId.trim());
    return link != null &&
        link.isActive &&
        message.createdAt > link.authorizedAfter;
  }

  /// 取得安全可同步的新訊息；撤銷或未授權的副端一律拋出 fail-closed 例外。
  ///
  /// 這裡不改寫訊息、不解密也不傳網路；後續 adapter 必須使用此選取結果，
  /// 並在送出前以該副端的新裝置金鑰再次加密。
  Future<List<MessageEnvelope>> selectNewMessages({
    required String deviceId,
    required Iterable<MessageEnvelope> candidates,
  }) async {
    final normalizedDeviceId = _requireValue(deviceId, field: 'deviceId');
    final link = await _requireActiveLink(normalizedDeviceId);
    return candidates
        .where((message) => message.createdAt > link.authorizedAfter)
        .toList(growable: false);
  }

  Future<DesktopLink> _requireActiveLink(String deviceId) async {
    final link = await _repository.findByDeviceId(deviceId);
    if (link == null) throw DesktopLinkNotFound(deviceId);
    if (!link.isActive) throw DesktopLinkRevoked(deviceId);
    return link;
  }

  String _requireValue(String value, {required String field}) {
    final normalized = value.trim();
    if (normalized.isEmpty) throw DesktopLinkInvalidRequest(field);
    return normalized;
  }

  int _nowEpochSeconds() => _clock().millisecondsSinceEpoch ~/ 1000;

  int _max(int left, int right) => left >= right ? left : right;
}

abstract class DesktopLinkException implements Exception {
  const DesktopLinkException(this.message);

  final String message;

  @override
  String toString() => 'DesktopLinkException: $message';
}

class DesktopLinkInvalidRequest extends DesktopLinkException {
  const DesktopLinkInvalidRequest(String field)
      : super('Desktop Link 欄位不可空白：$field');
}

class DesktopLinkPrimaryDeviceRejected extends DesktopLinkException {
  const DesktopLinkPrimaryDeviceRejected(String deviceId)
      : super('主裝置不可被當成桌面副端授權：$deviceId');
}

class DesktopLinkFingerprintMismatch extends DesktopLinkException {
  const DesktopLinkFingerprintMismatch(String deviceId)
      : super('副端 fingerprint 已變更，請以新裝置重新配對：$deviceId');
}

class DesktopLinkNotFound extends DesktopLinkException {
  const DesktopLinkNotFound(String deviceId)
      : super('找不到 Desktop Link：$deviceId');
}

class DesktopLinkRevoked extends DesktopLinkException {
  const DesktopLinkRevoked(String deviceId)
      : super('Desktop Link 已撤銷，拒絕同步：$deviceId');
}
