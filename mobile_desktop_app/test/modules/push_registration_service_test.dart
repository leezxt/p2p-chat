import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/push/domain/push_registration_service.dart';
import 'package:p2p_chat_app/modules/push/domain/push_token_client.dart';

void main() {
  test('token 註冊去重、更新並可撤銷', () async {
    final client = _FakePushClient();
    final service =
        PushRegistrationService(client: client, deviceId: 'device-1');

    await service.register(PushProvider.fcm, ' token-a ');
    await service.register(PushProvider.fcm, 'token-a');
    await service.register(PushProvider.fcm, 'token-b');
    await service.revoke(PushProvider.fcm);

    expect(client.registered, [
      ('device-1', PushProvider.fcm, 'token-a'),
      ('device-1', PushProvider.fcm, 'token-b'),
    ]);
    expect(client.revoked, [('device-1', PushProvider.fcm)]);
  });

  test('拒絕空白 token', () async {
    final service = PushRegistrationService(
      client: _FakePushClient(),
      deviceId: 'device-1',
    );

    await expectLater(
      service.register(PushProvider.fcm, '  '),
      throwsA(isA<FormatException>()),
    );
  });
}

class _FakePushClient implements PushTokenClient {
  final registered = <(String, PushProvider, String)>[];
  final revoked = <(String, PushProvider)>[];

  @override
  Future<void> register({
    required String deviceId,
    required PushProvider provider,
    required String token,
  }) async =>
      registered.add((deviceId, provider, token));

  @override
  Future<void> revoke({
    required String deviceId,
    required PushProvider provider,
  }) async =>
      revoked.add((deviceId, provider));
}
