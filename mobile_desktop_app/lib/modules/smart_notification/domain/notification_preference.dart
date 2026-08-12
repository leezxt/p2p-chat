class NotificationPreference {
  const NotificationPreference({
    required this.conversationId,
    this.muted = false,
    this.allowPreview = false,
  });

  final String conversationId;
  final bool muted;
  final bool allowPreview;

  NotificationPreference copyWith({bool? muted, bool? allowPreview}) =>
      NotificationPreference(
        conversationId: conversationId,
        muted: muted ?? this.muted,
        allowPreview: allowPreview ?? this.allowPreview,
      );
}
