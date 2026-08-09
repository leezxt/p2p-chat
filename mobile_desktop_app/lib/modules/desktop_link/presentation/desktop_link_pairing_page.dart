import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/desktop_link.dart';
import '../domain/desktop_link_pairing_exception.dart';
import '../domain/desktop_link_pairing_request.dart';
import '../domain/desktop_link_pairing_service.dart';
import '../domain/desktop_link_service.dart';
import 'desktop_link_qr_scanner.dart';

/// 手機主裝置的 Desktop Link 管理與明確配對確認畫面。
class DesktopLinkPairingPage extends StatefulWidget {
  const DesktopLinkPairingPage({
    super.key,
    required this.pairingService,
    required this.desktopLinkService,
    this.qrScanner = const MobileDesktopLinkQrScanner(),
  });

  final DesktopLinkPairingActions pairingService;
  final DesktopLinkManager desktopLinkService;
  final DesktopLinkQrScanner qrScanner;

  @override
  State<DesktopLinkPairingPage> createState() => _DesktopLinkPairingPageState();
}

class _DesktopLinkPairingPageState extends State<DesktopLinkPairingPage> {
  late Future<List<DesktopLink>> _links = widget.desktopLinkService.listLinks();
  DesktopLinkPairingRequest? _preparedRequest;
  bool _submitting = false;

  void _reloadLinks() {
    setState(() {
      _links = widget.desktopLinkService.listLinks();
    });
  }

  Future<void> _pasteRequest() async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final payload = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.desktopLinkPair),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(labelText: l10n.desktopLinkRequestData),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.desktopLinkReviewRequest),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || payload == null || payload.isEmpty) return;
    await _prepare(payload);
  }

  Future<void> _scanRequest() async {
    final payload = await widget.qrScanner.scan(context);
    if (!mounted || payload == null || payload.isEmpty) return;
    await _prepare(payload);
  }

  Future<void> _prepare(String payload) async {
    try {
      final request = await widget.pairingService.prepareQrPayload(payload);
      if (!mounted) return;
      setState(() => _preparedRequest = request);
    } on DesktopLinkPairingException {
      _showMessage(AppLocalizations.of(context).desktopLinkRequestInvalid);
    }
  }

  Future<void> _confirmPreparedRequest() async {
    final request = _preparedRequest;
    if (request == null || _submitting) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.desktopLinkApproveTitle),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(l10n.desktopLinkApproveDescription),
              const SizedBox(height: 16),
              Text('${l10n.desktopLinkDeviceName}: ${request.displayName}'),
              const SizedBox(height: 8),
              Text(l10n.desktopLinkFingerprint),
              SelectableText(request.publicKeyFingerprint),
              const SizedBox(height: 8),
              Text(
                l10n.desktopLinkKeyBindingNotice,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.desktopLinkApprove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await widget.pairingService.confirm(request);
      if (!mounted) return;
      setState(() => _preparedRequest = null);
      _reloadLinks();
      _showMessage(l10n.desktopLinkApproved);
    } on DesktopLinkPairingException {
      _showMessage(l10n.desktopLinkRequestInvalid);
    } on DesktopLinkException {
      _showMessage(l10n.desktopLinkRequestInvalid);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _rejectPreparedRequest() async {
    final request = _preparedRequest;
    if (request == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.pairingService.reject(request);
      if (!mounted) return;
      setState(() => _preparedRequest = null);
      _showMessage(AppLocalizations.of(context).desktopLinkRejected);
    } on DesktopLinkPairingException {
      _showMessage(AppLocalizations.of(context).desktopLinkRequestInvalid);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _revoke(DesktopLink link) async {
    if (!link.isActive || _submitting) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.desktopLinkRevokeTitle),
        content: Text(l10n.desktopLinkRevokeDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.desktopLinkRevoke),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await widget.desktopLinkService.revoke(link.deviceId);
      if (!mounted) return;
      _reloadLinks();
      _showMessage(l10n.desktopLinkRevokedConfirmation);
    } on DesktopLinkException {
      _showMessage(l10n.desktopLinkRequestInvalid);
    } finally {
      if (mounted) setState(() => _submitting = false);
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.desktopLink)),
      body: FutureBuilder<List<DesktopLink>>(
        future: _links,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final links = snapshot.data ?? const <DesktopLink>[];
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                l10n.desktopLinkPair,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l10n.desktopLinkPairDescription),
              const SizedBox(height: 16),
              if (widget.qrScanner.isSupported) ...[
                FilledButton.icon(
                  onPressed: _submitting ? null : _scanRequest,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n.desktopLinkScanQr),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pasteRequest,
                icon: const Icon(Icons.content_paste),
                label: Text(l10n.desktopLinkReviewRequest),
              ),
              if (_preparedRequest case final request?) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.desktopLinkRequestReady,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${l10n.desktopLinkDeviceName}: ${request.displayName}',
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.desktopLinkFingerprint),
                        SelectableText(request.publicKeyFingerprint),
                        const SizedBox(height: 8),
                        Text(
                          l10n.desktopLinkKeyBindingNotice,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed:
                                  _submitting ? null : _confirmPreparedRequest,
                              icon: const Icon(Icons.verified_outlined),
                              label: Text(l10n.desktopLinkApprove),
                            ),
                            TextButton(
                              onPressed:
                                  _submitting ? null : _rejectPreparedRequest,
                              child: Text(l10n.desktopLinkReject),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Text(
                l10n.desktopLinkCurrentLinks,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (links.isEmpty)
                Text(l10n.desktopLinkNoLinks)
              else
                ...links.map(
                  (link) => Card(
                    child: ListTile(
                      leading: Icon(
                        link.isActive
                            ? Icons.devices_other_outlined
                            : Icons.link_off_outlined,
                      ),
                      title: Text(link.displayName),
                      subtitle: SelectableText(link.publicKeyFingerprint),
                      trailing: link.isActive
                          ? TextButton(
                              onPressed:
                                  _submitting ? null : () => _revoke(link),
                              child: Text(l10n.desktopLinkRevoke),
                            )
                          : Text(l10n.desktopLinkRevoked),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
