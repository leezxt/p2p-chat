/// Storage Manager 顯示的本機用量快照。
///
/// [protectedPendingMailboxBytes] 是未送訊息所佔的資料庫內容，只用於揭露
/// 受保護範圍，絕不列入可清理空間。
class StorageUsageSnapshot {
  const StorageUsageSnapshot({
    required this.databaseBytes,
    required this.cacheBytes,
    required this.attachmentBytes,
    required this.protectedPendingMailboxBytes,
  });

  final int databaseBytes;
  final int cacheBytes;
  final int attachmentBytes;
  final int protectedPendingMailboxBytes;

  int get totalBytes => databaseBytes + cacheBytes + attachmentBytes;
  int get reclaimableBytes => cacheBytes;
}
