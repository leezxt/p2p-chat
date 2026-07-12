class LocalIdentity {
  const LocalIdentity(
      {required this.userId,
      required this.displayName,
      required this.createdAt,
      required this.updatedAt});
  final String userId;
  final String displayName;
  final int createdAt;
  final int updatedAt;
}
