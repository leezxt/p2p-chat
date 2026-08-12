import 'package:sqflite/sqflite.dart';

import '../domain/storage_usage_snapshot.dart';

/// 只管理可重建的快取索引，絕不對聊天、身份或 mailbox queue 執行 delete。
class SqliteStorageRepository {
  SqliteStorageRepository(this._db);

  final Database _db;

  Future<StorageUsageSnapshot> usage() async {
    final databaseBytes = await _databaseBytes();
    final cacheBytes = await _sumBytes('storage_cache_entries', 'byte_size');
    final pendingMailboxBytes = await _pendingMailboxBytes();
    return StorageUsageSnapshot(
      databaseBytes: databaseBytes,
      cacheBytes: cacheBytes,
      // Attachment transport 尚未實作，不能將聊天 payload 誤報為可清理附件。
      attachmentBytes: 0,
      protectedPendingMailboxBytes: pendingMailboxBytes,
    );
  }

  /// 清理範圍刻意只有可重建 cache index，回傳清理前的可回收位元組數。
  Future<int> clearCache() async {
    final bytes = await _sumBytes('storage_cache_entries', 'byte_size');
    await _db.delete('storage_cache_entries');
    return bytes;
  }

  Future<int> _databaseBytes() async {
    final pageCount = Sqflite.firstIntValue(
          await _db.rawQuery('PRAGMA page_count'),
        ) ??
        0;
    final pageSize = Sqflite.firstIntValue(
          await _db.rawQuery('PRAGMA page_size'),
        ) ??
        0;
    return pageCount * pageSize;
  }

  Future<int> _pendingMailboxBytes() async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(LENGTH(encrypted_envelope_json)), 0) AS bytes '
      'FROM mailbox_pending_queue',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> _sumBytes(String table, String column) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM($column), 0) AS bytes FROM $table',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
