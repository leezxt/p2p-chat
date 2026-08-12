import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/models/message_envelope.dart';
import '../../../shared/models/message_type.dart';
import '../../../shared/utils/id_generator.dart';
import '../data/chat_repository.dart';
import '../../mailbox/domain/message_transport_coordinator.dart';
import '../../reaction/data/reaction_repository.dart';
import '../../reaction/domain/reaction_event.dart';
import '../../sticker/data/built_in_sticker_catalog.dart';
import '../../sticker/domain/sticker_message.dart';
import '../../sticker/domain/sticker_pack_manifest.dart';

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
    this.reactionRepository,
    this.stickerCatalog,
  })  : _repository = repository,
        _ids = ids {
    _reactionSubscription = reactionRepository?.changes.listen((messageId) {
      if (_messages.any((message) => message.messageId == messageId)) {
        unawaited(_refreshReaction(messageId));
      }
    });
  }

  final String conversationId;
  final ChatRepository _repository;
  final IdGenerator _ids;
  final String currentUserId;
  final String currentDeviceId;
  final int pageSize;
  final String? targetDeviceId;
  final MessageTransportCoordinator? transport;
  final Future<void> Function(String messageId)? markRead;
  final ReactionRepository? reactionRepository;
  final BuiltInStickerCatalog? stickerCatalog;

  final List<MessageEnvelope> _messages = [];
  final Map<String, List<ReactionEvent>> _reactions = {};
  StreamSubscription<String>? _reactionSubscription;
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
    await _loadReactions(page);
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
    await _loadReactions(page);
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

  List<StickerPackManifest> get stickerPacks =>
      stickerCatalog?.packs ?? const [];

  StickerAsset? stickerAsset(MessageEnvelope message) {
    final catalog = stickerCatalog;
    if (catalog == null || message.type != MessageType.sticker) return null;
    try {
      final sticker = StickerMessage.fromEnvelope(message);
      return catalog.resolve(sticker.packId, sticker.stickerId);
    } on FormatException {
      return null;
    }
  }

  Future<void> sendSticker(String packId, String stickerId) async {
    if (stickerCatalog?.resolve(packId, stickerId) == null) return;
    final message =
        StickerMessage(packId: packId, stickerId: stickerId).toEnvelope(
      messageId: _ids.message(),
      conversationId: conversationId,
      senderUserId: currentUserId,
      senderDeviceId: currentDeviceId,
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

  List<ReactionEvent> reactionsFor(String messageId) =>
      List.unmodifiable(_reactions[messageId] ?? const []);

  Future<void> toggleReaction(MessageEnvelope target, String emoji) async {
    final repository = reactionRepository;
    if (repository == null ||
        !ReactionEvent.supportedEmoji.contains(emoji) ||
        !_messages.any((message) => message.messageId == target.messageId)) {
      return;
    }
    final current = reactionsFor(target.messageId);
    final existing = current.where(
      (reaction) =>
          reaction.reactorUserId == currentUserId && reaction.emoji == emoji,
    );
    final active = existing.isEmpty;
    final clock = DateTime.now().millisecondsSinceEpoch;
    final previousAt = existing.isEmpty ? -1 : existing.first.updatedAt;
    final now = clock > previousAt ? clock : previousAt + 1;
    final event = ReactionEvent(
      eventId: _ids.message(),
      targetMessageId: target.messageId,
      reactorUserId: currentUserId,
      emoji: emoji,
      active: active,
      updatedAt: now,
    );
    final envelope = event.toEnvelope(
      conversationId: conversationId,
      senderDeviceId: currentDeviceId,
    );
    await repository.apply(event);
    await _repository.saveOutgoingMessage(envelope);
    final targetDevice = targetDeviceId;
    final coordinator = transport;
    if (targetDevice != null && coordinator != null) {
      await coordinator.send(targetDevice, envelope);
    }
    await _loadReactions([target]);
    notifyListeners();
  }

  Future<void> _loadReactions(Iterable<MessageEnvelope> messages) async {
    final repository = reactionRepository;
    if (repository == null) return;
    for (final message in messages) {
      _reactions[message.messageId] =
          await repository.listActiveForMessage(message.messageId);
    }
  }

  Future<void> _refreshReaction(String messageId) async {
    final repository = reactionRepository;
    if (repository == null) return;
    _reactions[messageId] = await repository.listActiveForMessage(messageId);
    notifyListeners();
  }

  bool isMine(MessageEnvelope message) => message.senderUserId == currentUserId;

  @override
  void dispose() {
    _reactionSubscription?.cancel();
    super.dispose();
  }
}
