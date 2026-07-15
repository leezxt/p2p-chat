abstract interface class LocalePreferenceStore {
  Future<String?> read();
  Future<void> write(String value);
}
