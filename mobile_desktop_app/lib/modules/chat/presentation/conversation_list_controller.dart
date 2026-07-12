import 'package:flutter/foundation.dart';

import '../../../shared/utils/id_generator.dart';
import '../data/chat_repository.dart';
import '../domain/conversation.dart';

/// 聊天室列表控制器。
class ConversationListController extends ChangeNotifier {
  ConversationListController({
    required ChatRepository repository,
    required IdGenerator ids,
  })  : _repository = repository,
        _ids = ids;

  final ChatRepository _repository;
  final IdGenerator _ids;

  List<Conversation> _conversations = [];
  List<Conversation> get conversations => List.unmodifiable(_conversations);

  bool _loading = false;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _conversations = await _repository.listConversations();
    _loading = false;
    notifyListeners();
  }

  /// 建立一個新的本機聊天室（雛形：用於不連後端時測試）。
  Future<Conversation> createLocalConversation(String title) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final conv = Conversation(
      id: _ids.conversation(),
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.createConversation(conv);
    await load();
    return conv;
  }

  Future<Conversation> createContactConversation({
    required String peerUserId,
    required String title,
  }) async {
    final existing = _conversations
        .where((conversation) => conversation.peerUserId == peerUserId)
        .firstOrNull;
    if (existing != null) return existing;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final conversation = Conversation(
      id: _ids.conversation(),
      title: title,
      peerUserId: peerUserId,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.createConversation(conversation);
    await load();
    return conversation;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
