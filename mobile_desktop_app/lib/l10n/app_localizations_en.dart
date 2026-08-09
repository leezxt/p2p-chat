// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Simple Communication';

  @override
  String get chatListTitle => 'Chats';

  @override
  String get syncMessages => 'Sync messages';

  @override
  String get messagesSynced => 'Messages synced';

  @override
  String get syncFailed =>
      'Unable to sync messages. Local chats remain available.';

  @override
  String get createInvite => 'Create invite code';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get close => 'Close';

  @override
  String get inviteCreateFailed => 'Unable to create an invite code';

  @override
  String get addContact => 'Add contact';

  @override
  String get inviteInvalid =>
      'The invite code is invalid, used, or failed key verification';

  @override
  String get noConversations =>
      'No chats yet. Use the add button to create one.';

  @override
  String get noMessages => 'No messages';

  @override
  String get online => 'Online';

  @override
  String get recentlyOnline => 'Recently online';

  @override
  String get offline => 'Offline';

  @override
  String newConversationTitle(int count) {
    return 'Chat $count';
  }

  @override
  String get language => 'Language';

  @override
  String get appTools => 'App tools';

  @override
  String get followSystem => 'Follow system';

  @override
  String get traditionalChinese => 'Traditional Chinese';

  @override
  String get english => 'English';

  @override
  String get newConversation => 'New chat';

  @override
  String get chatEmpty => 'No messages yet. Start the conversation.';

  @override
  String get messageInputHint => 'Type a message';

  @override
  String get sendMessage => 'Send message';

  @override
  String get addReaction => 'Add reaction';

  @override
  String get chooseSticker => 'Choose sticker';

  @override
  String get stickerMessage => 'Sticker message';

  @override
  String toggleReaction(String emoji) {
    return 'Toggle $emoji reaction';
  }

  @override
  String get statusPending => 'Waiting to send';

  @override
  String get statusSent => 'Sent';

  @override
  String get statusStored => 'Stored in offline mailbox';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusRead => 'Read';

  @override
  String get statusFailed => 'Failed to send';

  @override
  String get statusExpired => 'Expired';

  @override
  String unsupportedMessageType(String type) {
    return '[$type]';
  }

  @override
  String get inviteCodeOrQr => 'Invite code or QR content';

  @override
  String get cancel => 'Cancel';

  @override
  String get join => 'Add';

  @override
  String get safetyNumber => 'Safety number';

  @override
  String get safetyNumberUnavailable =>
      'The safety number is currently unavailable';

  @override
  String get safetyNumberVerified => 'Verified';

  @override
  String get safetyNumberNotVerified => 'Not verified';

  @override
  String get safetyNumberQrCode => 'Contact safety number QR code';

  @override
  String get safetyNumberQrData => 'Safety number QR data';

  @override
  String get verifySafetyNumber => 'Verify safety number';

  @override
  String get scanSafetyNumberQr => 'Scan safety number QR';

  @override
  String get safetyNumberCameraUnavailable =>
      'Camera access is unavailable. Check camera permission and try again.';

  @override
  String get compareQrData => 'Compare QR data';

  @override
  String get qrDataMismatch =>
      'Safety numbers do not match. Trust was not changed.';

  @override
  String get verificationSaved => 'Safety number verification saved';

  @override
  String get appLock => 'App lock';

  @override
  String get appLockEnabled => 'App lock is enabled';

  @override
  String get appLockDisabled => 'App lock is disabled';

  @override
  String get appLockSetPin => 'Set a 6-digit PIN';

  @override
  String get appLockEnterPin => '6-digit PIN';

  @override
  String get appLockConfirmPin => 'Confirm PIN';

  @override
  String get appLockPinFormat => 'Enter exactly 6 digits';

  @override
  String get appLockPinMismatch => 'PINs do not match';

  @override
  String get appLockIncorrectPin => 'Incorrect PIN';

  @override
  String get appLockTryAgainLater => 'Too many attempts. Try again later.';

  @override
  String get appLockConfigurationError =>
      'App lock data is unavailable. Reset the app data to recover.';

  @override
  String get appLockUnlock => 'Unlock';

  @override
  String get appLockEnable => 'Enable';

  @override
  String get appLockDisable => 'Disable app lock';

  @override
  String get appLockLockNow => 'Lock now';

  @override
  String get appLockBiometricUnlock => 'Use biometrics';

  @override
  String get appLockBiometricDescription =>
      'Use fingerprint or Face ID to unlock';

  @override
  String get appLockBiometricUnavailable =>
      'No supported biometric method is enrolled';

  @override
  String get appLockBiometricEnableReason =>
      'Confirm your identity to enable biometric unlock';

  @override
  String get appLockBiometricUnlockReason =>
      'Authenticate to unlock Simple Communication';

  @override
  String get appLockBiometricFailed =>
      'Biometric authentication was not completed. Use your PIN.';

  @override
  String get appLockBiometricLockedOut =>
      'Biometrics are locked. Use your PIN.';

  @override
  String get appLockHideNotificationContent => 'Hide notification content';

  @override
  String get appLockHideNotificationDescription =>
      'Use generic text for message notifications';

  @override
  String get lowPowerMode => 'Low power mode';

  @override
  String get lowPowerModeEnabled => 'Low power mode is on';

  @override
  String get lowPowerModeDisabled => 'Low power mode is off';

  @override
  String get lowPowerModeDescription =>
      'Reduces presence updates, P2P connections, idle time, and automatic downloads';

  @override
  String get storageManager => 'Storage manager';

  @override
  String storageTotal(String size) {
    return 'Total local storage: $size';
  }

  @override
  String get storageDatabase => 'Local database';

  @override
  String get storageCache => 'Rebuildable cache';

  @override
  String get storageAttachments => 'Attachments';

  @override
  String get storageProtected => 'Protected data';

  @override
  String storageProtectedDescription(String size) {
    return 'Identity, keys, chats, and unsent mailbox messages ($size) are never included in cleanup.';
  }

  @override
  String get storageClearCache => 'Clear cache';

  @override
  String get storageClearCacheDescription =>
      'Only rebuildable cache is removed. Chats and security data stay on this device.';

  @override
  String storageClearCacheConfirmation(String size) {
    return 'Remove $size of rebuildable cache? This does not delete chats, identity, keys, or unsent messages.';
  }

  @override
  String storageCacheCleared(Object size) {
    return 'Cleared $size of cache';
  }

  @override
  String get smartNotification => 'Chat notifications';

  @override
  String get notificationMute => 'Mute this chat';

  @override
  String get notificationMuteDescription =>
      'Do not create notifications for new messages in this chat';

  @override
  String get notificationPreview => 'Show notification preview';

  @override
  String get notificationPreviewDescription =>
      'Show local sender and message details only when App Lock allows it';

  @override
  String get notificationPrivacyNotice =>
      'Even when enabled, previews stay hidden while App Lock is locked or notification privacy is enabled.';

  @override
  String get translateMessage => 'Translate';

  @override
  String get translationResult => 'Translation';

  @override
  String get translationUnavailable =>
      'No translation provider is configured. Your message has stayed on this device.';

  @override
  String get translationConsentDescription =>
      'Translation may send this message\'s text to the provider you choose in a future setup. The original message will not be changed, and the result is stored only on this device.';

  @override
  String get translationConsentApprove => 'Allow translation';

  @override
  String get clearTranslation => 'Clear translation';

  @override
  String get desktopLink => 'Desktop Link';

  @override
  String get desktopLinkPair => 'Pair a desktop';

  @override
  String get desktopLinkPairDescription =>
      'Scan or paste a short-lived pairing request from your desktop. Review its fingerprint before approving.';

  @override
  String get desktopLinkRequestData => 'Desktop pairing QR content';

  @override
  String get desktopLinkReviewRequest => 'Review pairing request';

  @override
  String get desktopLinkScanQr => 'Scan desktop pairing QR';

  @override
  String get desktopLinkCameraUnavailable =>
      'Camera access is unavailable. Check camera permission and try again.';

  @override
  String get desktopLinkRequestInvalid =>
      'This pairing request is invalid, expired, for another phone, or already handled.';

  @override
  String get desktopLinkRequestReady => 'Pairing request ready for review';

  @override
  String get desktopLinkApproveTitle => 'Approve this desktop link?';

  @override
  String get desktopLinkApproveDescription =>
      'Only approve a device you control. It will be eligible only for new messages created after this approval; existing messages are not copied.';

  @override
  String get desktopLinkDeviceName => 'Device';

  @override
  String get desktopLinkFingerprint => 'Public-key fingerprint';

  @override
  String get desktopLinkKeyBindingNotice =>
      'The QR public key matches this fingerprint, but private-key possession has not been verified yet.';

  @override
  String get desktopLinkApprove => 'Approve link';

  @override
  String get desktopLinkApproved => 'Desktop link approved';

  @override
  String get desktopLinkReject => 'Reject request';

  @override
  String get desktopLinkRejected => 'Pairing request rejected';

  @override
  String get desktopLinkCurrentLinks => 'Linked desktop devices';

  @override
  String get desktopLinkNoLinks => 'No desktop devices are linked';

  @override
  String get desktopLinkRevoke => 'Revoke';

  @override
  String get desktopLinkRevokeTitle => 'Revoke this desktop?';

  @override
  String get desktopLinkRevokeDescription =>
      'New message sync to this device will be rejected immediately. This local action cannot erase data the desktop may already hold.';

  @override
  String get desktopLinkRevoked => 'Revoked';

  @override
  String get desktopLinkRevokedConfirmation => 'Desktop link revoked';
}
