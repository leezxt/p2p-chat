class Contact {
  const Contact(
      {required this.userId,
      required this.displayName,
      this.deviceId,
      this.publicKey,
      this.publicKeyFingerprint,
      required this.createdAt,
      required this.updatedAt});
  final String userId;
  final String displayName;
  final String? deviceId;
  final String? publicKey;
  final String? publicKeyFingerprint;
  final int createdAt;
  final int updatedAt;
}
