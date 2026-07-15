// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'P2P 通訊軟體';

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
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'P2P 通訊軟體';

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
}
