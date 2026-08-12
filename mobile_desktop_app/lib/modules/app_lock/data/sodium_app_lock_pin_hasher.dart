import 'package:sodium/sodium_sumo.dart';

import '../domain/app_lock_service.dart';

class SodiumAppLockPinHasher implements AppLockPinHasher {
  const SodiumAppLockPinHasher(this._sodium);

  final SodiumSumo _sodium;

  @override
  Future<String> hash(String pin) async => _sodium.crypto.pwhash.str(
        password: pin,
        opsLimit: _sodium.crypto.pwhash.opsLimitInteractive,
        memLimit: _sodium.crypto.pwhash.memLimitInteractive,
      );

  @override
  Future<bool> verify(String encodedHash, String pin) async =>
      _sodium.crypto.pwhash.strVerify(
        passwordHash: encodedHash,
        password: pin,
      );
}
