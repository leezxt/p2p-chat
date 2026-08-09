import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../domain/desktop_link_pairing_exception.dart';
import '../domain/desktop_link_pairing_record.dart';
import '../domain/desktop_link_pairing_request.dart';

/// 保存一次性配對請求的處理狀態，防止同一 QR 在同一主裝置上被重複確認。
class DesktopLinkPairingRepository {
  DesktopLinkPairingRepository(this._db);

  static const tableName = 'desktop_link_pairing_requests';

  final Database _db;

  Future<DesktopLinkPairingRecord?> findByRequestId(String requestId) async {
    final rows = await _db.query(
      tableName,
      where: 'request_id = ?',
      whereArgs: [requestId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<DesktopLinkPairingRecord> prepare(
    DesktopLinkPairingRequest request, {
    required int now,
  }) {
    return _db.transaction((transaction) async {
      final existing = await _find(transaction, request.requestId);
      if (existing == null) {
        final record = DesktopLinkPairingRecord(
          request: request,
          state: DesktopLinkPairingState.pending,
          createdAt: now,
          updatedAt: now,
        );
        await transaction.insert(tableName, _toRow(record));
        return record;
      }
      _ensureMatches(existing, request);
      return switch (existing.state) {
        DesktopLinkPairingState.pending => existing,
        DesktopLinkPairingState.confirming =>
          throw const DesktopLinkPairingInProgress(),
        DesktopLinkPairingState.confirmed ||
        DesktopLinkPairingState.rejected =>
          throw const DesktopLinkPairingAlreadyHandled(),
      };
    });
  }

  Future<DesktopLinkPairingRecord> claimForConfirmation(
    DesktopLinkPairingRequest request, {
    required int now,
  }) {
    return _db.transaction((transaction) async {
      final existing = await _find(transaction, request.requestId);
      if (existing == null) throw const DesktopLinkPairingNotPrepared();
      _ensureMatches(existing, request);
      if (existing.state == DesktopLinkPairingState.confirming) {
        throw const DesktopLinkPairingInProgress();
      }
      if (existing.state == DesktopLinkPairingState.confirmed ||
          existing.state == DesktopLinkPairingState.rejected) {
        throw const DesktopLinkPairingAlreadyHandled();
      }
      final record = DesktopLinkPairingRecord(
        request: existing.request,
        state: DesktopLinkPairingState.confirming,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      await transaction.update(
        tableName,
        _toRow(record),
        where: 'request_id = ? AND state = ?',
        whereArgs: [request.requestId, DesktopLinkPairingState.pending.name],
      );
      return record;
    });
  }

  Future<void> markConfirmed(String requestId, {required int now}) async {
    final count = await _db.update(
      tableName,
      {
        'state': DesktopLinkPairingState.confirmed.name,
        'updated_at': now,
      },
      where: 'request_id = ? AND state = ?',
      whereArgs: [requestId, DesktopLinkPairingState.confirming.name],
    );
    if (count != 1) throw const DesktopLinkPairingNotPrepared();
  }

  Future<void> releaseConfirmation(String requestId, {required int now}) async {
    await _db.update(
      tableName,
      {
        'state': DesktopLinkPairingState.pending.name,
        'updated_at': now,
      },
      where: 'request_id = ? AND state = ?',
      whereArgs: [requestId, DesktopLinkPairingState.confirming.name],
    );
  }

  Future<DesktopLinkPairingRecord> reject(
    DesktopLinkPairingRequest request, {
    required int now,
  }) {
    return _db.transaction((transaction) async {
      final existing = await _find(transaction, request.requestId);
      if (existing == null) throw const DesktopLinkPairingNotPrepared();
      _ensureMatches(existing, request);
      if (existing.state == DesktopLinkPairingState.confirming) {
        throw const DesktopLinkPairingInProgress();
      }
      if (existing.state == DesktopLinkPairingState.confirmed) {
        throw const DesktopLinkPairingAlreadyHandled();
      }
      if (existing.state == DesktopLinkPairingState.rejected) return existing;
      final record = DesktopLinkPairingRecord(
        request: existing.request,
        state: DesktopLinkPairingState.rejected,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      await transaction.update(
        tableName,
        _toRow(record),
        where: 'request_id = ? AND state = ?',
        whereArgs: [request.requestId, DesktopLinkPairingState.pending.name],
      );
      return record;
    });
  }

  Future<DesktopLinkPairingRecord?> _find(
    DatabaseExecutor database,
    String requestId,
  ) async {
    final rows = await database.query(
      tableName,
      where: 'request_id = ?',
      whereArgs: [requestId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  void _ensureMatches(
    DesktopLinkPairingRecord existing,
    DesktopLinkPairingRequest request,
  ) {
    if (!existing.matches(request)) {
      throw const DesktopLinkPairingRequestIdCollision();
    }
  }

  Map<String, Object?> _toRow(DesktopLinkPairingRecord record) => {
        'request_id': record.request.requestId,
        'target_primary_device_id': record.request.targetPrimaryDeviceId,
        'device_id': record.request.deviceId,
        'display_name': record.request.displayName,
        'public_key': record.request.publicKeyBase64Url,
        'public_key_fingerprint': record.request.publicKeyFingerprint,
        'issued_at': record.request.issuedAt,
        'expires_at': record.request.expiresAt,
        'state': record.state.name,
        'created_at': record.createdAt,
        'updated_at': record.updatedAt,
      };

  DesktopLinkPairingRecord _fromRow(Map<String, Object?> row) {
    final request = _requestFromRow(row);
    return DesktopLinkPairingRecord(
      request: request,
      state: DesktopLinkPairingState.values.byName(row['state']! as String),
      createdAt: row['created_at']! as int,
      updatedAt: row['updated_at']! as int,
    );
  }

  DesktopLinkPairingRequest _requestFromRow(Map<String, Object?> row) {
    try {
      final publicKey = _decodePublicKey(row['public_key']);
      final request = DesktopLinkPairingRequest.create(
        requestId: row['request_id']! as String,
        targetPrimaryDeviceId: row['target_primary_device_id']! as String,
        deviceId: row['device_id']! as String,
        displayName: row['display_name']! as String,
        publicKey: publicKey,
        issuedAt: row['issued_at']! as int,
        lifetimeSeconds:
            (row['expires_at']! as int) - (row['issued_at']! as int),
      );
      final storedFingerprint = row['public_key_fingerprint'];
      if (storedFingerprint is! String ||
          request.publicKeyFingerprint != storedFingerprint) {
        throw const DesktopLinkPairingInvalidPayload();
      }
      return request;
    } on DesktopLinkPairingException {
      rethrow;
    } on FormatException {
      throw const DesktopLinkPairingInvalidPayload();
    } on ArgumentError {
      throw const DesktopLinkPairingInvalidPayload();
    } on TypeError {
      throw const DesktopLinkPairingInvalidPayload();
    }
  }

  Uint8List _decodePublicKey(Object? value) {
    if (value is! String || value.isEmpty || value.length > 128) {
      throw const DesktopLinkPairingInvalidPayload();
    }
    final publicKey = base64Url.decode(base64Url.normalize(value));
    if (base64UrlEncode(publicKey).replaceAll('=', '') != value) {
      throw const DesktopLinkPairingInvalidPayload();
    }
    return publicKey;
  }
}
