class PushNotificationPayload {
  const PushNotificationPayload._();

  static const int currentSchemaVersion = 1;
  static const String mailboxAvailable = 'MAILBOX_AVAILABLE';

  static PushNotificationPayload? tryParse(Map<String, Object?> data) {
    if (data.length != 2) return null;
    final schemaVersion = switch (data['schemaVersion']) {
      final int value => value,
      final String value => int.tryParse(value),
      _ => null,
    };
    if (schemaVersion != currentSchemaVersion ||
        data['type'] != mailboxAvailable) {
      return null;
    }
    return const PushNotificationPayload._();
  }
}
