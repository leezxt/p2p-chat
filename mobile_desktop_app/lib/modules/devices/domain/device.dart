class Device {
  const Device(
      {required this.id,
      required this.userId,
      required this.name,
      this.publicKey,
      this.publicKeyFingerprint,
      required this.isLocal,
      this.revokedAt,
      required this.createdAt,
      required this.updatedAt});
  final String id;
  final String userId;
  final String name;
  final String? publicKey;
  final String? publicKeyFingerprint;
  final bool isLocal;
  final int? revokedAt;
  final int createdAt;
  final int updatedAt;
}
