import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/models/message_envelope.dart';
import '../../../shared/models/message_status.dart';
import '../../../shared/utils/time_format.dart';
import 'chat_controller.dart';
import '../../safety_number/domain/safety_number_service.dart';
import '../../safety_number/presentation/safety_number_page.dart';
import '../../reaction/domain/reaction_event.dart';
import '../../sticker/domain/sticker_pack_manifest.dart';
import '../../smart_notification/domain/smart_notification_service.dart';
import '../../smart_notification/presentation/smart_notification_settings_page.dart';
import '../../translation/domain/translation_result.dart';
import '../../translation/domain/translation_service.dart';

/// 單一聊天室畫面。以 [ChatController] 驅動，支援送出文字與向上載入更舊訊息。
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.controller,
    required this.title,
    this.safetyNumberService,
    this.peerUserId,
    this.smartNotificationService,
    this.translationService,
  });

  final ChatController controller;
  final String title;
  final SafetyNumberService? safetyNumberService;
  final String? peerUserId;
  final SmartNotificationService? smartNotificationService;
  final TranslationService? translationService;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.loadInitial();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels <= 0) {
        widget.controller.loadOlder();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text;
    _inputController.clear();
    await widget.controller.sendText(text);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<void> _translate(MessageEnvelope message) async {
    final service = widget.translationService;
    final sourceText = message.text;
    if (service == null || sourceText == null) return;
    final l10n = AppLocalizations.of(context);
    if (!service.isProviderConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translationUnavailable)),
      );
      return;
    }
    if (!await service.hasConsent()) {
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.translateMessage),
          content: Text(l10n.translationConsentDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.translationConsentApprove),
            ),
          ],
        ),
      );
      if (approved != true) return;
      await service.setConsent(true);
      if (!mounted) return;
    }
    if (!mounted) return;
    try {
      final target =
          Localizations.localeOf(context).languageCode == 'en' ? 'zh-TW' : 'en';
      final result = await service.translate(
        messageId: message.messageId,
        sourceText: sourceText,
        targetLanguage: target,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.translationResult),
          content: SelectableText(result.text),
          actions: [
            TextButton(
              onPressed: () async {
                await service.clearMessageCache(message.messageId);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(l10n.clearTranslation),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    } on TranslationConsentRequired {
      // Consent may be revoked by a future settings surface while dialog is open.
    } on TranslationProviderUnavailable {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translationUnavailable)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.smartNotificationService case final service?)
            IconButton(
              tooltip: AppLocalizations.of(context).smartNotification,
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SmartNotificationSettingsPage(
                    conversationId: widget.controller.conversationId,
                    service: service,
                  ),
                ),
              ),
            ),
          if (widget.safetyNumberService != null && widget.peerUserId != null)
            IconButton(
              tooltip: AppLocalizations.of(context).safetyNumber,
              icon: const Icon(Icons.verified_user_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SafetyNumberPage(
                    title: widget.title,
                    load: () => widget.safetyNumberService!
                        .forContact(widget.peerUserId!),
                    markVerified: widget.safetyNumberService!.markVerified,
                    verifyQrPayload: (payload) => widget.safetyNumberService!
                        .verifyQrPayload(widget.peerUserId!, payload),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final messages = widget.controller.messages;
                if (messages.isEmpty && !widget.controller.loading) {
                  return Center(
                    child: Text(AppLocalizations.of(context).chatEmpty),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _MessageBubble(
                    message: messages[i],
                    mine: widget.controller.isMine(messages[i]),
                    reactions:
                        widget.controller.reactionsFor(messages[i].messageId),
                    sticker: widget.controller.stickerAsset(messages[i]),
                    onReaction: (emoji) =>
                        widget.controller.toggleReaction(messages[i], emoji),
                    onTranslate: widget.translationService == null
                        ? null
                        : () => _translate(messages[i]),
                  ),
                );
              },
            ),
          ),
          _InputBar(
            controller: _inputController,
            onSend: _send,
            stickerPacks: widget.controller.stickerPacks,
            onSticker: widget.controller.sendSticker,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.reactions,
    required this.onReaction,
    this.onTranslate,
    this.sticker,
  });
  final MessageEnvelope message;
  final bool mine;
  final List<ReactionEvent> reactions;
  final Future<void> Function(String emoji) onReaction;
  final Future<void> Function()? onTranslate;
  final StickerAsset? sticker;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final counts = <String, int>{};
    for (final reaction in reactions) {
      counts.update(reaction.emoji, (count) => count + 1, ifAbsent: () => 1);
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showReactionPicker(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color:
                mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sticker != null)
                Image.asset(
                  sticker!.path,
                  width: 128,
                  height: 128,
                  fit: BoxFit.contain,
                  semanticLabel: l10n.stickerMessage,
                )
              else
                Text(
                  message.text ??
                      l10n.unsupportedMessageType(message.type.wire),
                ),
              if (counts.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: counts.entries
                      .map(
                        (entry) => ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text('${entry.key} ${entry.value}'),
                          tooltip: l10n.toggleReaction(entry.key),
                          onPressed: () => onReaction(entry.key),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (onTranslate != null && message.text != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onTranslate,
                    icon: const Icon(Icons.translate, size: 18),
                    label: Text(l10n.translateMessage),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                mine
                    ? '${formatChatTime(context, message.createdAt)} · ${_statusLabel(l10n, message.status)}'
                    : formatChatTime(context, message.createdAt),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReactionPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Semantics(
          label: l10n.addReaction,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.addReaction,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: ReactionEvent.supportedEmoji
                      .map(
                        (value) => IconButton(
                          tooltip: l10n.toggleReaction(value),
                          onPressed: () => Navigator.pop(context, value),
                          icon: Text(
                            value,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (emoji != null) await onReaction(emoji);
  }

  String _statusLabel(AppLocalizations l10n, MessageStatus status) =>
      switch (status) {
        MessageStatus.pending => l10n.statusPending,
        MessageStatus.sent => l10n.statusSent,
        MessageStatus.stored => l10n.statusStored,
        MessageStatus.delivered => l10n.statusDelivered,
        MessageStatus.read => l10n.statusRead,
        MessageStatus.failed => l10n.statusFailed,
        MessageStatus.expired => l10n.statusExpired,
      };
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.stickerPacks,
    required this.onSticker,
  });
  final TextEditingController controller;
  final Future<void> Function() onSend;
  final List<StickerPackManifest> stickerPacks;
  final Future<void> Function(String packId, String stickerId) onSticker;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            IconButton(
              onPressed: stickerPacks.isEmpty
                  ? null
                  : () => _showStickerPicker(context),
              tooltip: l10n.chooseSticker,
              icon: const Icon(Icons.emoji_emotions_outlined),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: l10n.messageInputHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSend,
              tooltip: l10n.sendMessage,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStickerPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<(String, String)>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chooseSticker,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              for (final pack in stickerPacks) ...[
                Text(
                  Localizations.localeOf(context).languageCode == 'en'
                      ? pack.names['en']!
                      : pack.names['zh_TW']!,
                ),
                Wrap(
                  children: pack.stickers
                      .map(
                        (sticker) => IconButton(
                          tooltip: sticker.id,
                          onPressed: () => Navigator.pop(
                            context,
                            (pack.packId, sticker.id),
                          ),
                          icon: Image.asset(
                            sticker.path,
                            width: 48,
                            height: 48,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await onSticker(selected.$1, selected.$2);
    }
  }
}
