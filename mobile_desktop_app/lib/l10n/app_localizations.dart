import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Simple Communication'**
  String get appTitle;

  /// No description provided for @chatListTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatListTitle;

  /// No description provided for @syncMessages.
  ///
  /// In en, this message translates to:
  /// **'Sync messages'**
  String get syncMessages;

  /// No description provided for @messagesSynced.
  ///
  /// In en, this message translates to:
  /// **'Messages synced'**
  String get messagesSynced;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to sync messages. Local chats remain available.'**
  String get syncFailed;

  /// No description provided for @createInvite.
  ///
  /// In en, this message translates to:
  /// **'Create invite code'**
  String get createInvite;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @inviteCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to create an invite code'**
  String get inviteCreateFailed;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContact;

  /// No description provided for @inviteInvalid.
  ///
  /// In en, this message translates to:
  /// **'The invite code is invalid, used, or failed key verification'**
  String get inviteInvalid;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No chats yet. Use the add button to create one.'**
  String get noConversations;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get noMessages;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @recentlyOnline.
  ///
  /// In en, this message translates to:
  /// **'Recently online'**
  String get recentlyOnline;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @newConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat {count}'**
  String newConversationTitle(int count);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appTools.
  ///
  /// In en, this message translates to:
  /// **'App tools'**
  String get appTools;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @traditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'Traditional Chinese'**
  String get traditionalChinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @newConversation.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newConversation;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Start the conversation.'**
  String get chatEmpty;

  /// No description provided for @messageInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get messageInputHint;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessage;

  /// No description provided for @addReaction.
  ///
  /// In en, this message translates to:
  /// **'Add reaction'**
  String get addReaction;

  /// No description provided for @chooseSticker.
  ///
  /// In en, this message translates to:
  /// **'Choose sticker'**
  String get chooseSticker;

  /// No description provided for @stickerMessage.
  ///
  /// In en, this message translates to:
  /// **'Sticker message'**
  String get stickerMessage;

  /// No description provided for @toggleReaction.
  ///
  /// In en, this message translates to:
  /// **'Toggle {emoji} reaction'**
  String toggleReaction(String emoji);

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get statusPending;

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get statusSent;

  /// No description provided for @statusStored.
  ///
  /// In en, this message translates to:
  /// **'Stored in offline mailbox'**
  String get statusStored;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get statusRead;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send'**
  String get statusFailed;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @unsupportedMessageType.
  ///
  /// In en, this message translates to:
  /// **'[{type}]'**
  String unsupportedMessageType(String type);

  /// No description provided for @inviteCodeOrQr.
  ///
  /// In en, this message translates to:
  /// **'Invite code or QR content'**
  String get inviteCodeOrQr;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get join;

  /// No description provided for @safetyNumber.
  ///
  /// In en, this message translates to:
  /// **'Safety number'**
  String get safetyNumber;

  /// No description provided for @safetyNumberUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The safety number is currently unavailable'**
  String get safetyNumberUnavailable;

  /// No description provided for @safetyNumberVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get safetyNumberVerified;

  /// No description provided for @safetyNumberNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get safetyNumberNotVerified;

  /// No description provided for @safetyNumberQrCode.
  ///
  /// In en, this message translates to:
  /// **'Contact safety number QR code'**
  String get safetyNumberQrCode;

  /// No description provided for @safetyNumberQrData.
  ///
  /// In en, this message translates to:
  /// **'Safety number QR data'**
  String get safetyNumberQrData;

  /// No description provided for @verifySafetyNumber.
  ///
  /// In en, this message translates to:
  /// **'Verify safety number'**
  String get verifySafetyNumber;

  /// No description provided for @scanSafetyNumberQr.
  ///
  /// In en, this message translates to:
  /// **'Scan safety number QR'**
  String get scanSafetyNumberQr;

  /// No description provided for @safetyNumberCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera access is unavailable. Check camera permission and try again.'**
  String get safetyNumberCameraUnavailable;

  /// No description provided for @compareQrData.
  ///
  /// In en, this message translates to:
  /// **'Compare QR data'**
  String get compareQrData;

  /// No description provided for @qrDataMismatch.
  ///
  /// In en, this message translates to:
  /// **'Safety numbers do not match. Trust was not changed.'**
  String get qrDataMismatch;

  /// No description provided for @verificationSaved.
  ///
  /// In en, this message translates to:
  /// **'Safety number verification saved'**
  String get verificationSaved;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLock;

  /// No description provided for @appLockEnabled.
  ///
  /// In en, this message translates to:
  /// **'App lock is enabled'**
  String get appLockEnabled;

  /// No description provided for @appLockDisabled.
  ///
  /// In en, this message translates to:
  /// **'App lock is disabled'**
  String get appLockDisabled;

  /// No description provided for @appLockSetPin.
  ///
  /// In en, this message translates to:
  /// **'Set a 6-digit PIN'**
  String get appLockSetPin;

  /// No description provided for @appLockEnterPin.
  ///
  /// In en, this message translates to:
  /// **'6-digit PIN'**
  String get appLockEnterPin;

  /// No description provided for @appLockConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get appLockConfirmPin;

  /// No description provided for @appLockPinFormat.
  ///
  /// In en, this message translates to:
  /// **'Enter exactly 6 digits'**
  String get appLockPinFormat;

  /// No description provided for @appLockPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get appLockPinMismatch;

  /// No description provided for @appLockIncorrectPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get appLockIncorrectPin;

  /// No description provided for @appLockTryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get appLockTryAgainLater;

  /// No description provided for @appLockConfigurationError.
  ///
  /// In en, this message translates to:
  /// **'App lock data is unavailable. Reset the app data to recover.'**
  String get appLockConfigurationError;

  /// No description provided for @appLockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get appLockUnlock;

  /// No description provided for @appLockEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get appLockEnable;

  /// No description provided for @appLockDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable app lock'**
  String get appLockDisable;

  /// No description provided for @appLockLockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get appLockLockNow;

  /// No description provided for @appLockBiometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get appLockBiometricUnlock;

  /// No description provided for @appLockBiometricDescription.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or Face ID to unlock'**
  String get appLockBiometricDescription;

  /// No description provided for @appLockBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No supported biometric method is enrolled'**
  String get appLockBiometricUnavailable;

  /// No description provided for @appLockBiometricEnableReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm your identity to enable biometric unlock'**
  String get appLockBiometricEnableReason;

  /// No description provided for @appLockBiometricUnlockReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to unlock Simple Communication'**
  String get appLockBiometricUnlockReason;

  /// No description provided for @appLockBiometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication was not completed. Use your PIN.'**
  String get appLockBiometricFailed;

  /// No description provided for @appLockBiometricLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Biometrics are locked. Use your PIN.'**
  String get appLockBiometricLockedOut;

  /// No description provided for @appLockHideNotificationContent.
  ///
  /// In en, this message translates to:
  /// **'Hide notification content'**
  String get appLockHideNotificationContent;

  /// No description provided for @appLockHideNotificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Use generic text for message notifications'**
  String get appLockHideNotificationDescription;

  /// No description provided for @lowPowerMode.
  ///
  /// In en, this message translates to:
  /// **'Low power mode'**
  String get lowPowerMode;

  /// No description provided for @lowPowerModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Low power mode is on'**
  String get lowPowerModeEnabled;

  /// No description provided for @lowPowerModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Low power mode is off'**
  String get lowPowerModeDisabled;

  /// No description provided for @lowPowerModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Reduces presence updates, P2P connections, idle time, and automatic downloads'**
  String get lowPowerModeDescription;

  /// No description provided for @storageManager.
  ///
  /// In en, this message translates to:
  /// **'Storage manager'**
  String get storageManager;

  /// No description provided for @storageTotal.
  ///
  /// In en, this message translates to:
  /// **'Total local storage: {size}'**
  String storageTotal(String size);

  /// No description provided for @storageDatabase.
  ///
  /// In en, this message translates to:
  /// **'Local database'**
  String get storageDatabase;

  /// No description provided for @storageCache.
  ///
  /// In en, this message translates to:
  /// **'Rebuildable cache'**
  String get storageCache;

  /// No description provided for @storageAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get storageAttachments;

  /// No description provided for @storageProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected data'**
  String get storageProtected;

  /// No description provided for @storageProtectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Identity, keys, chats, and unsent mailbox messages ({size}) are never included in cleanup.'**
  String storageProtectedDescription(String size);

  /// No description provided for @storageClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get storageClearCache;

  /// No description provided for @storageClearCacheDescription.
  ///
  /// In en, this message translates to:
  /// **'Only rebuildable cache is removed. Chats and security data stay on this device.'**
  String get storageClearCacheDescription;

  /// No description provided for @storageClearCacheConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Remove {size} of rebuildable cache? This does not delete chats, identity, keys, or unsent messages.'**
  String storageClearCacheConfirmation(String size);

  /// No description provided for @storageCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared {size} of cache'**
  String storageCacheCleared(Object size);

  /// No description provided for @smartNotification.
  ///
  /// In en, this message translates to:
  /// **'Chat notifications'**
  String get smartNotification;

  /// No description provided for @notificationMute.
  ///
  /// In en, this message translates to:
  /// **'Mute this chat'**
  String get notificationMute;

  /// No description provided for @notificationMuteDescription.
  ///
  /// In en, this message translates to:
  /// **'Do not create notifications for new messages in this chat'**
  String get notificationMuteDescription;

  /// No description provided for @notificationPreview.
  ///
  /// In en, this message translates to:
  /// **'Show notification preview'**
  String get notificationPreview;

  /// No description provided for @notificationPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Show local sender and message details only when App Lock allows it'**
  String get notificationPreviewDescription;

  /// No description provided for @notificationPrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'Even when enabled, previews stay hidden while App Lock is locked or notification privacy is enabled.'**
  String get notificationPrivacyNotice;

  /// No description provided for @translateMessage.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translateMessage;

  /// No description provided for @translationResult.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translationResult;

  /// No description provided for @translationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No translation provider is configured. Your message has stayed on this device.'**
  String get translationUnavailable;

  /// No description provided for @translationConsentDescription.
  ///
  /// In en, this message translates to:
  /// **'Translation may send this message\'s text to the provider you choose in a future setup. The original message will not be changed, and the result is stored only on this device.'**
  String get translationConsentDescription;

  /// No description provided for @translationConsentApprove.
  ///
  /// In en, this message translates to:
  /// **'Allow translation'**
  String get translationConsentApprove;

  /// No description provided for @clearTranslation.
  ///
  /// In en, this message translates to:
  /// **'Clear translation'**
  String get clearTranslation;

  /// No description provided for @desktopLink.
  ///
  /// In en, this message translates to:
  /// **'Desktop Link'**
  String get desktopLink;

  /// No description provided for @desktopLinkPair.
  ///
  /// In en, this message translates to:
  /// **'Pair a desktop'**
  String get desktopLinkPair;

  /// No description provided for @desktopLinkPairDescription.
  ///
  /// In en, this message translates to:
  /// **'Scan or paste a short-lived pairing request from your desktop. Review its fingerprint before approving.'**
  String get desktopLinkPairDescription;

  /// No description provided for @desktopLinkPrimaryDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Primary phone device ID'**
  String get desktopLinkPrimaryDeviceId;

  /// No description provided for @desktopLinkPrimaryDeviceIdDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter this identifier in the desktop pairing helper. It is an identifier, not a secret.'**
  String get desktopLinkPrimaryDeviceIdDescription;

  /// No description provided for @desktopLinkCompanionTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up this desktop'**
  String get desktopLinkCompanionTitle;

  /// No description provided for @desktopLinkCompanionDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a short-lived pairing QR for your primary phone. This step does not transfer messages or create a network connection.'**
  String get desktopLinkCompanionDescription;

  /// No description provided for @desktopLinkCompanionPrimaryDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Primary phone device ID'**
  String get desktopLinkCompanionPrimaryDeviceId;

  /// No description provided for @desktopLinkCompanionPrimaryDeviceIdHelp.
  ///
  /// In en, this message translates to:
  /// **'Copy it from the primary phone\'s Desktop Link page.'**
  String get desktopLinkCompanionPrimaryDeviceIdHelp;

  /// No description provided for @desktopLinkCompanionDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Desktop name'**
  String get desktopLinkCompanionDisplayName;

  /// No description provided for @desktopLinkCompanionGenerate.
  ///
  /// In en, this message translates to:
  /// **'Create pairing QR'**
  String get desktopLinkCompanionGenerate;

  /// No description provided for @desktopLinkCompanionRequestReady.
  ///
  /// In en, this message translates to:
  /// **'Pairing QR ready'**
  String get desktopLinkCompanionRequestReady;

  /// No description provided for @desktopLinkCompanionPairingQr.
  ///
  /// In en, this message translates to:
  /// **'Desktop pairing QR code'**
  String get desktopLinkCompanionPairingQr;

  /// No description provided for @desktopLinkCompanionRequestNotice.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR from the primary phone, then paste its encrypted verification challenge below. The QR alone does not grant access.'**
  String get desktopLinkCompanionRequestNotice;

  /// No description provided for @desktopLinkCompanionRequestPayload.
  ///
  /// In en, this message translates to:
  /// **'Pairing request data'**
  String get desktopLinkCompanionRequestPayload;

  /// No description provided for @desktopLinkCompanionPasteChallenge.
  ///
  /// In en, this message translates to:
  /// **'Paste phone verification challenge'**
  String get desktopLinkCompanionPasteChallenge;

  /// No description provided for @desktopLinkCompanionChallengeData.
  ///
  /// In en, this message translates to:
  /// **'Phone verification challenge data'**
  String get desktopLinkCompanionChallengeData;

  /// No description provided for @desktopLinkCompanionCreateResponse.
  ///
  /// In en, this message translates to:
  /// **'Create desktop response'**
  String get desktopLinkCompanionCreateResponse;

  /// No description provided for @desktopLinkCompanionResponseReady.
  ///
  /// In en, this message translates to:
  /// **'Encrypted desktop response ready'**
  String get desktopLinkCompanionResponseReady;

  /// No description provided for @desktopLinkCompanionResponseNotice.
  ///
  /// In en, this message translates to:
  /// **'Return this encrypted response to the primary phone, then complete private-key verification and explicit approval there.'**
  String get desktopLinkCompanionResponseNotice;

  /// No description provided for @desktopLinkCompanionResponsePayload.
  ///
  /// In en, this message translates to:
  /// **'Desktop verification response data'**
  String get desktopLinkCompanionResponsePayload;

  /// No description provided for @desktopLinkCompanionCopyResponse.
  ///
  /// In en, this message translates to:
  /// **'Copy desktop response'**
  String get desktopLinkCompanionCopyResponse;

  /// No description provided for @desktopLinkCompanionResponseCopied.
  ///
  /// In en, this message translates to:
  /// **'Desktop response copied'**
  String get desktopLinkCompanionResponseCopied;

  /// No description provided for @desktopLinkCompanionResponseCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to copy the desktop response'**
  String get desktopLinkCompanionResponseCopyFailed;

  /// No description provided for @desktopLinkCompanionInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid primary phone device ID and desktop name.'**
  String get desktopLinkCompanionInvalidInput;

  /// No description provided for @desktopLinkCompanionChallengeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The phone challenge is invalid, expired, or not intended for this desktop.'**
  String get desktopLinkCompanionChallengeInvalid;

  /// No description provided for @desktopLinkCompanionNoTransport.
  ///
  /// In en, this message translates to:
  /// **'This is a local pairing presentation and manual handoff only. Desktop transport, message sync, and per-device encryption are not implemented.'**
  String get desktopLinkCompanionNoTransport;

  /// No description provided for @desktopLinkRequestData.
  ///
  /// In en, this message translates to:
  /// **'Desktop pairing QR content'**
  String get desktopLinkRequestData;

  /// No description provided for @desktopLinkReviewRequest.
  ///
  /// In en, this message translates to:
  /// **'Review pairing request'**
  String get desktopLinkReviewRequest;

  /// No description provided for @desktopLinkScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan desktop pairing QR'**
  String get desktopLinkScanQr;

  /// No description provided for @desktopLinkCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera access is unavailable. Check camera permission and try again.'**
  String get desktopLinkCameraUnavailable;

  /// No description provided for @desktopLinkRequestInvalid.
  ///
  /// In en, this message translates to:
  /// **'This pairing request is invalid, expired, for another phone, or already handled.'**
  String get desktopLinkRequestInvalid;

  /// No description provided for @desktopLinkRequestReady.
  ///
  /// In en, this message translates to:
  /// **'Pairing request ready for review'**
  String get desktopLinkRequestReady;

  /// No description provided for @desktopLinkApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve this desktop link?'**
  String get desktopLinkApproveTitle;

  /// No description provided for @desktopLinkApproveDescription.
  ///
  /// In en, this message translates to:
  /// **'Only approve a device you control. It will be eligible only for new messages created after this approval; existing messages are not copied.'**
  String get desktopLinkApproveDescription;

  /// No description provided for @desktopLinkDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get desktopLinkDeviceName;

  /// No description provided for @desktopLinkFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Public-key fingerprint'**
  String get desktopLinkFingerprint;

  /// No description provided for @desktopLinkKeyBindingNotice.
  ///
  /// In en, this message translates to:
  /// **'The QR public key matches this fingerprint, but private-key possession has not been verified yet.'**
  String get desktopLinkKeyBindingNotice;

  /// No description provided for @desktopLinkKeyProofStart.
  ///
  /// In en, this message translates to:
  /// **'Verify desktop private key'**
  String get desktopLinkKeyProofStart;

  /// No description provided for @desktopLinkKeyProofDescription.
  ///
  /// In en, this message translates to:
  /// **'Create an encrypted challenge and send it to the desktop. Do not approve the link until its response is verified.'**
  String get desktopLinkKeyProofDescription;

  /// No description provided for @desktopLinkKeyProofChallengeReady.
  ///
  /// In en, this message translates to:
  /// **'Encrypted challenge ready'**
  String get desktopLinkKeyProofChallengeReady;

  /// No description provided for @desktopLinkKeyProofChallengeData.
  ///
  /// In en, this message translates to:
  /// **'Desktop verification challenge data'**
  String get desktopLinkKeyProofChallengeData;

  /// No description provided for @desktopLinkKeyProofPasteResponse.
  ///
  /// In en, this message translates to:
  /// **'Paste desktop verification response'**
  String get desktopLinkKeyProofPasteResponse;

  /// No description provided for @desktopLinkKeyProofResponseData.
  ///
  /// In en, this message translates to:
  /// **'Desktop verification response data'**
  String get desktopLinkKeyProofResponseData;

  /// No description provided for @desktopLinkKeyProofVerified.
  ///
  /// In en, this message translates to:
  /// **'The desktop proved possession of the matching private key. Your explicit approval is still required.'**
  String get desktopLinkKeyProofVerified;

  /// No description provided for @desktopLinkKeyProofRequired.
  ///
  /// In en, this message translates to:
  /// **'Verify the desktop private key before approving this link.'**
  String get desktopLinkKeyProofRequired;

  /// No description provided for @desktopLinkKeyProofInvalid.
  ///
  /// In en, this message translates to:
  /// **'The desktop proof is invalid, expired, or does not match. Create a new challenge.'**
  String get desktopLinkKeyProofInvalid;

  /// No description provided for @desktopLinkApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve link'**
  String get desktopLinkApprove;

  /// No description provided for @desktopLinkApproved.
  ///
  /// In en, this message translates to:
  /// **'Desktop link approved'**
  String get desktopLinkApproved;

  /// No description provided for @desktopLinkReject.
  ///
  /// In en, this message translates to:
  /// **'Reject request'**
  String get desktopLinkReject;

  /// No description provided for @desktopLinkRejected.
  ///
  /// In en, this message translates to:
  /// **'Pairing request rejected'**
  String get desktopLinkRejected;

  /// No description provided for @desktopLinkCurrentLinks.
  ///
  /// In en, this message translates to:
  /// **'Linked desktop devices'**
  String get desktopLinkCurrentLinks;

  /// No description provided for @desktopLinkNoLinks.
  ///
  /// In en, this message translates to:
  /// **'No desktop devices are linked'**
  String get desktopLinkNoLinks;

  /// No description provided for @desktopLinkRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get desktopLinkRevoke;

  /// No description provided for @desktopLinkRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke this desktop?'**
  String get desktopLinkRevokeTitle;

  /// No description provided for @desktopLinkRevokeDescription.
  ///
  /// In en, this message translates to:
  /// **'New message sync to this device will be rejected immediately. This local action cannot erase data the desktop may already hold.'**
  String get desktopLinkRevokeDescription;

  /// No description provided for @desktopLinkRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get desktopLinkRevoked;

  /// No description provided for @desktopLinkRevokedConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Desktop link revoked'**
  String get desktopLinkRevokedConfirmation;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
