import 'package:flutter/material.dart';

import '../../../shared/models/message_envelope.dart';
import '../../../shared/models/message_status.dart';
import '../../../shared/utils/time_format.dart';
import 'chat_controller.dart';

/// 單一聊天室畫面。以 [ChatController] 驅動，支援送出文字與向上載入更舊訊息。
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.controller, required this.title});

  final ChatController controller;
  final String title;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final messages = widget.controller.messages;
                if (messages.isEmpty && !widget.controller.loading) {
                  return const Center(child: Text('還沒有訊息，開始聊天吧'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _MessageBubble(
                      message: messages[i],
                      mine: widget.controller.isMine(messages[i])),
                );
              },
            ),
          ),
          _InputBar(controller: _inputController, onSend: _send),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});
  final MessageEnvelope message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
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
            Text(message.text ?? '[${message.type.wire}]'),
            const SizedBox(height: 4),
            Text(
              mine
                  ? '${formatChatTime(message.createdAt)} · ${_statusLabel(message.status)}'
                  : formatChatTime(message.createdAt),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(MessageStatus status) => switch (status) {
        MessageStatus.pending => '等待傳送',
        MessageStatus.sent => '已傳送',
        MessageStatus.stored => '已存入離線信箱',
        MessageStatus.delivered => '已送達',
        MessageStatus.read => '已讀',
        MessageStatus.failed => '傳送失敗',
        MessageStatus.expired => '已過期',
      };
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: '輸入訊息',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: onSend, icon: const Icon(Icons.send)),
          ],
        ),
      ),
    );
  }
}
