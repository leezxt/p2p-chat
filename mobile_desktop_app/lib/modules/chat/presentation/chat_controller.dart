import 'package:flutter/foundation.dart';

import '../../../shared/models/message_envelope.dart';
import '../../../shared/models/message_type.dart';
import '../../../shared/utils/id_generator.dart';
import '../data/chat_repository.dart';
import '../../mailbox/domain/message_transport_coordinator.dart';

/// 單一聊天室的 UI 狀態控制器。
///
/// 用 [ChangeNotifier] 保持輕量，不引入額外狀態管理套件（最小依賴原則）。
/// 一次載入最近 [pageSize] 則，向上滑動載入更舊訊息（規格 §21）。
class ChatController extends ChangeNotifier {
  ChatController({
    required this.conversationId,
    required ChatRepository repository,
    required IdGenerator ids,
    required this.currentUserId,
    required this.currentDeviceId,
    this.pageSize = 50,
    this.targetDeviceId,
    this.transport,
    this.markRead,
  })  : _repository = repository,
        _ids = ids;

  final String conversationId;
  final ChatRepository _repository;
  final IdGenerator _ids;
  final String currentUserId;
  final String currentDeviceId;
  final int pageSize;
  final String? targetDeviceId;
  final MessageTransportCoordinator? transport;
  final Future<void> Function(String messageId)? markRead;

  final List<MessageEnvelope> _messages = [];
  List<MessageEnvelope> get messages => List.unmodifiable(_messages);

  bool _loading = false;
  bool get loading => _loading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  /// 首次載入最近一頁。
  Future<void> loadInitial() async {
    _loading = true;
    notifyListeners();
    final page = await _repository.loadRecentMessages(
      conversationId,
      limit: pageSize,
    );
    _messages
      ..clear()
      ..addAll(page);
    final acknowledgeRead = markRead;
    if (acknowledgeRead != null) {
      for (final message in page.where((message) => !isMine(message))) {
        await acknowledgeRead(message.messageId);
      }
    }
    _hasMore = page.length == pageSize;
    _loading = false;
    notifyListeners();
  }

  /// 向上載入更舊訊息（分頁）。
  Future<void> loadOlder() async {
    if (_loading || !_hasMore || _messages.isEmpty) return;
    _loading = true;
    notifyListeners();
    final oldest = _messages.first.createdAt;
    final page = await _repository.loadRecentMessages(
      conversationId,
      limit: pageSize,
      beforeCreatedAt: oldest,
    );
    _messages.insertAll(0, page);
    _hasMore = page.length == pageSize;
    _loading = false;
    notifyListeners();
  }

  /// 送出一則文字訊息（本機寫入；傳輸由後續 Sprint 接手）。
  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final message = MessageEnvelope(
      messageId: _ids.message(),
      conversationId: conversationId,
      senderUserId: currentUserId,
      senderDeviceId: currentDeviceId,
      type: MessageType.text,
      payload: {'text': trimmed},
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    await _repository.saveOutgoingMessage(message);
    final target = targetDeviceId;
    final coordinator = transport;
    if (target != null && coordinator != null) {
      await coordinator.send(target, message);
    }
    _messages.add(message);
    notifyListeners();
  }

  bool isMine(MessageEnvelope message) => message.senderUserId == currentUserId;
}
