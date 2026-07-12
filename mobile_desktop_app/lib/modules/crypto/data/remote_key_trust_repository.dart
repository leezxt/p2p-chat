import 'package:sqflite/sqflite.dart';

import '../domain/remote_key_trust.dart';

class RemoteKeyTrustRepository {
  RemoteKeyTrustRepository(this._db);

  final Database _db;

  Future<RemoteKeyTrust?> find(String deviceId) async {
    final rows = await _db.query(
      'remote_key_trust',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<RemoteKeyObservation> observe({
    required String deviceId,
    required String publicKey,
    required String fingerprint,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'remote_key_trust',
        where: 'device_id = ?',
        whereArgs: [deviceId],
        limit: 1,
      );
      if (rows.isEmpty) {
        await txn.insert('remote_key_trust', {
          'device_id': deviceId,
          'trusted_public_key': publicKey,
          'trusted_fingerprint': fingerprint,
          'trusted_at': now,
          'updated_at': now,
        });
        return RemoteKeyObservation.firstTrusted;
      }

      final current = _fromRow(rows.single);
      if (current.trustedPublicKey == publicKey &&
          current.trustedFingerprint == fingerprint) {
        return RemoteKeyObservation.unchanged;
      }

      await txn.update(
        'remote_key_trust',
        {
          'pending_public_key': publicKey,
          'pending_fingerprint': fingerprint,
          'changed_at': now,
          'updated_at': now,
        },
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );
      return RemoteKeyObservation.changePending;
    });
  }

  Future<RemoteKeyTrust> trustPending(String deviceId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'remote_key_trust',
        where: 'device_id = ?',
        whereArgs: [deviceId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Remote key trust unavailable');
      final current = _fromRow(rows.single);
      if (!current.hasPendingChange) {
        throw StateError('No pending remote key change');
      }
      await txn.update(
        'remote_key_trust',
        {
          'trusted_public_key': current.pendingPublicKey,
          'trusted_fingerprint': current.pendingFingerprint,
          'pending_public_key': null,
          'pending_fingerprint': null,
          'changed_at': null,
          'trusted_at': now,
          'updated_at': now,
        },
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );
      return RemoteKeyTrust(
        deviceId: deviceId,
        trustedPublicKey: current.pendingPublicKey!,
        trustedFingerprint: current.pendingFingerprint!,
      );
    });
  }

  RemoteKeyTrust _fromRow(Map<String, Object?> row) => RemoteKeyTrust(
        deviceId: row['device_id'] as String,
        trustedPublicKey: row['trusted_public_key'] as String,
        trustedFingerprint: row['trusted_fingerprint'] as String,
        pendingPublicKey: row['pending_public_key'] as String?,
        pendingFingerprint: row['pending_fingerprint'] as String?,
      );
}
