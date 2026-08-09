import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_fingerprint.dart';
import 'package:p2p_chat_app/modules/crypto/domain/device_key_material.dart';
import 'package:p2p_chat_app/modules/crypto/domain/message_box.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_companion_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_key_possession.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_request.dart';
import 'package:p2p_chat_app/modules/desktop_link/presentation/desktop_link_companion_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sodium/sodium.dart';

const _verifyClipboard =
    bool.fromEnvironment('VERIFY_CLIPBOARD', defaultValue: false);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Desktop Companion renders QR and completes a real sodium challenge response',
    (tester) async {
      final sodium = await SodiumInit.init();
      final primaryPair = sodium.crypto.box.keyPair();
      final desktopPair = sodium.crypto.box.keyPair();
      final primaryKey = DeviceKeyMaterial(
        publicKey: primaryPair.publicKey,
        secretKey: primaryPair.secretKey.copy(),
        keyId: 'desktop-runtime-primary-key',
        fingerprint: computeDeviceKeyFingerprint(
          'primary-phone-runtime',
          primaryPair.publicKey,
        ),
      );
      final desktopKey = DeviceKeyMaterial(
        publicKey: desktopPair.publicKey,
        secretKey: desktopPair.secretKey.copy(),
        keyId: 'desktop-runtime-companion-key',
        fingerprint: computeDeviceKeyFingerprint(
          'desktop-windows-runtime',
          desktopPair.publicKey,
        ),
      );
      primaryPair.dispose();
      desktopPair.dispose();

      final primary = DesktopLinkKeyPossessionService(
        box: SodiumMessageBox(sodium),
        primaryKey: primaryKey,
        primaryDeviceId: 'primary-phone-runtime',
      );
      final actions = _RecordingCompanionActions(
        DesktopLinkCompanionService(
          box: SodiumMessageBox(sodium),
          desktopKey: desktopKey,
          desktopDeviceId: 'desktop-windows-runtime',
        ),
      );

      try {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DesktopLinkCompanionPage(companionService: actions),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Primary phone device ID'),
          'primary-phone-runtime',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Desktop name'),
          'Windows native runtime',
        );
        await tester
            .tap(find.widgetWithText(FilledButton, 'Create pairing QR'));
        await tester.pumpAndSettle();

        final request = actions.lastRequest;
        expect(request, isNotNull);
        expect(request!.publicKey, orderedEquals(desktopKey.publicKey));
        expect(find.byType(QrImageView), findsOneWidget);

        final challenge = primary.createChallenge(request);
        final pasteChallenge = find.widgetWithText(
          OutlinedButton,
          'Paste phone verification challenge',
        );
        await tester.ensureVisible(pasteChallenge);
        await tester.tap(pasteChallenge);
        await tester.pumpAndSettle();

        final dialog = find.byType(AlertDialog);
        await tester.enterText(
          find.descendant(of: dialog, matching: find.byType(TextField)),
          challenge.toPayload(),
        );
        await tester.tap(
          find.descendant(
            of: dialog,
            matching:
                find.widgetWithText(FilledButton, 'Create desktop response'),
          ),
        );
        await tester.pumpAndSettle();

        final response = actions.lastResponse;
        expect(response, isNotNull);
        primary.verifyResponsePayload(response!.toPayload());
        expect(primary.isVerified(request), isTrue);
        expect(find.text('Encrypted desktop response ready'), findsWidgets);

        if (_verifyClipboard) {
          final copyResponse = find.widgetWithText(
            OutlinedButton,
            'Copy desktop response',
          );
          await tester.ensureVisible(copyResponse);
          await tester.tap(copyResponse);
          await tester.pump(const Duration(milliseconds: 300));
          final copied = await Clipboard.getData('text/plain');
          expect(copied?.text, response.toPayload());
        }
      } finally {
        if (_verifyClipboard) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
        primary.dispose();
        primaryKey.dispose();
        desktopKey.dispose();
      }
    },
  );
}

class _RecordingCompanionActions implements DesktopLinkCompanionActions {
  _RecordingCompanionActions(this._delegate);

  final DesktopLinkCompanionActions _delegate;
  DesktopLinkPairingRequest? lastRequest;
  DesktopLinkKeyPossessionResponse? lastResponse;

  @override
  DesktopLinkPairingRequest issuePairingRequest({
    required String targetPrimaryDeviceId,
    required String displayName,
  }) {
    final request = _delegate.issuePairingRequest(
      targetPrimaryDeviceId: targetPrimaryDeviceId,
      displayName: displayName,
    );
    lastRequest = request;
    return request;
  }

  @override
  DesktopLinkKeyPossessionResponse respondToChallengePayload(
    String rawPayload,
  ) {
    final response = _delegate.respondToChallengePayload(rawPayload);
    lastResponse = response;
    return response;
  }
}
