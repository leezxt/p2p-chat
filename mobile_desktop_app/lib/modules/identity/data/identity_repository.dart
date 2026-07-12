import 'package:sqflite/sqflite.dart';
import '../domain/local_identity.dart';
import '../../../shared/utils/id_generator.dart';
import '../domain/identity_session.dart';

class IdentityRepository {
  IdentityRepository(this._db);
  final Database _db;

  Future<LocalIdentity?> getLocalIdentity() async {
    final rows = await _db.query('local_identities', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return LocalIdentity(
        userId: row['user_id']! as String,
        displayName: row['display_name']! as String,
        createdAt: row['created_at']! as int,
        updatedAt: row['updated_at']! as int);
  }

  Future<void> save(LocalIdentity identity) async {
    await _db.insert(
        'local_identities',
        {
          'user_id': identity.userId,
          'display_name': identity.displayName,
          'created_at': identity.createdAt,
          'updated_at': identity.updatedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<IdentitySession> getOrCreateLocalIdentity(IdGenerator ids) async {
    return _db.transaction((txn) async {
      final identities = await txn.query('local_identities', limit: 1);
      if (identities.isNotEmpty) {
        final userId = identities.first['user_id']! as String;
        final devices = await txn.query('devices',
            where: 'user_id = ? AND is_local = 1',
            whereArgs: [userId],
            limit: 1);
        if (devices.isEmpty) throw StateError('本機身份缺少 local device');
        return IdentitySession(
            userId: userId, deviceId: devices.first['id']! as String);
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final userId = ids.raw();
      final deviceId = ids.raw();
      await txn.insert('local_identities', {
        'user_id': userId,
        'display_name': 'New User',
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('devices', {
        'id': deviceId,
        'user_id': userId,
        'name': 'Primary Device',
        'is_local': 1,
        'created_at': now,
        'updated_at': now,
      });
      return IdentitySession(userId: userId, deviceId: deviceId);
    });
  }
}
