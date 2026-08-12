import 'package:sqflite/sqflite.dart';

import '../domain/desktop_link.dart';

/// Desktop Link 授權狀態的本機 SQLite 儲存。
///
/// 這張表刻意不保存私鑰、聊天室內容或待同步 payload；真正的 per-device
/// 加密與傳輸會由後續 protocol adapter 以此授權狀態為前置條件。
class DesktopLinkRepository {
  DesktopLinkRepository(this._db);

  static const tableName = 'desktop_link_authorizations';

  final Database _db;

  Future<void> save(DesktopLink link) => _db.insert(
        tableName,
        {
          'device_id': link.deviceId,
          'display_name': link.displayName,
          'public_key_fingerprint': link.publicKeyFingerprint,
          'authorized_after': link.authorizedAfter,
          'revoked_at': link.revokedAt,
          'created_at': link.createdAt,
          'updated_at': link.updatedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<DesktopLink?> findByDeviceId(String deviceId) async {
    final rows = await _db.query(
      tableName,
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<List<DesktopLink>> list() async {
    final rows = await _db.query(tableName, orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList(growable: false);
  }

  DesktopLink _fromRow(Map<String, Object?> row) => DesktopLink(
        deviceId: row['device_id']! as String,
        displayName: row['display_name']! as String,
        publicKeyFingerprint: row['public_key_fingerprint']! as String,
        authorizedAfter: row['authorized_after']! as int,
        revokedAt: row['revoked_at'] as int?,
        createdAt: row['created_at']! as int,
        updatedAt: row['updated_at']! as int,
      );
}
