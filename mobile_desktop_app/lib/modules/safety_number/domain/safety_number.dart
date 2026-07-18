import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const _schemaVersion = 1;
const _payloadType = 'P2P_SAFETY_NUMBER';
const _domain = 'P2P_SAFETY_NUMBER_V1';

class SafetyNumberParticipant {
  SafetyNumberParticipant({
    required this.userId,
    required this.deviceId,
    required Uint8List publicKey,
  }) : publicKey = Uint8List.fromList(publicKey) {
    if (userId.isEmpty || deviceId.isEmpty || publicKey.length != 32) {
      throw ArgumentError('Safety number participant is invalid');
    }
  }

  final String userId;
  final String deviceId;
  final Uint8List publicKey;

  Map<String, String> get identityJson => {
        'userId': userId,
        'deviceId': deviceId,
      };

  Map<String, String> get canonicalJson => {
        ...identityJson,
        'publicKey': base64UrlEncode(publicKey).replaceAll('=', ''),
      };
}

class SafetyNumber {
  SafetyNumber._({
    required this.participants,
    required this.digest,
    required this.displayGroups,
    required this.qrPayload,
    required this.verified,
    this.verifiedAt,
  });

  factory SafetyNumber.generate({
    required SafetyNumberParticipant local,
    required SafetyNumberParticipant remote,
    bool verified = false,
    DateTime? verifiedAt,
  }) {
    final participants = [local, remote]..sort((a, b) {
        final userOrder = a.userId.compareTo(b.userId);
        return userOrder != 0 ? userOrder : a.deviceId.compareTo(b.deviceId);
      });
    if (participants[0].userId == participants[1].userId &&
        participants[0].deviceId == participants[1].deviceId) {
      throw ArgumentError('Safety number participants must be distinct');
    }

    final canonical = jsonEncode(
      participants.map((participant) => participant.canonicalJson).toList(),
    );
    final digestBytes =
        sha512.convert(utf8.encode('$_domain\u0000$canonical')).bytes;
    final digest = base64UrlEncode(digestBytes).replaceAll('=', '');
    final decimal = _decimalCode(digestBytes);
    final qrPayload = jsonEncode({
      'schemaVersion': _schemaVersion,
      'type': _payloadType,
      'participants':
          participants.map((participant) => participant.identityJson).toList(),
      'digest': digest,
    });

    return SafetyNumber._(
      participants: List.unmodifiable(participants),
      digest: digest,
      displayGroups: List.generate(
        12,
        (index) => decimal.substring(index * 5, (index + 1) * 5),
      ),
      qrPayload: qrPayload,
      verified: verified,
      verifiedAt: verifiedAt,
    );
  }

  final List<SafetyNumberParticipant> participants;
  final String digest;
  final List<String> displayGroups;
  final String qrPayload;
  final bool verified;
  final DateTime? verifiedAt;

  String get displayCode => displayGroups.join(' ');

  bool matchesQrPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 4 ||
          decoded['schemaVersion'] != _schemaVersion ||
          decoded['type'] != _payloadType ||
          decoded['digest'] is! String) {
        return false;
      }
      final payloadParticipants = decoded['participants'];
      if (payloadParticipants is! List || payloadParticipants.length != 2) {
        return false;
      }
      for (var i = 0; i < participants.length; i++) {
        final item = payloadParticipants[i];
        if (item is! Map<String, dynamic> ||
            item.length != 2 ||
            item['userId'] != participants[i].userId ||
            item['deviceId'] != participants[i].deviceId) {
          return false;
        }
      }
      return _constantTimeEquals(decoded['digest'] as String, digest);
    } on FormatException {
      return false;
    }
  }
}

String _decimalCode(List<int> digestBytes) {
  var value = BigInt.zero;
  for (final byte in digestBytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  final modulus = BigInt.from(10).pow(60);
  return (value % modulus).toString().padLeft(60, '0');
}

bool _constantTimeEquals(String left, String right) {
  var difference = left.length ^ right.length;
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final leftCode = i < left.length ? left.codeUnitAt(i) : 0;
    final rightCode = i < right.length ? right.codeUnitAt(i) : 0;
    difference |= leftCode ^ rightCode;
  }
  return difference == 0;
}
