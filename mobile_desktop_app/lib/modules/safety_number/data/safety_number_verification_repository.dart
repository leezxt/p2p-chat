import 'package:sqflite/sqflite.dart';

class SafetyNumberVerification {
  const SafetyNumberVerification({
    required this.digest,
    required this.verifiedAt,
  });

  final String digest;
  final DateTime verifiedAt;
}

class SafetyNumberVerificationRepository {
  SafetyNumberVerificationRepository(this._db);

  final Database _db;

  Future<SafetyNumberVerification?> find(String remoteDeviceId) async {
    final rows = await _db.query(
      'safety_number_verifications',
      where: 'remote_device_id = ?',
      whereArgs: [remoteDeviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return SafetyNumberVerification(
      digest: row['digest'] as String,
      verifiedAt:
          DateTime.fromMillisecondsSinceEpoch(row['verified_at'] as int),
    );
  }

  Future<void> save({
    required String remoteDeviceId,
    required String digest,
    DateTime? verifiedAt,
  }) async {
    final timestamp = (verifiedAt ?? DateTime.now()).millisecondsSinceEpoch;
    await _db.insert(
      'safety_number_verifications',
      {
        'remote_device_id': remoteDeviceId,
        'digest': digest,
        'verified_at': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
