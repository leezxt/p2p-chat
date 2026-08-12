import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/notification_preference.dart';
import '../domain/smart_notification_service.dart';

class SmartNotificationSettingsPage extends StatefulWidget {
  const SmartNotificationSettingsPage({
    super.key,
    required this.conversationId,
    required this.service,
  });

  final String conversationId;
  final SmartNotificationService service;

  @override
  State<SmartNotificationSettingsPage> createState() =>
      _SmartNotificationSettingsPageState();
}

class _SmartNotificationSettingsPageState
    extends State<SmartNotificationSettingsPage> {
  NotificationPreference? _preference;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preference =
        await widget.service.preferenceFor(widget.conversationId);
    if (mounted) setState(() => _preference = preference);
  }

  Future<void> _update(NotificationPreference next) async {
    setState(() => _preference = next);
    try {
      await widget.service.savePreference(next);
    } catch (_) {
      if (mounted) await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preference = _preference;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.smartNotification)),
      body: preference == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: Text(l10n.notificationMute),
                  subtitle: Text(l10n.notificationMuteDescription),
                  value: preference.muted,
                  onChanged: (value) =>
                      _update(preference.copyWith(muted: value)),
                ),
                SwitchListTile(
                  title: Text(l10n.notificationPreview),
                  subtitle: Text(l10n.notificationPreviewDescription),
                  value: preference.allowPreview,
                  onChanged: preference.muted
                      ? null
                      : (value) => _update(
                            preference.copyWith(allowPreview: value),
                          ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.notificationPrivacyNotice),
                ),
              ],
            ),
    );
  }
}
