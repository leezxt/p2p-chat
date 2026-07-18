import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/app_lock_biometric_authenticator.dart';
import '../domain/app_lock_service.dart';

class AppLockSettingsPage extends StatefulWidget {
  const AppLockSettingsPage({super.key, required this.service});

  final AppLockService service;

  @override
  State<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends State<AppLockSettingsPage> {
  late final Future<bool> _biometricsAvailable;

  AppLockService get service => widget.service;

  @override
  void initState() {
    super.initState();
    _biometricsAvailable = service.biometricsAvailable();
  }

  Future<void> _enable(BuildContext context) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _CreatePinDialog(),
    );
    if (pin == null || !context.mounted) return;
    await service.enable(pin);
  }

  Future<void> _disable(BuildContext context) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _EnterPinDialog(),
    );
    if (pin == null || !context.mounted) return;
    final result = await service.disable(pin);
    if (!context.mounted || result == AppLockUnlockResult.success) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == AppLockUnlockResult.lockedOut
              ? l10n.appLockTryAgainLater
              : l10n.appLockIncorrectPin,
        ),
      ),
    );
  }

  Future<void> _setBiometrics(BuildContext context, bool enabled) async {
    final l10n = AppLocalizations.of(context);
    final result = await service.setBiometricsEnabled(
      enabled,
      reason: l10n.appLockBiometricEnableReason,
    );
    if (!context.mounted || result == AppLockBiometricResult.success) return;
    final message = switch (result) {
      AppLockBiometricResult.unavailable ||
      AppLockBiometricResult.notEnrolled =>
        l10n.appLockBiometricUnavailable,
      AppLockBiometricResult.lockedOut => l10n.appLockBiometricLockedOut,
      AppLockBiometricResult.configurationError =>
        l10n.appLockConfigurationError,
      AppLockBiometricResult.cancelled ||
      AppLockBiometricResult.failed =>
        l10n.appLockBiometricFailed,
      AppLockBiometricResult.success => '',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appLock)),
      body: AnimatedBuilder(
        animation: service,
        builder: (context, _) => ListView(
          children: [
            SwitchListTile(
              key: const Key('app-lock-enabled-switch'),
              secondary: const Icon(Icons.lock_outline),
              title: Text(l10n.appLock),
              subtitle: Text(
                service.enabled ? l10n.appLockEnabled : l10n.appLockDisabled,
              ),
              value: service.enabled,
              onChanged: service.configurationError
                  ? null
                  : (enabled) => enabled ? _enable(context) : _disable(context),
            ),
            if (service.enabled)
              FutureBuilder<bool>(
                future: _biometricsAvailable,
                builder: (context, snapshot) {
                  final available = snapshot.data ?? false;
                  return SwitchListTile(
                    key: const Key('app-lock-biometric-switch'),
                    secondary: const Icon(Icons.fingerprint),
                    title: Text(l10n.appLockBiometricUnlock),
                    subtitle: Text(
                      available
                          ? l10n.appLockBiometricDescription
                          : l10n.appLockBiometricUnavailable,
                    ),
                    value: service.biometricsEnabled,
                    onChanged: available || service.biometricsEnabled
                        ? (enabled) => _setBiometrics(context, enabled)
                        : null,
                  );
                },
              ),
            if (service.enabled)
              SwitchListTile(
                key: const Key('app-lock-notification-privacy-switch'),
                secondary: const Icon(Icons.notifications_off_outlined),
                title: Text(l10n.appLockHideNotificationContent),
                subtitle: Text(l10n.appLockHideNotificationDescription),
                value: service.hideNotificationContent,
                onChanged: service.configurationError
                    ? null
                    : (value) => service.setHideNotificationContent(value),
              ),
            if (service.enabled)
              ListTile(
                leading: const Icon(Icons.lock_clock_outlined),
                title: Text(l10n.appLockLockNow),
                onTap: () {
                  service.lock();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CreatePinDialog extends StatefulWidget {
  const _CreatePinDialog();

  @override
  State<_CreatePinDialog> createState() => _CreatePinDialogState();
}

class _CreatePinDialogState extends State<_CreatePinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (!AppLockService.isValidPin(_pin.text)) {
      setState(() => _error = l10n.appLockPinFormat);
      return;
    }
    if (_pin.text != _confirm.text) {
      setState(() => _error = l10n.appLockPinMismatch);
      return;
    }
    Navigator.pop(context, _pin.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.appLockSetPin),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PinField(controller: _pin, label: l10n.appLockEnterPin),
          const SizedBox(height: 8),
          _PinField(
            controller: _confirm,
            label: l10n.appLockConfirmPin,
            errorText: _error,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.appLockEnable),
        ),
      ],
    );
  }
}

class _EnterPinDialog extends StatefulWidget {
  const _EnterPinDialog();

  @override
  State<_EnterPinDialog> createState() => _EnterPinDialogState();
}

class _EnterPinDialogState extends State<_EnterPinDialog> {
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.appLockDisable),
      content: _PinField(
        controller: _pin,
        label: l10n.appLockEnterPin,
        onSubmitted: (_) => Navigator.pop(context, _pin.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _pin.text),
          child: Text(l10n.appLockDisable),
        ),
      ],
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    this.errorText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, errorText: errorText),
        onSubmitted: onSubmitted,
      );
}
