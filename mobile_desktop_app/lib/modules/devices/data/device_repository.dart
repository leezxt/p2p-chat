import 'package:sqflite/sqflite.dart';
import '../domain/device.dart';

class DeviceRepository {
  DeviceRepository(this._db);
  final Database _db;

  Future<void> upsert(Device device) async {
    await _db.insert(
        'devices',
        {
          'id': device.id,
          'user_id': device.userId,
          'name': device.name,
          'public_key': device.publicKey,
          'public_key_fingerprint': device.publicKeyFingerprint,
          'is_local': device.isLocal ? 1 : 0,
          'revoked_at': device.revokedAt,
          'created_at': device.createdAt,
          'updated_at': device.updatedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> listForUser(String userId) =>
      _db.query('devices',
          where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at ASC');

  Future<Device?> findById(String id) async {
    final rows = await _db.query(
      'devices',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Device _fromRow(Map<String, Object?> row) => Device(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        name: row['name'] as String,
        publicKey: row['public_key'] as String?,
        publicKeyFingerprint: row['public_key_fingerprint'] as String?,
        isLocal: row['is_local'] == 1,
        revokedAt: row['revoked_at'] as int?,
        createdAt: row['created_at'] as int,
        updatedAt: row['updated_at'] as int,
      );
}
