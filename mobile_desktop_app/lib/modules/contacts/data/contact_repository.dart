import 'package:sqflite/sqflite.dart';
import '../domain/contact.dart';

class ContactRepository {
  ContactRepository(this._db);
  final Database _db;

  Future<void> upsert(Contact contact) async {
    await _db.insert(
        'contacts',
        {
          'user_id': contact.userId,
          'display_name': contact.displayName,
          'device_id': contact.deviceId,
          'public_key': contact.publicKey,
          'public_key_fingerprint': contact.publicKeyFingerprint,
          'created_at': contact.createdAt,
          'updated_at': contact.updatedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> list() =>
      _db.query('contacts', orderBy: 'display_name COLLATE NOCASE ASC');

  Future<Contact?> findByDeviceId(String deviceId) async {
    final rows = await _db.query(
      'contacts',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<Contact?> findByUserId(String userId) async {
    final rows = await _db.query(
      'contacts',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Contact _fromRow(Map<String, Object?> row) => Contact(
        userId: row['user_id'] as String,
        displayName: row['display_name'] as String,
        deviceId: row['device_id'] as String?,
        publicKey: row['public_key'] as String?,
        publicKeyFingerprint: row['public_key_fingerprint'] as String?,
        createdAt: row['created_at'] as int,
        updatedAt: row['updated_at'] as int,
      );
}
