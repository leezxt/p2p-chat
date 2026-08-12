import 'attachment_metadata.dart';

abstract interface class AttachmentTransfer {
  Future<void> download(AttachmentMetadata attachment);

  Future<void> cancel(String attachmentId);
}

enum AttachmentDownloadState {
  idle,
  blockedByPolicy,
  downloading,
  available,
  cancelled,
  failed,
}
