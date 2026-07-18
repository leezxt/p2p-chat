abstract interface class LowPowerPreferenceStore {
  Future<bool?> read();

  Future<void> write(bool enabled);
}
