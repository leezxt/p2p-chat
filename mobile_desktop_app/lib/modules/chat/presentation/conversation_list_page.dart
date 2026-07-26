import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../l10n/app_localizations.dart';
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
import '../../safety_number/domain/safety_number_service.dart';
import '../../app_lock/domain/app_lock_service.dart';
import '../../app_lock/presentation/app_lock_settings_page.dart';
import '../../low_power/domain/low_power_mode_service.dart';
import '../../low_power/presentation/low_power_settings_page.dart';
import '../../reaction/data/reaction_repository.dart';

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
    this.safetyNumberService,
    this.appLockService,
    this.lowPowerModeService,
    this.localeController,
    this.reactionRepository,
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
  final SafetyNumberService? safetyNumberService;
  final AppLockService? appLockService;
  final LowPowerModeService? lowPowerModeService;
  final LocaleController? localeController;
  final ReactionRepository? reactionRepository;

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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.messagesSynced)),
        );
      }
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.syncFailed)),
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
    final title = AppLocalizations.of(context).newConversationTitle(count);
    final conv = await _controller.createLocalConversation(title);
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
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.inviteCode),
            content: SelectableText(invite.code),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inviteCreateFailed)),
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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inviteInvalid)),
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
      reactionRepository: widget.reactionRepository,
    );
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatPage(
        controller: chatController,
        title: conv.title,
        safetyNumberService:
            peerUserId == null ? null : widget.safetyNumberService,
        peerUserId: peerUserId,
      ),
    ));
    await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatListTitle),
        actions: [
          IconButton(
            onPressed:
                widget.syncMailbox == null || _syncing ? null : _syncMailbox,
            tooltip: l10n.syncMessages,
            icon: _syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            onPressed: widget.contactService == null ? null : _createInvite,
            tooltip: l10n.createInvite,
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            onPressed: widget.contactService == null ? null : _redeemInvite,
            tooltip: l10n.addContact,
            icon: const Icon(Icons.person_add_alt_1),
          ),
          if (widget.appLockService case final service?)
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AppLockSettingsPage(service: service),
                ),
              ),
              tooltip: l10n.appLock,
              icon: const Icon(Icons.lock_outline),
            ),
          if (widget.lowPowerModeService case final service?)
            AnimatedBuilder(
              animation: service,
              builder: (context, _) => IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LowPowerSettingsPage(service: service),
                  ),
                ),
                tooltip: l10n.lowPowerMode,
                icon: Icon(
                  service.enabled
                      ? Icons.battery_saver
                      : Icons.battery_saver_outlined,
                ),
              ),
            ),
          if (widget.localeController case final controller?)
            PopupMenuButton<AppLanguage>(
              tooltip: l10n.language,
              icon: const Icon(Icons.language),
              initialValue: controller.language,
              onSelected: (language) =>
                  unawaited(controller.setLanguage(language)),
              itemBuilder: (context) => [
                _languageItem(
                  controller,
                  AppLanguage.system,
                  l10n.followSystem,
                ),
                _languageItem(
                  controller,
                  AppLanguage.traditionalChinese,
                  l10n.traditionalChinese,
                ),
                _languageItem(
                  controller,
                  AppLanguage.english,
                  l10n.english,
                ),
              ],
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
            return Center(child: Text(l10n.noConversations));
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
                      ? c.lastMessagePreview ?? l10n.noMessages
                      : '${_presenceLabel(l10n, c.peerUserId!)}\n${c.lastMessagePreview ?? l10n.noMessages}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: c.lastMessageAt == null
                    ? null
                    : Text(formatChatTime(context, c.lastMessageAt!)),
                onTap: () => unawaited(_openChat(c)),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createConversation,
        tooltip: l10n.newConversation,
        child: const Icon(Icons.add),
      ),
    );
  }

  PopupMenuItem<AppLanguage> _languageItem(
    LocaleController controller,
    AppLanguage language,
    String label,
  ) {
    return CheckedPopupMenuItem<AppLanguage>(
      value: language,
      checked: controller.language == language,
      child: Text(label),
    );
  }

  String _presenceLabel(AppLocalizations l10n, String userId) {
    final state = widget.presenceService?.stateFor(userId) ??
        ContactPresenceState.offline;
    return switch (state) {
      ContactPresenceState.online => l10n.online,
      ContactPresenceState.recentlyOnline => l10n.recentlyOnline,
      ContactPresenceState.offline => l10n.offline,
    };
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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addContact),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.inviteCodeOrQr),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.join),
        ),
      ],
    );
  }
}
