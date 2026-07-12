import 'dart:io';

import 'package:p2p_chat_app/core/network/http_backend_api.dart';
import 'package:p2p_chat_app/modules/identity/domain/identity_session.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  final backendUrl = Platform.environment['BACKEND_URL'];
  final localDevKey = Platform.environment['LOCAL_DEV_AUTH_KEY'];
  if (backendUrl == null ||
      backendUrl.isEmpty ||
      localDevKey == null ||
      localDevKey.isEmpty) {
    stderr.writeln('BACKEND_URL and LOCAL_DEV_AUTH_KEY are required.');
    exitCode = 64;
    return;
  }

  const ids = Uuid();
  final alice = IdentitySession(userId: ids.v4(), deviceId: ids.v4());
  final bob = IdentitySession(userId: ids.v4(), deviceId: ids.v4());
  final api = HttpBackendApi(baseUrl: backendUrl, localDevKey: localDevKey);

  final aliceAccess = await api.register(
    alice,
    'Alice',
    publicKey: 'test-alice-public-key',
    publicKeyFingerprint: 'test-alice-fingerprint',
  );
  final bobAccess = await api.register(
    bob,
    'Bob',
    publicKey: 'test-bob-public-key',
    publicKeyFingerprint: 'test-bob-fingerprint',
  );
  await api.initializeDeviceKey(
    aliceAccess.token,
    alice.deviceId,
    publicKey: 'test-alice-public-key',
    publicKeyFingerprint: 'test-alice-fingerprint',
  );
  await api.initializeDeviceKey(
    bobAccess.token,
    bob.deviceId,
    publicKey: 'test-bob-public-key',
    publicKeyFingerprint: 'test-bob-fingerprint',
  );
  _require(aliceAccess.token.isNotEmpty,
      'Alice registration returned no access token.');
  _require(
      bobAccess.token.isNotEmpty, 'Bob registration returned no access token.');

  final refreshedAliceAccess = await api.register(
    alice,
    'Alice',
    publicKey: 'test-alice-public-key',
    publicKeyFingerprint: 'test-alice-fingerprint',
  );
  _require(refreshedAliceAccess.token.isNotEmpty,
      'Repeated registration did not refresh the access token.');

  final invite = await api.createInvite(aliceAccess.token);
  final contact = await api.redeemInvite(bobAccess.token, invite.qrPayload);
  _require(contact.userId == alice.userId,
      'Redeemed contact has the wrong user ID.');
  _require(contact.deviceId == alice.deviceId,
      'Redeemed contact has the wrong device ID.');
  _require(contact.displayName == 'Alice',
      'Redeemed contact has the wrong display name.');

  await _requireHttpFailure(
    () => api.redeemInvite(bobAccess.token, invite.code),
    'A redeemed invite code was accepted twice.',
  );
  await _requireHttpFailure(
    () => HttpBackendApi(
            baseUrl: backendUrl, localDevKey: 'invalid-local-dev-key')
        .register(
      IdentitySession(userId: ids.v4(), deviceId: ids.v4()),
      'Unauthorized',
      publicKey: 'test-unauthorized-public-key',
      publicKeyFingerprint: 'test-unauthorized-fingerprint',
    ),
    'An invalid local development key was accepted.',
  );

  stdout.writeln('Live backend integration check passed.');
}

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> _requireHttpFailure(
    Future<Object?> Function() action, String message) async {
  try {
    await action();
  } on HttpException {
    return;
  }
  throw StateError(message);
}
