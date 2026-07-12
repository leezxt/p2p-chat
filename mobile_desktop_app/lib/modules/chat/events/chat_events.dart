import '../../../core/events/app_event.dart';
import '../../../shared/models/message_envelope.dart';
import '../../../shared/models/message_status.dart';

/// 聊天模組相關事件（規格 §11）。
///
/// 其他模組（P2P / Mailbox / Notification）只透過這些事件與 Chat 互動，
/// 不直接呼叫 Chat 內部（規格 §26 規則 2、4）。

/// 使用者在 UI 要求送出一則訊息。由 Chat 監聽並寫入本機、後續交給傳輸層。
class MessageSendRequested extends AppEvent {
  const MessageSendRequested(this.message);
  final MessageEnvelope message;
}

/// 訊息已寫入本機 DB。
class MessageStored extends AppEvent {
  const MessageStored(this.message);
  final MessageEnvelope message;
}

/// 收到來自對方的訊息（Sprint 5+ 由 P2P / Mailbox 發出）。
class MessageReceived extends AppEvent {
  const MessageReceived(this.message);
  final MessageEnvelope message;
}

/// 訊息狀態變更（規格 §13 狀態機）。
class MessageStatusChanged extends AppEvent {
  const MessageStatusChanged(this.messageId, this.status);
  final String messageId;
  final MessageStatus status;
}
