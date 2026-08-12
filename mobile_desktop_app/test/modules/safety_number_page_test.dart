import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/modules/safety_number/domain/safety_number.dart';
import 'package:p2p_chat_app/modules/safety_number/presentation/safety_number_page.dart';
import 'package:p2p_chat_app/modules/safety_number/presentation/safety_number_qr_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('shows a QR code and saves manual verification', (tester) async {
    var verified = false;

    SafetyNumber number() => SafetyNumber.generate(
          local: _participant('alice', 'alice-phone', 0),
          remote: _participant('bob', 'bob-phone', 32),
          verified: verified,
        );

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      locale: const Locale('zh', 'TW'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: SafetyNumberPage(
        title: 'Bob',
        load: () async => number(),
        markVerified: (_) async => verified = true,
        verifyQrPayload: (_) async => false,
        qrScanner: _FakeScanner(null, supported: false),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('安全碼'), findsOneWidget);
    expect(find.text('尚未驗證'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    final qrCode = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qrCode.backgroundColor, Colors.white);
    expect(qrCode.eyeStyle.color, Colors.black);
    expect(qrCode.dataModuleStyle.color, Colors.black);
    expect(find.text(number().displayGroups.first), findsOneWidget);
    expect(find.text('掃描安全碼 QR'), findsNothing);
    expect(find.text('比對 QR 內容'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '確認安全碼').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '確認安全碼').last);
    await tester.pumpAndSettle();

    expect(verified, isTrue);
    expect(find.text('已驗證'), findsOneWidget);
    expect(find.text('安全碼驗證已保存'), findsOneWidget);
  });

  testWidgets('validates a payload returned by an injected QR scanner',
      (tester) async {
    var verified = false;
    final number = SafetyNumber.generate(
      local: _participant('alice', 'alice-phone', 0),
      remote: _participant('bob', 'bob-phone', 32),
    );
    final scanner = _FakeScanner(number.qrPayload);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: SafetyNumberPage(
        title: 'Bob',
        load: () async => SafetyNumber.generate(
          local: _participant('alice', 'alice-phone', 0),
          remote: _participant('bob', 'bob-phone', 32),
          verified: verified,
        ),
        markVerified: (_) async {},
        verifyQrPayload: (payload) async {
          expect(payload, number.qrPayload);
          verified = true;
          return true;
        },
        qrScanner: scanner,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(
      OutlinedButton,
      'Scan safety number QR',
    ));
    await tester.pumpAndSettle();

    expect(scanner.calls, 1);
    expect(verified, isTrue);
    expect(find.text('Verified'), findsOneWidget);
  });
}

class _FakeScanner implements SafetyNumberQrScanner {
  _FakeScanner(this.payload, {this.supported = true});

  final String? payload;
  final bool supported;
  int calls = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<String?> scan(BuildContext context) async {
    calls++;
    return payload;
  }
}

SafetyNumberParticipant _participant(
  String userId,
  String deviceId,
  int offset,
) =>
    SafetyNumberParticipant(
      userId: userId,
      deviceId: deviceId,
      publicKey:
          Uint8List.fromList(List.generate(32, (index) => index + offset)),
    );
