class NotificationLaunch {
  const NotificationLaunch({required this.launchId, required this.data});

  /// Provider message ID or another process-local unique delivery ID.
  final String launchId;
  final Map<String, Object?> data;
}

abstract interface class NotificationLaunchSource {
  Future<NotificationLaunch?> initialLaunch();

  Stream<NotificationLaunch> get launches;
}

/// Used until a platform push adapter is configured with real credentials.
class NoopNotificationLaunchSource implements NotificationLaunchSource {
  const NoopNotificationLaunchSource();

  @override
  Future<NotificationLaunch?> initialLaunch() async => null;

  @override
  Stream<NotificationLaunch> get launches => const Stream.empty();
}
