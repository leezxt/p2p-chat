import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:p2p_chat_app/app.dart';
import 'package:p2p_chat_app/bootstrap.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/module/module_lifecycle.dart';
import 'package:p2p_chat_app/modules/chat/presentation/conversation_list_page.dart';
import 'package:p2p_chat_app/modules/desktop_link/desktop_link_module.dart';
import 'package:p2p_chat_app/modules/desktop_link/presentation/desktop_link_companion_page.dart';
import 'package:p2p_chat_app/modules/desktop_link/presentation/desktop_link_pairing_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets(
    'Windows app bootstrap opens Desktop Link from the actual Chat tools menu',
    (tester) async {
      // 若原生測試意外改由非 Windows target 執行，副端畫面選擇必須 fail-closed。
      expect(defaultTargetPlatform, TargetPlatform.windows);

      final directory =
          await Directory.systemTemp.createTemp('p2p_link_app_entry_runtime_');
      Bootstrap? boot;
      DatabaseService? database;
      var appMounted = false;

      try {
        // 不注入 BACKEND_URL / LOCAL_DEV_AUTH_KEY：完整 bootstrap 仍會組裝正式
        // 模組與路由，但不會產生 AccessSession 或發起網路同步。
        boot = await bootstrap(
          databaseFactory: databaseFactoryFfi,
          databaseDirectory: directory.path,
        );
        database = boot.services.get<DatabaseService>();

        expect(boot.registry.stateOf('desktop_link'), ModuleState.enabled);
        expect(boot.routes.contains(DesktopLinkModule.route), isTrue);

        await tester.pumpWidget(
          P2pChatApp(
            routes: boot.routes,
            registry: boot.registry,
            services: boot.services,
          ),
        );
        appMounted = true;
        await tester.pumpAndSettle();

        // P2pChatApp 的 initialRoute 是 ChatModule.route，以下操作的是正式
        // ConversationListPage，而非為測試額外建立的 Navigator shell。
        expect(find.byType(ConversationListPage), findsOneWidget);
        await tester.tap(find.byIcon(Icons.tune_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.devices_other_outlined));
        await tester.pumpAndSettle();

        expect(find.byType(DesktopLinkCompanionPage), findsOneWidget);
        expect(find.byType(DesktopLinkPairingPage), findsNothing);
      } finally {
        if (appMounted) {
          // 讓根 Widget 的 dispose() 走正式 ModuleRegistry 生命週期，再關閉 DB。
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        } else {
          boot?.registry.disposeAll();
        }
        await database?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
