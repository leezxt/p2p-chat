class NotificationPresentation {
  const NotificationPresentation({
    required this.title,
    required this.body,
    required this.redacted,
  });

  final String title;
  final String body;
  final bool redacted;
}

class NotificationPresentationPolicy {
  bool _stateKnown = false;
  bool _appLockEnabled = false;
  bool _appLocked = false;
  bool _hideNotificationContent = true;

  void updateAppLockState({
    required bool enabled,
    required bool locked,
    required bool hideNotificationContent,
  }) {
    _stateKnown = true;
    _appLockEnabled = enabled;
    _appLocked = locked;
    _hideNotificationContent = hideNotificationContent;
  }

  NotificationPresentation resolve({
    required String genericTitle,
    required String genericBody,
    String? localSenderName,
    String? localMessagePreview,
  }) {
    final sender = localSenderName?.trim();
    final preview = localMessagePreview?.trim();
    final mustRedact = !_stateKnown ||
        (_appLockEnabled && (_appLocked || _hideNotificationContent));
    if (mustRedact ||
        sender == null ||
        sender.isEmpty ||
        preview == null ||
        preview.isEmpty) {
      return NotificationPresentation(
        title: genericTitle,
        body: genericBody,
        redacted: true,
      );
    }
    return NotificationPresentation(
      title: sender,
      body: preview,
      redacted: false,
    );
  }
}
