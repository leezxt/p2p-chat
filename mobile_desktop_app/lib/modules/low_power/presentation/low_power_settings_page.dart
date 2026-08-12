import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/low_power_mode_service.dart';

class LowPowerSettingsPage extends StatefulWidget {
  const LowPowerSettingsPage({super.key, required this.service});

  final LowPowerModeService service;

  @override
  State<LowPowerSettingsPage> createState() => _LowPowerSettingsPageState();
}

class _LowPowerSettingsPageState extends State<LowPowerSettingsPage> {
  bool _saving = false;

  Future<void> _setEnabled(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.service.setEnabled(value);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lowPowerMode)),
      body: AnimatedBuilder(
        animation: widget.service,
        builder: (context, _) => SwitchListTile(
          secondary: const Icon(Icons.battery_saver),
          title: Text(
            widget.service.enabled
                ? l10n.lowPowerModeEnabled
                : l10n.lowPowerModeDisabled,
          ),
          subtitle: Text(l10n.lowPowerModeDescription),
          value: widget.service.enabled,
          onChanged: _saving ? null : (value) => unawaited(_setEnabled(value)),
        ),
      ),
    );
  }
}
