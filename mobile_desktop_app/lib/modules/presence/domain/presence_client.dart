class ContactPresence {
  const ContactPresence({
    required this.userId,
    required this.deviceId,
    required this.lastSeenAt,
  });

  final String userId;
  final String? deviceId;
  final DateTime? lastSeenAt;
}

abstract class PresenceClient {
  Future<void> heartbeat(String deviceId);
  Future<List<ContactPresence>> fetchContacts();
}
