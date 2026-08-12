import '../../../core/events/event_bus.dart';
import '../../../shared/models/message_envelope.dart';
import '../../../shared/models/message_status.dart';
import '../../../shared/models/message_type.dart';
import '../domain/conversation.dart';
import '../events/chat_events.dart';
import 'chat_dao.dart';

/// 聊天資料倉儲：封裝 DAO，維護會話與訊息一致性，並發出領域事件。
///
/// 目前（Sprint 2）僅本機讀寫；傳輸（P2P / Mailbox）在 Sprint 5+ 由其他
/// 模組監聽事件接手，Repository 不直接依賴傳輸層。
class ChatRepository {
  ChatRepository(this._dao, this._eventBus);

  final ChatDao _dao;
  final EventBus _eventBus;

  Future<List<Conversation>> listConversations() => _dao.listConversations();

  Future<Conversation?> getConversation(String id) => _dao.getConversation(id);

  Future<void> createConversation(Conversation conversation) =>
      _dao.upsertConversation(conversation);

  Future<List<MessageEnvelope>> loadRecentMessages(
    String conversationId, {
    required int limit,
    int? beforeCreatedAt,
  }) =>
      _dao.loadRecentMessages(
        conversationId,
        limit: limit,
        beforeCreatedAt: beforeCreatedAt,
      );

  /// 寫入一則訊息、更新會話預覽，並發出 [MessageStored]。
  ///
  /// 狀態預設 pending（本機等待送出）；本機雛形階段直接視為 sent。
  Future<void> saveOutgoingMessage(MessageEnvelope message) async {
    final stored = message.copyWith(status: MessageStatus.sent);
    await _dao.insertMessage(stored);
    await _touchConversation(stored);
    _eventBus.emit(MessageStored(stored));
  }

  /// 寫入收到的訊息（Sprint 5+ 用）。
  Future<void> saveIncomingMessage(MessageEnvelope message) async {
    if (await _dao.getConversation(message.conversationId) == null) {
      await _dao.upsertConversation(Conversation(
        id: message.conversationId,
        title: message.senderUserId,
        peerUserId: message.senderUserId,
        createdAt: message.createdAt,
        updatedAt: message.createdAt,
      ));
    }
    await _dao.insertMessage(message);
    await _touchConversation(message);
    _eventBus.emit(MessageStored(message));
  }

  Future<void> updateStatus(String messageId, MessageStatus status) async {
    await _dao.updateMessageStatus(messageId, status);
    _eventBus.emit(MessageStatusChanged(messageId, status));
  }

  /// 更新會話的最後訊息預覽與時間，讓聊天室列表能正確排序。
  Future<void> _touchConversation(MessageEnvelope message) async {
    if (message.type == MessageType.reaction) return;
    final conv = await _dao.getConversation(message.conversationId);
    if (conv == null) return;
    await _dao.upsertConversation(conv.copyWith(
      lastMessagePreview: _preview(message),
      lastMessageAt: message.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ));
  }

  String _preview(MessageEnvelope message) => switch (message.type) {
        MessageType.text => message.text ?? '',
        MessageType.sticker => '[貼圖]',
        MessageType.image => '[圖片]',
        MessageType.voiceMessage => '[語音訊息]',
        MessageType.file => '[檔案]',
        MessageType.callEvent => '[通話]',
        _ => '[訊息]',
      };
}
