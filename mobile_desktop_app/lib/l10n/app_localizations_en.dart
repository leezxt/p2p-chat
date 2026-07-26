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
}
