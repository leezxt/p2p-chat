import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../crypto/data/secure_key_value_store.dart';
import 'app_lock_biometric_authenticator.dart';

const _storageKey = 'app_lock_config_v1';
const _version = 1;
const _maxFailedAttempts = 5;
const _lockoutDuration = Duration(seconds: 30);

abstract interface class AppLockPinHasher {
  Future<String> hash(String pin);

  Future<bool> verify(String encodedHash, String pin);
}

enum AppLockUnlockResult {
  success,
  invalidPin,
  lockedOut,
  configurationError,
}

class AppLockService extends ChangeNotifier {
  AppLockService({
    required SecureKeyValueStore store,
    required AppLockPinHasher pinHasher,
    required AppLockBiometricAuthenticator biometricAuthenticator,
    DateTime Function()? now,
  })  : _store = store,
        _pinHasher = pinHasher,
        _biometricAuthenticator = biometricAuthenticator,
        _now = now ?? DateTime.now;

  final SecureKeyValueStore _store;
  final AppLockPinHasher _pinHasher;
  final AppLockBiometricAuthenticator _biometricAuthenticator;
  final DateTime Function() _now;

  _AppLockConfig? _config;
  bool _enabled = false;
  bool _locked = false;
  bool _configurationError = false;

  bool get enabled => _enabled;
  bool get locked => _locked;
  bool get configurationError => _configurationError;
  bool get biometricsEnabled => _config?.biometricsEnabled ?? false;
  bool get hideNotificationContent => _config?.hideNotificationContent ?? true;

