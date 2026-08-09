import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_request.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_pairing_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/domain/desktop_link_service.dart';
import 'package:p2p_chat_app/modules/desktop_link/presentation/desktop_link_pairing_page.dart';
import 'package:p2p_chat_app/modules/desktop_link/presentation/desktop_link_qr_scanner.dart';

void main() {
  testWidgets('掃描後先檢閱 fingerprint，再按同意才授權桌面端', (tester) async {
    final links = _FakeLinkManager();
    final pairing = _FakePairingActions(links);
    final request = _request();
    final scanner = _FakeScanner(request.toQrPayload());
    await tester.pumpWidget(
      _app(
        DesktopLinkPairingPage(
          pairingService: pairing,
          desktopLinkService: links,
          qrScanner: scanner,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan desktop pairing QR'));
    await tester.pumpAndSettle();

    expect(scanner.calls, 1);
    expect(find.text('Pairing request ready for review'), findsOneWidget);
    expect(find.textContaining('Windows test desktop'), findsOneWidget);
    expect(find.text('desktop-fingerprint-1234'), findsOneWidget);
    expect(pairing.confirmCalls, 0);
    expect(links.links, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve link'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, 'Approve link'),
      ),
    );
    await tester.pumpAndSettle();

    expect(pairing.confirmCalls, 1);
    expect(find.text('Desktop link approved'), findsOneWidget);
    expect(links.links, hasLength(1));
    expect(links.links.single.isActive, isTrue);
  });
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

DesktopLinkPairingRequest _request() => DesktopLinkPairingRequest.create(
      requestId: 'request-0000000001',
      targetPrimaryDeviceId: 'primary-phone',
      deviceId: 'desktop-windows',
      displayName: 'Windows test desktop',
      publicKeyFingerprint: 'desktop-fingerprint-1234',
      issuedAt: 100,
    );

class _FakeScanner implements DesktopLinkQrScanner {
  _FakeScanner(this.payload);

  final String payload;
  int calls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<String?> scan(BuildContext context) async {
    calls++;
    return payload;
  }
}

class _FakePairingActions implements DesktopLinkPairingActions {
  _FakePairingActions(this._links);

  final _FakeLinkManager _links;
  int confirmCalls = 0;

  @override
  Future<DesktopLinkPairingRequest> prepareQrPayload(String rawPayload) async =>
      DesktopLinkPairingRequest.fromQrPayload(rawPayload);

  @override
  Future<DesktopLink> confirm(DesktopLinkPairingRequest request) async {
    confirmCalls++;
    final link = DesktopLink(
      deviceId: request.deviceId,
      displayName: request.displayName,
      publicKeyFingerprint: request.publicKeyFingerprint,
      authorizedAfter: 100,
      createdAt: 100,
      updatedAt: 100,
    );
    _links.authorize(link);
    return link;
  }

  @override
  Future<void> reject(DesktopLinkPairingRequest request) async {}
}

class _FakeLinkManager implements DesktopLinkManager {
  final List<DesktopLink> links = <DesktopLink>[];

  @override
  Future<List<DesktopLink>> listLinks() async => List.unmodifiable(links);

  @override
  Future<DesktopLink> revoke(String deviceId) async {
    final index = links.indexWhere((link) => link.deviceId == deviceId);
    final existing = links[index];
    final revoked = DesktopLink(
      deviceId: existing.deviceId,
      displayName: existing.displayName,
      publicKeyFingerprint: existing.publicKeyFingerprint,
      authorizedAfter: existing.authorizedAfter,
      revokedAt: existing.updatedAt + 1,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt + 1,
    );
    links[index] = revoked;
    return revoked;
  }

  void authorize(DesktopLink link) => links.add(link);
}
