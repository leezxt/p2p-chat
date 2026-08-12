import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/app_lock_biometric_authenticator.dart';
import '../domain/app_lock_service.dart';

class AppLockGate extends StatelessWidget {
  const AppLockGate({
    super.key,
    required this.service,
    required this.child,
  });

  final AppLockService service;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: service,
        child: child,
        builder: (context, child) {
          if (!service.enabled || !service.locked) return child!;
          return _UnlockView(service: service);
        },
      );
}

class _UnlockView extends StatefulWidget {
  const _UnlockView({required this.service});

  final AppLockService service;

  @override
  State<_UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends State<_UnlockView> {
  final _pinController = TextEditingController();
  bool _submitting = false;
  bool _biometricSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.service.biometricsEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _unlockWithBiometrics();
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_submitting || _biometricSubmitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.service.unlock(_pinController.text);
    if (!mounted || result == AppLockUnlockResult.success) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _submitting = false;
      _pinController.clear();
      _error = switch (result) {
        AppLockUnlockResult.invalidPin => l10n.appLockIncorrectPin,
        AppLockUnlockResult.lockedOut => l10n.appLockTryAgainLater,
        AppLockUnlockResult.configurationError =>
          l10n.appLockConfigurationError,
        AppLockUnlockResult.success => null,
      };
    });
  }

  Future<void> _unlockWithBiometrics() async {
    if (_submitting || _biometricSubmitting) return;
    setState(() {
      _biometricSubmitting = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context);
    final result = await widget.service.unlockWithBiometrics(
      reason: l10n.appLockBiometricUnlockReason,
    );
    if (!mounted || result == AppLockBiometricResult.success) return;
    setState(() {
      _biometricSubmitting = false;
      _error = switch (result) {
        AppLockBiometricResult.cancelled => null,
        AppLockBiometricResult.unavailable ||
        AppLockBiometricResult.notEnrolled =>
          l10n.appLockBiometricUnavailable,
        AppLockBiometricResult.lockedOut => l10n.appLockBiometricLockedOut,
        AppLockBiometricResult.failed => l10n.appLockBiometricFailed,
        AppLockBiometricResult.configurationError =>
          l10n.appLockConfigurationError,
        AppLockBiometricResult.success => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final disabled = _submitting ||
        _biometricSubmitting ||
        widget.service.configurationError;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    l10n.appLock,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pinController,
                    enabled: !disabled,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.appLockEnterPin,
                      errorText: widget.service.configurationError
                          ? l10n.appLockConfigurationError
                          : _error,
                    ),
                    onSubmitted: (_) => _unlock(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: disabled ? null : _unlock,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open),
                      label: Text(l10n.appLockUnlock),
                    ),
                  ),
                  if (widget.service.biometricsEnabled) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('app-lock-biometric-button'),
                        onPressed: disabled ? null : _unlockWithBiometrics,
                        icon: _biometricSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.fingerprint),
                        label: Text(l10n.appLockBiometricUnlock),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
