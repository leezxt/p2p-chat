import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/safety_number.dart';
import 'safety_number_qr_scanner.dart';

class SafetyNumberPage extends StatefulWidget {
  const SafetyNumberPage({
    super.key,
    required this.title,
    required this.load,
    required this.markVerified,
    required this.verifyQrPayload,
    this.qrScanner = const MobileSafetyNumberQrScanner(),
  });

  final String title;
  final Future<SafetyNumber> Function() load;
  final Future<void> Function(SafetyNumber safetyNumber) markVerified;
  final Future<bool> Function(String payload) verifyQrPayload;
  final SafetyNumberQrScanner qrScanner;

  @override
  State<SafetyNumberPage> createState() => _SafetyNumberPageState();
}

class _SafetyNumberPageState extends State<SafetyNumberPage> {
  late Future<SafetyNumber> _number = widget.load();

  void _reload() {
    setState(() {
      _number = widget.load();
    });
  }

  Future<void> _markVerified(SafetyNumber number) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.verifySafetyNumber),
        content: SelectableText(number.displayCode),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.verifySafetyNumber),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.markVerified(number);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.verificationSaved)),
    );
  }

  Future<void> _compareQrPayload() async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final payload = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.compareQrData),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.safetyNumberQrData),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.compareQrData),
          ),
        ],
      ),
    );
    controller.dispose();
    if (payload == null || payload.isEmpty) return;
    await _verifyQrPayload(payload);
  }

  Future<void> _scanQrPayload() async {
    final payload = await widget.qrScanner.scan(context);
    if (!mounted || payload == null || payload.isEmpty) return;
    await _verifyQrPayload(payload);
  }

  Future<void> _verifyQrPayload(String payload) async {
    final l10n = AppLocalizations.of(context);
    final matched = await widget.verifyQrPayload(payload);
    if (!mounted) return;
    if (matched) _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          matched ? l10n.verificationSaved : l10n.qrDataMismatch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyNumber)),
      body: FutureBuilder<SafetyNumber>(
        future: _number,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text(l10n.safetyNumberUnavailable));
          }
          final number = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    number.verified
                        ? Icons.verified_user
                        : Icons.gpp_maybe_outlined,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    number.verified
                        ? l10n.safetyNumberVerified
                        : l10n.safetyNumberNotVerified,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: QrImageView(
                  data: number.qrPayload,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
                  semanticsLabel: l10n.safetyNumberQrCode,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: number.displayGroups
                    .map(
                      (group) => SelectableText(
                        group,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontFeatures: const []),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: number.verified ? null : () => _markVerified(number),
                icon: const Icon(Icons.verified_outlined),
                label: Text(l10n.verifySafetyNumber),
              ),
              const SizedBox(height: 12),
              if (widget.qrScanner.isSupported) ...[
                OutlinedButton.icon(
                  onPressed: _scanQrPayload,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n.scanSafetyNumberQr),
                ),
                const SizedBox(height: 12),
              ],
              TextButton.icon(
                onPressed: _compareQrPayload,
                icon: const Icon(Icons.content_paste),
                label: Text(l10n.compareQrData),
              ),
            ],
          );
        },
      ),
    );
  }
}
