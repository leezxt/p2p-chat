import 'package:flutter/foundation.dart';

import '../../../core/resource_policy/resource_policy_service.dart';
import 'attachment_metadata.dart';
import 'attachment_transfer.dart';

/// 按需下載附件，避免背景或低功耗模式自動取得大型內容。
class AttachmentDownloadController extends ChangeNotifier {
  AttachmentDownloadController({
    required AttachmentTransfer transfer,
    required ResourcePolicyService resourcePolicy,
  })  : _transfer = transfer,
        _resourcePolicy = resourcePolicy;

  final AttachmentTransfer _transfer;
  final ResourcePolicyService _resourcePolicy;
  final Map<String, AttachmentDownloadState> _states = {};

  AttachmentDownloadState stateFor(String attachmentId) =>
      _states[attachmentId] ?? AttachmentDownloadState.idle;

  Future<void> request(AttachmentMetadata attachment,
      {required bool manual}) async {
    if (!manual && !_mayAutoDownload(attachment)) {
      _set(attachment.attachmentId, AttachmentDownloadState.blockedByPolicy);
      return;
    }
    if (stateFor(attachment.attachmentId) ==
        AttachmentDownloadState.downloading) {
      return;
    }
    _set(attachment.attachmentId, AttachmentDownloadState.downloading);
    try {
      await _transfer.download(attachment);
      if (stateFor(attachment.attachmentId) ==
          AttachmentDownloadState.downloading) {
        _set(attachment.attachmentId, AttachmentDownloadState.available);
      }
    } catch (_) {
      if (stateFor(attachment.attachmentId) ==
          AttachmentDownloadState.downloading) {
        _set(attachment.attachmentId, AttachmentDownloadState.failed);
      }
    }
  }

  Future<void> cancel(String attachmentId) async {
    if (stateFor(attachmentId) != AttachmentDownloadState.downloading) return;
    await _transfer.cancel(attachmentId);
    _set(attachmentId, AttachmentDownloadState.cancelled);
  }

  bool _mayAutoDownload(AttachmentMetadata attachment) =>
      attachment.kind == AttachmentKind.image &&
      _resourcePolicy.autoDownloadImages;

  void _set(String id, AttachmentDownloadState state) {
    _states[id] = state;
    notifyListeners();
  }
}
