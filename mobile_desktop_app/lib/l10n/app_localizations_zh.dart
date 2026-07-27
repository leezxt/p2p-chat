// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Simple Communication';

  @override
  String get chatListTitle => '聊天';

  @override
  String get syncMessages => '同步訊息';

  @override
  String get messagesSynced => '訊息已同步';

  @override
  String get syncFailed => '無法同步訊息，本機聊天仍可使用';

  @override
  String get createInvite => '建立邀請碼';

  @override
  String get inviteCode => '邀請碼';

  @override
  String get close => '關閉';

  @override
  String get inviteCreateFailed => '無法建立邀請碼';

  @override
  String get addContact => '加入聯絡人';

  @override
  String get inviteInvalid => '邀請碼無效、已使用或金鑰驗證失敗';

  @override
  String get noConversations => '尚無聊天室，請使用新增按鈕建立';

  @override
  String get noMessages => '尚無訊息';

  @override
  String get online => '在線';

  @override
  String get recentlyOnline => '剛剛在線';

  @override
  String get offline => '離線';

  @override
  String newConversationTitle(int count) {
    return '聊天室 $count';
  }

  @override
  String get language => '語言';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get english => '英文';

  @override
  String get newConversation => '新增聊天室';

  @override
  String get chatEmpty => '還沒有訊息，開始聊天吧';

  @override
  String get messageInputHint => '輸入訊息';

  @override
  String get sendMessage => '傳送訊息';

  @override
  String get addReaction => '新增表情回應';

  @override
  String get chooseSticker => '選擇貼圖';

  @override
  String get stickerMessage => '貼圖訊息';

  @override
  String toggleReaction(String emoji) {
    return '切換 $emoji 表情回應';
  }

  @override
  String get statusPending => '等待傳送';

  @override
  String get statusSent => '已傳送';

  @override
  String get statusStored => '已存入離線信箱';

  @override
  String get statusDelivered => '已送達';

  @override
  String get statusRead => '已讀';

  @override
  String get statusFailed => '傳送失敗';

  @override
  String get statusExpired => '已過期';

  @override
  String unsupportedMessageType(String type) {
    return '[$type]';
  }

  @override
  String get inviteCodeOrQr => '邀請碼或 QR 內容';

  @override
  String get cancel => '取消';

  @override
  String get join => '加入';

  @override
  String get safetyNumber => '安全碼';

  @override
  String get safetyNumberUnavailable => '目前無法取得安全碼';

  @override
  String get safetyNumberVerified => '已驗證';

  @override
  String get safetyNumberNotVerified => '尚未驗證';

  @override
  String get safetyNumberQrCode => '聯絡人安全碼 QR Code';

  @override
  String get safetyNumberQrData => '安全碼 QR 內容';

  @override
  String get verifySafetyNumber => '確認安全碼';

  @override
  String get scanSafetyNumberQr => '掃描安全碼 QR';

  @override
  String get safetyNumberCameraUnavailable => '無法使用相機，請檢查相機權限後再試一次';

  @override
  String get compareQrData => '比對 QR 內容';

  @override
  String get qrDataMismatch => '安全碼不一致，未變更信任狀態';

  @override
  String get verificationSaved => '安全碼驗證已保存';

  @override
  String get appLock => '應用程式鎖定';

  @override
  String get appLockEnabled => '應用程式鎖定已啟用';

  @override
  String get appLockDisabled => '應用程式鎖定未啟用';

  @override
  String get appLockSetPin => '設定 6 位數 PIN';

  @override
  String get appLockEnterPin => '6 位數 PIN';

  @override
  String get appLockConfirmPin => '再次輸入 PIN';

  @override
  String get appLockPinFormat => '請輸入剛好 6 位數字';

  @override
  String get appLockPinMismatch => '兩次輸入的 PIN 不一致';

  @override
  String get appLockIncorrectPin => 'PIN 不正確';

  @override
  String get appLockTryAgainLater => '嘗試次數過多，請稍後再試';

  @override
  String get appLockConfigurationError => '無法讀取應用程式鎖定資料，請重設應用程式資料後復原';

  @override
  String get appLockUnlock => '解鎖';

  @override
  String get appLockEnable => '啟用';

  @override
  String get appLockDisable => '停用應用程式鎖定';

  @override
  String get appLockLockNow => '立即鎖定';

  @override
  String get appLockBiometricUnlock => '使用生物辨識';

  @override
  String get appLockBiometricDescription => '使用指紋或 Face ID 解鎖';

  @override
  String get appLockBiometricUnavailable => '裝置未設定支援的生物辨識方式';

  @override
  String get appLockBiometricEnableReason => '請驗證身分以啟用生物辨識解鎖';

  @override
  String get appLockBiometricUnlockReason => '請驗證身分以解鎖 Simple Communication';

  @override
  String get appLockBiometricFailed => '未完成生物辨識，請改用 PIN';

  @override
  String get appLockBiometricLockedOut => '生物辨識已鎖定，請改用 PIN';

  @override
  String get appLockHideNotificationContent => '隱藏通知內容';

  @override
  String get appLockHideNotificationDescription => '訊息通知僅顯示通用文字';

  @override
  String get lowPowerMode => '低功耗模式';

  @override
  String get lowPowerModeEnabled => '低功耗模式已開啟';

  @override
  String get lowPowerModeDisabled => '低功耗模式已關閉';

  @override
  String get lowPowerModeDescription => '降低在線更新、P2P 連線與閒置時間，並停用自動下載';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'Simple Communication';

  @override
  String get chatListTitle => '聊天';

  @override
  String get syncMessages => '同步訊息';

  @override
  String get messagesSynced => '訊息已同步';

  @override
  String get syncFailed => '無法同步訊息，本機聊天仍可使用';

  @override
  String get createInvite => '建立邀請碼';

  @override
  String get inviteCode => '邀請碼';

  @override
  String get close => '關閉';

  @override
  String get inviteCreateFailed => '無法建立邀請碼';

  @override
  String get addContact => '加入聯絡人';

  @override
  String get inviteInvalid => '邀請碼無效、已使用或金鑰驗證失敗';

  @override
  String get noConversations => '尚無聊天室，請使用新增按鈕建立';

  @override
  String get noMessages => '尚無訊息';

  @override
  String get online => '在線';

  @override
  String get recentlyOnline => '剛剛在線';

  @override
  String get offline => '離線';

  @override
  String newConversationTitle(int count) {
    return '聊天室 $count';
  }

  @override
  String get language => '語言';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get english => '英文';

  @override
  String get newConversation => '新增聊天室';

  @override
  String get chatEmpty => '還沒有訊息，開始聊天吧';

  @override
  String get messageInputHint => '輸入訊息';

  @override
  String get sendMessage => '傳送訊息';

  @override
  String get addReaction => '新增表情回應';

  @override
  String get chooseSticker => '選擇貼圖';

  @override
  String get stickerMessage => '貼圖訊息';

  @override
  String toggleReaction(String emoji) {
    return '切換 $emoji 表情回應';
  }

  @override
  String get statusPending => '等待傳送';

  @override
  String get statusSent => '已傳送';

  @override
  String get statusStored => '已存入離線信箱';

  @override
  String get statusDelivered => '已送達';

  @override
  String get statusRead => '已讀';

  @override
  String get statusFailed => '傳送失敗';

  @override
  String get statusExpired => '已過期';

  @override
  String unsupportedMessageType(String type) {
    return '[$type]';
  }

  @override
  String get inviteCodeOrQr => '邀請碼或 QR 內容';

  @override
  String get cancel => '取消';

  @override
  String get join => '加入';

  @override
  String get safetyNumber => '安全碼';

  @override
  String get safetyNumberUnavailable => '目前無法取得安全碼';

  @override
  String get safetyNumberVerified => '已驗證';

  @override
  String get safetyNumberNotVerified => '尚未驗證';

  @override
  String get safetyNumberQrCode => '聯絡人安全碼 QR Code';

  @override
  String get safetyNumberQrData => '安全碼 QR 內容';

  @override
  String get verifySafetyNumber => '確認安全碼';

  @override
  String get scanSafetyNumberQr => '掃描安全碼 QR';

  @override
  String get safetyNumberCameraUnavailable => '無法使用相機，請檢查相機權限後再試一次';

  @override
  String get compareQrData => '比對 QR 內容';

  @override
  String get qrDataMismatch => '安全碼不一致，未變更信任狀態';

  @override
  String get verificationSaved => '安全碼驗證已保存';

  @override
  String get appLock => '應用程式鎖定';

  @override
  String get appLockEnabled => '應用程式鎖定已啟用';

  @override
  String get appLockDisabled => '應用程式鎖定未啟用';

  @override
  String get appLockSetPin => '設定 6 位數 PIN';

  @override
  String get appLockEnterPin => '6 位數 PIN';

  @override
  String get appLockConfirmPin => '再次輸入 PIN';

  @override
  String get appLockPinFormat => '請輸入剛好 6 位數字';

  @override
  String get appLockPinMismatch => '兩次輸入的 PIN 不一致';

  @override
  String get appLockIncorrectPin => 'PIN 不正確';

  @override
  String get appLockTryAgainLater => '嘗試次數過多，請稍後再試';

  @override
  String get appLockConfigurationError => '無法讀取應用程式鎖定資料，請重設應用程式資料後復原';

  @override
  String get appLockUnlock => '解鎖';

  @override
  String get appLockEnable => '啟用';

  @override
  String get appLockDisable => '停用應用程式鎖定';

  @override
  String get appLockLockNow => '立即鎖定';

  @override
  String get appLockBiometricUnlock => '使用生物辨識';

  @override
  String get appLockBiometricDescription => '使用指紋或 Face ID 解鎖';

  @override
  String get appLockBiometricUnavailable => '裝置未設定支援的生物辨識方式';

  @override
  String get appLockBiometricEnableReason => '請驗證身分以啟用生物辨識解鎖';

  @override
  String get appLockBiometricUnlockReason => '請驗證身分以解鎖 Simple Communication';

  @override
  String get appLockBiometricFailed => '未完成生物辨識，請改用 PIN';

  @override
  String get appLockBiometricLockedOut => '生物辨識已鎖定，請改用 PIN';

  @override
  String get appLockHideNotificationContent => '隱藏通知內容';

  @override
  String get appLockHideNotificationDescription => '訊息通知僅顯示通用文字';

  @override
  String get lowPowerMode => '低功耗模式';

  @override
  String get lowPowerModeEnabled => '低功耗模式已開啟';

  @override
  String get lowPowerModeDisabled => '低功耗模式已關閉';

  @override
  String get lowPowerModeDescription => '降低在線更新、P2P 連線與閒置時間，並停用自動下載';
}
