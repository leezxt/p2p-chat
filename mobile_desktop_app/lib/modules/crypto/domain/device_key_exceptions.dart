class DeviceKeyException implements Exception {
  const DeviceKeyException(this.code, [this.cause]);

  final String code;
  final Object? cause;

  @override
  String toString() => 'DeviceKeyException($code)';
}

class DeviceKeyStorageException extends DeviceKeyException {
  const DeviceKeyStorageException([Object? cause])
      : super('KEY_STORAGE_FAILED', cause);
}

class DeviceKeyCorruptedException extends DeviceKeyException {
  const DeviceKeyCorruptedException([Object? cause])
      : super('KEY_MATERIAL_CORRUPTED', cause);
}
