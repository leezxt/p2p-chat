import '../../../core/events/app_event.dart';

enum RemoteKeyObservation { firstTrusted, unchanged, changePending }

class RemoteKeyTrust {
  const RemoteKeyTrust({
    required this.deviceId,
    required this.trustedPublicKey,
    required this.trustedFingerprint,
    this.pendingPublicKey,
    this.pendingFingerprint,
  });

  final String deviceId;
  final String trustedPublicKey;
  final String trustedFingerprint;
  final String? pendingPublicKey;
  final String? pendingFingerprint;

  bool get hasPendingChange =>
      pendingPublicKey != null && pendingFingerprint != null;
}

class RemoteDeviceKeyChanged extends AppEvent {
  const RemoteDeviceKeyChanged({
    required this.deviceId,
    required this.trustedFingerprint,
    required this.pendingFingerprint,
  });

  final String deviceId;
  final String trustedFingerprint;
  final String pendingFingerprint;
}

class RemoteKeyChangeException implements Exception {
  const RemoteKeyChangeException(this.deviceId);

  final String deviceId;

  @override
  String toString() => 'RemoteKeyChangeException(deviceId: $deviceId)';
}
