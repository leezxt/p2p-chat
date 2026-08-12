import 'package:flutter/material.dart';

/// 讓 Desktop Link 的 controller 與 dialog route 同時釋放。
///
/// 手動貼入 pairing request、challenge 與 response 都可使用這個元件；controller 只在
/// dialog route 完全 dispose 後釋放，避免按下確認的 exit animation 仍讀取已釋放 controller。
class DesktopLinkPayloadInputDialog extends StatefulWidget {
  const DesktopLinkPayloadInputDialog({
    super.key,
    required this.title,
    required this.inputLabel,
    required this.cancelLabel,
    required this.submitLabel,
  });

  final String title;
  final String inputLabel;
  final String cancelLabel;
  final String submitLabel;

  @override
  State<DesktopLinkPayloadInputDialog> createState() =>
      _DesktopLinkPayloadInputDialogState();
}

class _DesktopLinkPayloadInputDialogState
    extends State<DesktopLinkPayloadInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(labelText: widget.inputLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: Text(widget.submitLabel),
          ),
        ],
      );
}
