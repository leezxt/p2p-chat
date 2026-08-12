import '../../push/domain/notification_presentation_policy.dart';
import '../data/sqlite_notification_preference_repository.dart';
import 'notification_preference.dart';

/// 結合 per-chat 偏好與 App Lock 的 provider-neutral 通知決策。
class SmartNotificationService {
  SmartNotificationService({
    required SqliteNotificationPreferenceRepository preferences,
    required NotificationPresentationPolicy presentationPolicy,
  })  : _preferences = preferences,
        _presentationPolicy = presentationPolicy;

  final SqliteNotificationPreferenceRepository _preferences;
  final NotificationPresentationPolicy _presentationPolicy;

  Future<NotificationPreference> preferenceFor(String conversationId) =>
      _preferences.get(conversationId);

  Future<void> savePreference(NotificationPreference preference) =>
      _preferences.save(preference);

  /// `null` 代表聊天已靜音，provider 不應建立通知。
  Future<NotificationPresentation?> resolve({
    required String conversationId,
    required String genericTitle,
    required String genericBody,
    String? localSenderName,
    String? localMessagePreview,
  }) async {
    final preference = await preferenceFor(conversationId);
    if (preference.muted) return null;
    return _presentationPolicy.resolve(
      genericTitle: genericTitle,
      genericBody: genericBody,
      // 預覽須先獲聊天偏好允許，還會再經 App Lock privacy policy 檢查。
      localSenderName: preference.allowPreview ? localSenderName : null,
      localMessagePreview: preference.allowPreview ? localMessagePreview : null,
    );
  }
}
