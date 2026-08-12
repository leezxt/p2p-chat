import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../l10n/app_localizations.dart';

/// 可替換的 QR scanner，讓 widget tests 與不支援相機的平台保持可驗證。
abstract interface class DesktopLinkQrScanner {
  bool get isSupported;

  Future<String?> scan(BuildContext context);
}

/// 相機只會在使用者按下掃描後建立；Desktop Link module 平時不持有相機資源。
class MobileDesktopLinkQrScanner implements DesktopLinkQrScanner {
  const MobileDesktopLinkQrScanner();

  @override
  bool get isSupported {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        true,
      _ => false,
    };
  }

  @override
  Future<String?> scan(BuildContext context) {
    if (!isSupported) return Future.value();
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _DesktopLinkScannerPage()),
    );
  }
}

class _DesktopLinkScannerPage extends StatefulWidget {
  const _DesktopLinkScannerPage();

  @override
  State<_DesktopLinkScannerPage> createState() =>
      _DesktopLinkScannerPageState();
}

class _DesktopLinkScannerPageState extends State<_DesktopLinkScannerPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _finished = false;

  void _handleDetection(BarcodeCapture capture) {
    if (_finished) return;
    for (final barcode in capture.barcodes) {
      final payload = barcode.rawValue?.trim();
      if (payload == null || payload.isEmpty) continue;
      _finished = true;
      unawaited(_controller.stop());
      Navigator.of(context).pop(payload);
      return;
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.desktopLinkScanQr)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
            errorBuilder: (context, error) => ColoredBox(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.desktopLinkCameraUnavailable,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side =
                    math.min(constraints.maxWidth, constraints.maxHeight) *
                        0.65;
                return Center(
                  child: SizedBox.square(
                    dimension: side,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
