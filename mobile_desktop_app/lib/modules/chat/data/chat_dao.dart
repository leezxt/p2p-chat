import '../../../shared/models/message_envelope.dart';
import '../../../shared/models/message_status.dart';
import '../domain/conversation.dart';

/// 聊天資料存取介面。
///
/// 抽成介面是為了讓 Repository 與 UI 不綁死 sqflite，
/// 單元測試可注入純記憶體實作（不需 Flutter / sqflite）。
abstract class ChatDao {
  // 會話
  Future<void> upsertConversation(Conversation conversation);
  Future<List<Conversation>> listConversations();
  Future<Conversation?> getConversation(String id);

  // 訊息
  Future<void> insertMessage(MessageEnvelope message);

  /// 載入某會話最近 [limit] 則，可用 [beforeCreatedAt] 分頁載入更舊訊息
  /// （規格 §21：一次載入最近 50 則，滑動載入更舊）。回傳由舊到新排序。
  Future<List<MessageEnvelope>> loadRecentMessages(
    String conversationId, {
    required int limit,
    int? beforeCreatedAt,
  });

  Future<void> updateMessageStatus(String messageId, MessageStatus status);
}
