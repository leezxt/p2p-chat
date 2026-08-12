import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_companion_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_key_possession.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_request.dart';
import 'package:p2p_chat_app/modules/desktop_link/presentation/desktop_link_companion_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('Desktop Companion 建立 QR、接受手機 challenge 並輸出回應', (tester) async {
    final companion = _FakeCompanionActions();
    await tester.pumpWidget(
      _app(DesktopLinkCompanionPage(companionService: companion)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up this desktop'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextField, 'Primary phone device ID'),
      'primary-phone',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Desktop name'),
      'Windows test desktop',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create pairing QR'));
    await tester.pumpAndSettle();

    expect(companion.issueCalls, 1);
    expect(companion.lastPrimaryDeviceId, 'primary-phone');
    expect(companion.lastDisplayName, 'Windows test desktop');
    expect(find.text('Pairing QR ready'), findsWidgets);
    expect(find.byType(QrImageView), findsOneWidget);

    final pasteChallenge = find.widgetWithText(
      OutlinedButton,
      'Paste phone verification challenge',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -640));
    await tester.pumpAndSettle();
    await tester.tap(pasteChallenge);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)),
      'phone-challenge',
    );
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, 'Create desktop response'),
      ),
    );
    await tester.pumpAndSettle();

    expect(companion.responseCalls, 1);
    expect(companion.lastChallenge, 'phone-challenge');
    expect(find.text('Encrypted desktop response ready'), findsWidgets);
    expect(find.text('Copy desktop response'), findsOneWidget);
  });
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

class _FakeCompanionActions implements DesktopLinkCompanionActions {
  int issueCalls = 0;
  int responseCalls = 0;
  String? lastPrimaryDeviceId;
  String? lastDisplayName;
  String? lastChallenge;

  @override
  DesktopLinkPairingRequest issuePairingRequest({
    required String targetPrimaryDeviceId,
    required String displayName,
  }) {
    issueCalls++;
    lastPrimaryDeviceId = targetPrimaryDeviceId;
    lastDisplayName = displayName;
    return DesktopLinkPairingRequest.create(
      requestId: 'request-0000000001',
      targetPrimaryDeviceId: targetPrimaryDeviceId,
      deviceId: 'desktop-windows',
      displayName: displayName,
      publicKey: _desktopPublicKey,
      issuedAt: 100,
    );
  }

  @override
  DesktopLinkKeyPossessionResponse respondToChallengePayload(
    String rawPayload,
  ) {
    responseCalls++;
    lastChallenge = rawPayload;
    return DesktopLinkKeyPossessionResponse.create(
      challengeId: 'challenge-0000000001',
      requestId: 'request-0000000001',
      primaryDeviceId: 'primary-phone',
      desktopDeviceId: 'desktop-windows',
      expiresAt: 400,
      nonce: Uint8List.fromList(List<int>.filled(24, 1)),
      ciphertext: Uint8List.fromList(List<int>.filled(32, 2)),
    );
  }
}

final Uint8List _desktopPublicKey = Uint8List.fromList(
  List<int>.generate(32, (index) => index + 1),
);
