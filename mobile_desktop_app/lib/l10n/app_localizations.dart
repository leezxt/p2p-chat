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
