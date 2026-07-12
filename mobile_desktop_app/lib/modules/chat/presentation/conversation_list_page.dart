import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/utils/id_generator.dart';
import '../../../shared/utils/time_format.dart';
import '../data/chat_repository.dart';
import '../domain/conversation.dart';
import 'chat_controller.dart';
import 'chat_page.dart';
import 'conversation_list_controller.dart';
import '../../mailbox/domain/message_transport_coordinator.dart';
import '../../contacts/domain/contact_service.dart';
import '../../presence/domain/presence_service.dart';

/// 聊天室列表畫面（App 首頁）。可建立本機測試聊天室並進入聊天。
class ConversationListPage extends StatefulWidget {
  const ConversationListPage({
    super.key,
    required this.repository,
    required this.ids,
    required this.currentUserId,
    required this.currentDeviceId,
    this.transport,
    this.resolveTargetDevice,
    this.markRead,
    this.syncMailbox,
    this.contactService,
    this.presenceService,
  });

  final ChatRepository repository;
  final IdGenerator ids;
  final String currentUserId;
  final String currentDeviceId;
  final MessageTransportCoordinator? transport;
  final Future<String?> Function(String userId)? resolveTargetDevice;
  final Future<void> Function(String messageId)? markRead;
  final Future<void> Function()? syncMailbox;
  final ContactService? contactService;
  final PresenceService? presenceService;

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  bool _syncing = false;
  late final ConversationListController _controller =
      ConversationListController(
    repository: widget.repository,
    ids: widget.ids,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await widget.syncMailbox?.call();
    } catch (_) {
      // Local chat remains usable while mailbox/backend is unavailable.
    }
    await _controller.load();
  }

  Future<void> _syncMailbox() async {
    if (_syncing || widget.syncMailbox == null) return;
    setState(() => _syncing = true);
    try {
      await widget.syncMailbox!.call();
      await _controller.load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('訊息已同步')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法同步訊息，本機聊天仍可使用')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createConversation() async {
    final count = _controller.conversations.length + 1;
    final conv = await _controller.createLocalConversation('聊天室 $count');
    if (mounted) await _openChat(conv);
  }

  Future<void> _createInvite() async {
    final service = widget.contactService;
    if (service == null) return;
    try {
      final invite = await service.createInvite();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('邀請碼'),
          content: SelectableText(invite.code),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法建立邀請碼')),
        );
      }
    }
  }

  Future<void> _redeemInvite() async {
    final service = widget.contactService;
    if (service == null) return;
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _InviteCodeDialog(),
    );
    if (code == null || code.isEmpty) return;
    try {
      final contact = await service.redeemInvite(code);
      final conversation = await _controller.createContactConversation(
        peerUserId: contact.userId,
        title: contact.displayName,
      );
      if (mounted) await _openChat(conversation);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('邀請碼無效、已使用或金鑰驗證失敗')),
        );
      }
    }
  }

  Future<void> _openChat(Conversation conv) async {
    final peerUserId = conv.peerUserId;
    final targetDeviceId = peerUserId == null
        ? null
        : await widget.resolveTargetDevice?.call(peerUserId);
    if (!mounted) return;
    final chatController = ChatController(
      conversationId: conv.id,
      repository: widget.repository,
      ids: widget.ids,
      currentUserId: widget.currentUserId,
      currentDeviceId: widget.currentDeviceId,
      targetDeviceId: targetDeviceId,
      transport: widget.transport,
      markRead: widget.markRead,
    );
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatPage(controller: chatController, title: conv.title),
    ));
    await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天'),
        actions: [
          IconButton(
            onPressed:
                widget.syncMailbox == null || _syncing ? null : _syncMailbox,
            tooltip: '同步訊息',
            icon: _syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            onPressed: widget.contactService == null ? null : _createInvite,
            tooltip: '建立邀請碼',
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            onPressed: widget.contactService == null ? null : _redeemInvite,
            tooltip: '加入聯絡人',
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          if (widget.presenceService != null) widget.presenceService!,
        ]),
        builder: (context, _) {
          if (_controller.loading && _controller.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = _controller.conversations;
          if (items.isEmpty) {
            return const Center(child: Text('尚無聊天室，點右下角 + 建立'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = items[i];
              return ListTile(
                leading: CircleAvatar(child: Text(c.title.characters.first)),
                title: Text(c.title),
                subtitle: Text(
                  c.peerUserId == null
                      ? c.lastMessagePreview ?? '尚無訊息'
                      : '${widget.presenceService?.labelFor(c.peerUserId!) ?? '離線'}\n${c.lastMessagePreview ?? '尚無訊息'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: c.lastMessageAt == null
                    ? null
                    : Text(formatChatTime(c.lastMessageAt!)),
                onTap: () => unawaited(_openChat(c)),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createConversation,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _InviteCodeDialog extends StatefulWidget {
  const _InviteCodeDialog();

  @override
  State<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<_InviteCodeDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('加入聯絡人'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '邀請碼或 QR 內容'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('加入'),
        ),
      ],
    );
  }
}
