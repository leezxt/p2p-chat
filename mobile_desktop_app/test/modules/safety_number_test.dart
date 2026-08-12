import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/safety_number/domain/safety_number.dart';

void main() {
  final alice = SafetyNumberParticipant(
    userId: 'alice',
    deviceId: 'alice-phone',
    publicKey: Uint8List.fromList(List.generate(32, (index) => index)),
  );
  final bob = SafetyNumberParticipant(
    userId: 'bob',
    deviceId: 'bob-phone',
    publicKey: Uint8List.fromList(List.generate(32, (index) => index + 32)),
  );

  test('both participant orders produce the same 60-digit safety number', () {
    final first = SafetyNumber.generate(local: alice, remote: bob);
    final second = SafetyNumber.generate(local: bob, remote: alice);

    expect(first.digest, second.digest);
    expect(first.displayCode, second.displayCode);
    expect(first.displayGroups, hasLength(12));
    expect(first.displayCode.replaceAll(' ', ''), matches(r'^\d{60}$'));
    expect(first.matchesQrPayload(second.qrPayload), isTrue);
  });

  test('a changed remote key produces a different number', () {
    final original = SafetyNumber.generate(local: alice, remote: bob);
    final changedBob = SafetyNumberParticipant(
      userId: bob.userId,
      deviceId: bob.deviceId,
      publicKey: Uint8List.fromList(List.generate(32, (index) => index + 64)),
    );
    final changed = SafetyNumber.generate(local: alice, remote: changedBob);

    expect(changed.digest, isNot(original.digest));
    expect(changed.matchesQrPayload(original.qrPayload), isFalse);
  });

  test('QR payload rejects tampering, extra fields, and malformed data', () {
    final number = SafetyNumber.generate(local: alice, remote: bob);
    final decoded = jsonDecode(number.qrPayload) as Map<String, dynamic>;

    expect(number.matchesQrPayload('{not-json'), isFalse);
    expect(
      number.matchesQrPayload(jsonEncode({...decoded, 'extra': true})),
      isFalse,
    );
    expect(
      number.matchesQrPayload(jsonEncode({...decoded, 'digest': 'tampered'})),
      isFalse,
    );
  });

  test('participants require distinct ids and 32-byte public keys', () {
    expect(
      () => SafetyNumberParticipant(
        userId: 'alice',
        deviceId: 'bad',
        publicKey: Uint8List(31),
      ),
      throwsArgumentError,
    );
    expect(
      () => SafetyNumber.generate(local: alice, remote: alice),
      throwsArgumentError,
    );
  });
}
