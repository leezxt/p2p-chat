import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/desktop_link_companion_service.dart';
import '../domain/desktop_link_key_possession.dart';
import '../domain/desktop_link_pairing_exception.dart';
import '../domain/desktop_link_pairing_request.dart';
import 'desktop_link_payload_input_dialog.dart';

/// 桌面副端的短效 pairing QR 與手動 challenge responder 畫面。
///
/// 這不是同步頁面：它沒有 P2P、mailbox、背景 timer 或訊息資料庫存取。畫面只持有目前
/// request／encrypted response 的可顯示 payload；challenge token 由 domain responder 在回應後
/// 清除，最終授權仍必須在手機主端完成。
class DesktopLinkCompanionPage extends StatefulWidget {
  const DesktopLinkCompanionPage({
    super.key,
    required this.companionService,
    this.initialDisplayName = 'Desktop',
  });

  final DesktopLinkCompanionActions companionService;
  final String initialDisplayName;

  @override
  State<DesktopLinkCompanionPage> createState() =>
      _DesktopLinkCompanionPageState();
}

class _DesktopLinkCompanionPageState extends State<DesktopLinkCompanionPage> {
  late final _primaryDeviceIdController = TextEditingController();
  late final _displayNameController = TextEditingController(
    text: widget.initialDisplayName,
  );
  DesktopLinkPairingRequest? _request;
  DesktopLinkKeyPossessionResponse? _response;
  bool _submitting = false;

  @override
  void dispose() {
    _primaryDeviceIdController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _issueRequest() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final request = widget.companionService.issuePairingRequest(
        targetPrimaryDeviceId: _primaryDeviceIdController.text,
        displayName: _displayNameController.text,
      );
      if (!mounted) return;
      setState(() {
        _request = request;
        _response = null;
      });
      _showMessage(
          AppLocalizations.of(context).desktopLinkCompanionRequestReady);
    } on DesktopLinkPairingException {
      _showMessage(
          AppLocalizations.of(context).desktopLinkCompanionInvalidInput);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pasteChallenge() async {
    if (_submitting || _request == null) return;
    final l10n = AppLocalizations.of(context);
    final payload = await showDialog<String>(
      context: context,
      builder: (_) => DesktopLinkPayloadInputDialog(
        title: l10n.desktopLinkCompanionPasteChallenge,
        inputLabel: l10n.desktopLinkCompanionChallengeData,
        cancelLabel: l10n.cancel,
        submitLabel: l10n.desktopLinkCompanionCreateResponse,
      ),
    );
    if (!mounted || payload == null || payload.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final response =
          widget.companionService.respondToChallengePayload(payload);
      if (!mounted) return;
      setState(() => _response = response);
      _showMessage(l10n.desktopLinkCompanionResponseReady);
    } on DesktopLinkPairingException {
      _showMessage(l10n.desktopLinkCompanionChallengeInvalid);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _copyResponse() async {
    final response = _response;
    if (response == null) return;
    final l10n = AppLocalizations.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: response.toPayload()));
      if (mounted) _showMessage(l10n.desktopLinkCompanionResponseCopied);
    } catch (_) {
      if (mounted) _showMessage(l10n.desktopLinkCompanionResponseCopyFailed);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final request = _request;
    final response = _response;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.desktopLinkCompanionTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                l10n.desktopLinkCompanionTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l10n.desktopLinkCompanionDescription),
              const SizedBox(height: 24),
              TextField(
                controller: _primaryDeviceIdController,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: l10n.desktopLinkCompanionPrimaryDeviceId,
                  helperText: l10n.desktopLinkCompanionPrimaryDeviceIdHelp,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _displayNameController,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: l10n.desktopLinkCompanionDisplayName,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submitting ? null : _issueRequest,
                icon: const Icon(Icons.qr_code_2_outlined),
                label: Text(l10n.desktopLinkCompanionGenerate),
              ),
              if (request != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.desktopLinkCompanionRequestReady,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: QrImageView(
                            data: request.toQrPayload(),
                            size: 248,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(color: Colors.black),
                            dataModuleStyle:
                                const QrDataModuleStyle(color: Colors.black),
                            semanticsLabel: l10n.desktopLinkCompanionPairingQr,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.desktopLinkCompanionRequestNotice),
                        const SizedBox(height: 16),
                        Text(
                          l10n.desktopLinkCompanionRequestPayload,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        _PayloadBox(payload: request.toQrPayload()),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _submitting ? null : _pasteChallenge,
                          icon: const Icon(Icons.content_paste),
                          label: Text(
                            l10n.desktopLinkCompanionPasteChallenge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (response != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.desktopLinkCompanionResponseReady,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(l10n.desktopLinkCompanionResponseNotice),
                        const SizedBox(height: 16),
                        Text(
                          l10n.desktopLinkCompanionResponsePayload,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        _PayloadBox(payload: response.toPayload()),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _copyResponse,
                          icon: const Icon(Icons.copy_outlined),
                          label: Text(l10n.desktopLinkCompanionCopyResponse),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                l10n.desktopLinkCompanionNoTransport,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayloadBox extends StatelessWidget {
  const _PayloadBox({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 112,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: SelectableText(payload),
          ),
        ),
      );
}
