import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:p2p_chat_app/app.dart';
import 'package:p2p_chat_app/bootstrap.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/modules/chat/data/chat_repository.dart';
import 'package:p2p_chat_app/modules/chat/domain/conversation.dart';
import 'package:p2p_chat_app/modules/chat/presentation/chat_page.dart';
import 'package:p2p_chat_app/modules/chat/presentation/conversation_list_page.dart';
import 'package:p2p_chat_app/modules/crypto/data/secure_key_value_store.dart';
import 'package:p2p_chat_app/modules/identity/domain/identity_session.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android App renders and persists a built-in sticker from the Chat picker',
    (tester) async {
      // 若原生測試意外改由非 Android target 執行，這個 Android UI gate 必須
      // fail-closed，不能把 host widget test 誤當成 AVD runtime 證據。
      expect(defaultTargetPlatform, TargetPlatform.android);

      final temporary = await getTemporaryDirectory();
      final directory = Directory(
        '${temporary.path}${Platform.pathSeparator}'
        'p2p_sticker_runtime_${DateTime.now().microsecondsSinceEpoch}',
      );
      await directory.create(recursive: true);

      Bootstrap? boot;
      DatabaseService? database;
      SecureKeyValueStore? secureStore;
      String? generatedDeviceKeyStorageKey;
      var appMounted = false;

      try {
        // 不注入 BACKEND_URL / LOCAL_DEV_AUTH_KEY：仍使用正式 bootstrap、SQLite、
        // secure storage 與內建貼圖資產，但不建立 AccessSession 或發起網路同步。
        boot = await bootstrap(
          databaseFactory: databaseFactory,
          databaseDirectory: directory.path,
        );
        database = boot.services.get<DatabaseService>();
        final identity = boot.services.get<IdentitySession>();
        secureStore = boot.services.get<SecureKeyValueStore>();
        generatedDeviceKeyStorageKey =
            'p2p.crypto.device.${identity.deviceId}.v1';

        const conversation = Conversation(
          id: 'sticker-runtime-conversation',
          title: 'Sticker runtime',
          createdAt: 1,
          updatedAt: 1,
        );
        final repository = boot.services.get<ChatRepository>();
        await repository.createConversation(conversation);

        await tester.pumpWidget(
          P2pChatApp(
            routes: boot.routes,
            registry: boot.registry,
            services: boot.services,
          ),
        );
        appMounted = true;
        await tester.pumpAndSettle();

        // 首頁及聊天室均是正式 module route，沒有在測試內另建 Navigator shell。
        expect(find.byType(ConversationListPage), findsOneWidget);
        await tester.tap(find.text(conversation.title));
        await tester.pumpAndSettle();
        expect(find.byType(ChatPage), findsOneWidget);

        await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
        await tester.pumpAndSettle();
        expect(find.byTooltip('flutter'), findsOneWidget);

        await tester.tap(find.byTooltip('flutter'));
        await tester.pumpAndSettle();

        // 選取後驗證的是訊息氣泡中的正式 Image.asset，而不只是 manifest 載入。
        final stickerImage = find.byType(Image);
        expect(stickerImage, findsOneWidget);
        final image = tester.widget<Image>(stickerImage);
        expect(image.image, isA<AssetImage>());
        expect(
          (image.image as AssetImage).assetName,
          'assets/stickers/simple_communication/logo.png',
        );

        final messages = await repository.loadRecentMessages(
          conversation.id,
          limit: 50,
        );
        expect(messages, hasLength(1));
        expect(messages.single.type, MessageType.sticker);
        expect(
          messages.single.payload,
          const {
            'packId': 'simple_communication',
            'stickerId': 'flutter',
          },
        );
      } finally {
        if (appMounted) {
          // 讓根 Widget 走正式 ModuleRegistry dispose，再關閉 SQLite。
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        } else {
          boot?.registry.disposeAll();
        }
        try {
          // identity 與 DB 都是本 test 的專屬資料；移除同樣專屬的 native
          // secure-storage device key，避免留下可解密材料給下一次測試。
          if (secureStore != null && generatedDeviceKeyStorageKey != null) {
            await secureStore.delete(generatedDeviceKeyStorageKey);
          }
        } finally {
          await database?.close();
          await directory.delete(recursive: true);
        }
      }
    },
  );
}