  Duration get retryAfter {
    final retryAt = _config?.retryAt;
    if (retryAt == null) return Duration.zero;
    final remaining = retryAt.difference(_now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static bool isValidPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  Future<void> load() async {
    final encoded = await _store.read(_storageKey);
    if (encoded == null) return;
    try {
      _config = _AppLockConfig.fromJson(jsonDecode(encoded));
      _enabled = true;
      _locked = true;
    } catch (_) {
      _enabled = true;
      _locked = true;
      _configurationError = true;
    }
    notifyListeners();
  }

  Future<void> enable(String pin) async {
    if (!isValidPin(pin)) {
      throw const FormatException('App lock PIN must contain exactly 6 digits');
    }
    _config = _AppLockConfig(encodedHash: await _pinHasher.hash(pin));
    await _saveConfig();
    _enabled = true;
    _locked = false;
    _configurationError = false;
    notifyListeners();
  }

  Future<AppLockUnlockResult> unlock(String pin) async {
    final result = await _verify(pin);
    if (result == AppLockUnlockResult.success) {
      _locked = false;
      notifyListeners();
    }
    return result;
  }

  Future<bool> biometricsAvailable() => _biometricAuthenticator.isAvailable();

  Future<void> setHideNotificationContent(bool value) async {
    final config = _config;
    if (!_enabled || _configurationError || config == null) {
      throw StateError('App lock configuration is unavailable');
    }
    if (config.hideNotificationContent == value) return;
    config.hideNotificationContent = value;
    await _saveConfig();
    notifyListeners();
  }

  Future<AppLockBiometricResult> setBiometricsEnabled(
    bool enabled, {
    required String reason,
  }) async {
    final config = _config;
    if (!_enabled || _configurationError || config == null) {
      return AppLockBiometricResult.configurationError;
    }
    if (!enabled) {
      config.biometricsEnabled = false;
      await _saveConfig();
      notifyListeners();
      return AppLockBiometricResult.success;
    }

    final result = await _biometricAuthenticator.authenticate(reason: reason);
    if (result == AppLockBiometricResult.success) {
      config.biometricsEnabled = true;
      await _saveConfig();
      notifyListeners();
    }
    return result;
  }

  Future<AppLockBiometricResult> unlockWithBiometrics({
    required String reason,
  }) async {
    if (!_enabled || !_locked || _configurationError || !biometricsEnabled) {
      return _configurationError
          ? AppLockBiometricResult.configurationError
          : AppLockBiometricResult.unavailable;
    }
    final result = await _biometricAuthenticator.authenticate(reason: reason);
    if (result == AppLockBiometricResult.success) {
      _locked = false;
      notifyListeners();
    }
    return result;
  }

  Future<AppLockUnlockResult> disable(String pin) async {
    final result = await _verify(pin);
    if (result != AppLockUnlockResult.success) return result;
    await _store.delete(_storageKey);
    _config = null;
    _enabled = false;
    _locked = false;
    _configurationError = false;
    notifyListeners();
    return AppLockUnlockResult.success;
  }

  void lock() {
    if (!_enabled || _locked) return;
    _locked = true;
    notifyListeners();
  }

  Future<AppLockUnlockResult> _verify(String pin) async {
    final config = _config;
    if (!_enabled) return AppLockUnlockResult.success;
    if (_configurationError || config == null) {
      return AppLockUnlockResult.configurationError;
    }
    if (config.retryAt case final retryAt? when retryAt.isAfter(_now())) {
      return AppLockUnlockResult.lockedOut;
    }
    if (!isValidPin(pin)) return AppLockUnlockResult.invalidPin;

    if (config.retryAt != null) {
      config.retryAt = null;
      config.failedAttempts = 0;
    }
    if (await _pinHasher.verify(config.encodedHash, pin)) {
      config.failedAttempts = 0;
      config.retryAt = null;
      await _saveConfig();
      return AppLockUnlockResult.success;
    }

    config.failedAttempts++;
    if (config.failedAttempts >= _maxFailedAttempts) {
      config.failedAttempts = 0;
      config.retryAt = _now().add(_lockoutDuration);
      await _saveConfig();
      notifyListeners();
      return AppLockUnlockResult.lockedOut;
    }
    await _saveConfig();
    return AppLockUnlockResult.invalidPin;
  }

  Future<void> _saveConfig() {
    final config = _config;
    if (config == null) throw StateError('App lock configuration is missing');
    return _store.write(_storageKey, jsonEncode(config.toJson()));
  }
}

class _AppLockConfig {
  _AppLockConfig({
    required this.encodedHash,
    this.failedAttempts = 0,
    this.retryAt,
    this.biometricsEnabled = false,
    this.hideNotificationContent = true,
  });

  factory _AppLockConfig.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['version'] != _version ||
        value['encodedHash'] is! String ||
        value['failedAttempts'] is! int) {
      throw const FormatException('Invalid app lock configuration');
    }
    final encodedHash = value['encodedHash'] as String;
    final failedAttempts = value['failedAttempts'] as int;
    final retryAtMs = value['retryAtMs'];
    final biometricsEnabled = value['biometricsEnabled'] ?? false;
    final hideNotificationContent = value['hideNotificationContent'] ?? true;
    if (encodedHash.isEmpty ||
        failedAttempts < 0 ||
        biometricsEnabled is! bool ||
        hideNotificationContent is! bool ||
        (retryAtMs != null && retryAtMs is! int)) {
      throw const FormatException('Invalid app lock configuration');
    }
    return _AppLockConfig(
      encodedHash: encodedHash,
      failedAttempts: failedAttempts,
      retryAt: retryAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(retryAtMs as int),
      biometricsEnabled: biometricsEnabled,
      hideNotificationContent: hideNotificationContent,
    );
  }

  final String encodedHash;
  int failedAttempts;
  DateTime? retryAt;
  bool biometricsEnabled;
  bool hideNotificationContent;

  Map<String, Object?> toJson() => {
        'version': _version,
        'encodedHash': encodedHash,
        'failedAttempts': failedAttempts,
        'retryAtMs': retryAt?.millisecondsSinceEpoch,
        'biometricsEnabled': biometricsEnabled,
        'hideNotificationContent': hideNotificationContent,
      };
}
