import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/crypto/data/secure_key_value_store.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_exceptions.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_service.dart';
import 'package:sodium/sodium.dart';

void main() {
  late Sodium sodium;

  setUpAll(() async {
    sodium = await SodiumInit.init();
  });

  test('首次產生後可從 secure storage 穩定載入同一組裝置金鑰', () async {
    final store = _MemorySecureStore();
    final service = DeviceKeyService(sodium: sodium, store: store);

    final first = await service.getOrCreate('device-a');
    final second = await service.getOrCreate('device-a');

    expect(second.publicKey, orderedEquals(first.publicKey));
    expect(second.secretKey, first.secretKey);
    expect(first.keyId, hasLength(22));
    expect(first.fingerprint.split(' '), hasLength(16));
    expect(first.toString(), contains('secretKey: [REDACTED]'));

    final stored =
        jsonDecode(store.values.values.single) as Map<String, dynamic>;
    expect(first.toString(), isNot(contains(stored['secretKey'] as String)));
    first.dispose();
    second.dispose();
  });

  test('不同裝置產生不同 key id 與 fingerprint', () async {
    final store = _MemorySecureStore();
    final service = DeviceKeyService(sodium: sodium, store: store);
    final first = await service.getOrCreate('device-a');
    final second = await service.getOrCreate('device-b');

    expect(second.keyId, isNot(first.keyId));
    expect(second.fingerprint, isNot(first.fingerprint));
    first.dispose();
    second.dispose();
  });

  test('損壞或版本不支援的 key record 不會靜默重建身份', () async {
    final store = _MemorySecureStore()
      ..values['p2p.crypto.device.device-a.v1'] = jsonEncode({
        'version': 99,
        'publicKey': 'invalid',
        'secretKey': 'invalid',
      });
    final service = DeviceKeyService(sodium: sodium, store: store);

    await expectLater(
      service.getOrCreate('device-a'),
      throwsA(isA<DeviceKeyCorruptedException>()),
    );
    expect(store.writeCount, 0);
  });

  test('secure storage 讀取失敗回傳穩定錯誤碼', () async {
    final store = _MemorySecureStore()..failReads = true;
    final service = DeviceKeyService(sodium: sodium, store: store);

    await expectLater(
      service.getOrCreate('device-a'),
      throwsA(
        isA<DeviceKeyStorageException>().having(
          (error) => error.code,
          'code',
          'KEY_STORAGE_FAILED',
        ),
      ),
    );
  });

  test('secure storage 寫入失敗不回傳未保存的身份', () async {
    final store = _MemorySecureStore()..failWrites = true;
    final service = DeviceKeyService(sodium: sodium, store: store);

    await expectLater(
      service.getOrCreate('device-a'),
      throwsA(isA<DeviceKeyStorageException>()),
    );
    expect(store.values, isEmpty);
  });
}

class _MemorySecureStore implements SecureKeyValueStore {
  final values = <String, String>{};
  bool failReads = false;
  bool failWrites = false;
  int writeCount = 0;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('read failed');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('write failed');
    writeCount += 1;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
