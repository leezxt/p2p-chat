import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/modules/storage/domain/storage_manager_service.dart';
import 'package:p2p_chat_app/modules/storage/domain/storage_usage_snapshot.dart';
import 'package:p2p_chat_app/modules/storage/presentation/storage_manager_page.dart';

void main() {
  testWidgets('清理前會顯示受保護範圍與快取預覽', (tester) async {
    await tester.pumpWidget(_app(_StorageService()));
    await tester.pumpAndSettle();

    expect(find.text('Storage manager'), findsOneWidget);
    expect(find.text('Rebuildable cache'), findsOneWidget);
    expect(find.textContaining('never included in cleanup'), findsOneWidget);
    expect(find.text('Clear cache'), findsOneWidget);
  });
}

Widget _app(StorageManagerService service) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: StorageManagerPage(service: service),
    );

class _StorageService implements StorageManagerService {
  @override
  Future<int> clearRebuildableCache() async => 1024;

  @override
  Future<StorageUsageSnapshot> preview() async => const StorageUsageSnapshot(
        databaseBytes: 4096,
        cacheBytes: 1024,
        attachmentBytes: 0,
        protectedPendingMailboxBytes: 128,
      );
}
