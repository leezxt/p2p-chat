import 'push_token_client.dart';

class PushRegistrationService {
  PushRegistrationService(
      {required PushTokenClient client, required this.deviceId})
      : _client = client;

  final PushTokenClient _client;
  final String deviceId;
  String? _registeredToken;
  PushProvider? _registeredProvider;

  Future<void> register(PushProvider provider, String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) throw const FormatException('Push token is empty');
    if (_registeredProvider == provider && _registeredToken == normalized) {
      return;
    }
    await _client.register(
        deviceId: deviceId, provider: provider, token: normalized);
    _registeredProvider = provider;
    _registeredToken = normalized;
  }

  Future<void> revoke(PushProvider provider) async {
    await _client.revoke(deviceId: deviceId, provider: provider);
    if (_registeredProvider == provider) {
      _registeredProvider = null;
      _registeredToken = null;
    }
  }
}
