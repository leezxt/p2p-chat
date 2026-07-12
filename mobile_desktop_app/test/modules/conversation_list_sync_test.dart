import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/modules/chat/data/chat_repository.dart';
import 'package:p2p_chat_app/modules/chat/presentation/conversation_list_page.dart';
import 'package:p2p_chat_app/shared/utils/id_generator.dart';

import 'fake_chat_dao.dart';

void main() {
  testWidgets('manual sync remains available after initial backend failure',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(syncMailbox: () async {
      calls++;
      if (calls == 1) throw StateError('offline');
    }));
    await tester.pumpAndSettle();

    expect(find.byTooltip('同步訊息'), findsOneWidget);
    await tester.tap(find.byTooltip('同步訊息'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('訊息已同步'), findsOneWidget);
    expect(find.textContaining('尚無聊天室'), findsOneWidget);
  });

  testWidgets('manual sync failure keeps local chat usable', (tester) async {
    await tester.pumpWidget(_app(syncMailbox: () async {
      throw StateError('offline');
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('同步訊息'));
    await tester.pumpAndSettle();

    expect(find.text('無法同步訊息，本機聊天仍可使用'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('manual sync ignores overlapping taps', (tester) async {
    var calls = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(_app(syncMailbox: () {
      calls++;
      if (calls == 1) return Future<void>.value();
      return pending.future;
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('同步訊息'));
    await tester.tap(find.byTooltip('同步訊息'));
    await tester.pump();

    expect(calls, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
  });
}

Widget _app({required Future<void> Function() syncMailbox}) {
  return MaterialApp(
    home: ConversationListPage(
      repository: ChatRepository(FakeChatDao(), EventBus()),
      ids: IdGenerator(),
      currentUserId: 'user-a',
      currentDeviceId: 'device-a',
      syncMailbox: syncMailbox,
    ),
  );
}
