import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/database/database_service.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/logging/logging_service.dart';
import 'package:p2p_chat_app/modules/chat/data/chat_repository.dart';
import 'package:p2p_chat_app/modules/chat/domain/conversation.dart';
import 'package:p2p_chat_app/modules/chat/presentation/chat_controller.dart';
import 'package:p2p_chat_app/modules/chat/presentation/chat_page.dart';
import 'package:p2p_chat_app/modules/reaction/data/reaction_repository.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';
import 'package:p2p_chat_app/shared/utils/id_generator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_chat_dao.dart';

void main() {
  sqfliteFfiInit();

  late Directory directory;
  late DatabaseService database;
  late FakeChatDao dao;
  late ChatRepository chat;
  late ReactionRepository reactions;
  late ChatController controller;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('p2p_chat_reactions_');
    database = DatabaseService(
      databaseFactory: databaseFactoryFfi,
      logger: LoggingService(),
      fileName: 'test.db',
    );
    await database.open(directoryPath: directory.path);
    dao = FakeChatDao();
    chat = ChatRepository(dao, EventBus());
    reactions = ReactionRepository(database.db);
    await chat.createConversation(
      const Conversation(
        id: 'conversation-1',
        title: 'Peer',
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await chat.saveIncomingMessage(_message);
    controller = ChatController(
      conversationId: 'conversation-1',
      repository: chat,
      ids: IdGenerator(),
      currentUserId: 'user-a',
      currentDeviceId: 'device-a',
      reactionRepository: reactions,
    );
    await controller.loadInitial();
  });

  tearDown(() async {
    controller.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  test('toggleReaction 新增後再次切換會取消，且不加入訊息泡泡', () async {
    await controller.toggleReaction(_message, '👍');

    expect(controller.reactionsFor(_message.messageId), hasLength(1));
    expect(controller.messages.map((message) => message.type), [
      MessageType.text,
    ]);

    await controller.toggleReaction(_message, '👍');

    expect(controller.reactionsFor(_message.messageId), isEmpty);
    expect(
      dao.messages.where((message) => message.type == MessageType.reaction),
      hasLength(2),
    );
  });

  test('不支援的 emoji 不會建立 reaction event', () async {
    await controller.toggleReaction(_message, '🔥');

    expect(controller.reactionsFor(_message.messageId), isEmpty);
    expect(
      dao.messages.where((message) => message.type == MessageType.reaction),
      isEmpty,
    );
  });

  for (final testCase in const [
    (Locale('en'), 'Add reaction'),
    (Locale('zh', 'TW'), '新增表情回應'),
  ]) {
    testWidgets('${testCase.$1} 長按訊息可新增 reaction', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: testCase.$1,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatPage(controller: controller, title: 'Peer'),
      ));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Hello'));
      await tester.pumpAndSettle();

      expect(find.text(testCase.$2), findsOneWidget);
      await tester.tap(find.text('👍'));
      await tester.pumpAndSettle();

      expect(find.text('👍 1'), findsOneWidget);
    });
  }
}

const _message = MessageEnvelope(
  messageId: 'message-1',
  conversationId: 'conversation-1',
  senderUserId: 'user-b',
  senderDeviceId: 'device-b',
  type: MessageType.text,
  payload: {'text': 'Hello'},
  createdAt: 1,
);
