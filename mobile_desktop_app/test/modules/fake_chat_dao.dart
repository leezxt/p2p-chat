import 'package:p2p_chat_app/modules/chat/data/chat_dao.dart';
import 'package:p2p_chat_app/modules/chat/domain/conversation.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_status.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';

/// 純記憶體 [ChatDao]，供 Repository / Controller 單元測試使用，
/// 不需 Flutter binding 或 sqflite。
class FakeChatDao implements ChatDao {
  final Map<String, Conversation> conversations = {};
  final List<MessageEnvelope> messages = [];

  @override
  Future<void> upsertConversation(Conversation conversation) async {
    conversations[conversation.id] = conversation;
  }

  @override
  Future<List<Conversation>> listConversations() async {
    final list = conversations.values.toList()
      ..sort((a, b) => (b.lastMessageAt ?? b.updatedAt)
          .compareTo(a.lastMessageAt ?? a.updatedAt));
    return list;
  }

  @override
  Future<Conversation?> getConversation(String id) async => conversations[id];

  @override
  Future<void> insertMessage(MessageEnvelope message) async {
    if (messages.any((item) => item.messageId == message.messageId)) return;
    messages.add(message);
  }

  @override
  Future<List<MessageEnvelope>> loadRecentMessages(
    String conversationId, {
    required int limit,
    int? beforeCreatedAt,
  }) async {
    final filtered = messages
        .where((m) => m.conversationId == conversationId)
        .where((m) => m.type != MessageType.reaction)
        .where((m) => beforeCreatedAt == null || m.createdAt < beforeCreatedAt)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    // 取最新 limit 則，回傳由舊到新。
    final start = filtered.length > limit ? filtered.length - limit : 0;
    return filtered.sublist(start);
  }

  @override
  Future<void> updateMessageStatus(
      String messageId, MessageStatus status) async {
    final i = messages.indexWhere((m) => m.messageId == messageId);
    if (i >= 0) messages[i] = messages[i].copyWith(status: status);
  }
}
