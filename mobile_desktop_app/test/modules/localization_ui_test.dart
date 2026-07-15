import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/core/localization/app_language.dart';
import 'package:p2p_chat_app/core/localization/locale_controller.dart';
import 'package:p2p_chat_app/core/localization/locale_preference_store.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/modules/chat/data/chat_repository.dart';
import 'package:p2p_chat_app/modules/chat/presentation/conversation_list_page.dart';
import 'package:p2p_chat_app/shared/utils/id_generator.dart';

import 'fake_chat_dao.dart';

void main() {
  testWidgets('renders the main chat interface in Traditional Chinese',
      (tester) async {
    await tester.pumpWidget(_localizedApp(const Locale('zh', 'TW')));
    await tester.pumpAndSettle();

    expect(find.text('聊天'), findsOneWidget);
    expect(find.text('尚無聊天室，請使用新增按鈕建立'), findsOneWidget);
  });

  testWidgets('renders the main chat interface in English', (tester) async {
    await tester.pumpWidget(_localizedApp(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Chats'), findsOneWidget);
    expect(
      find.text('No chats yet. Use the add button to create one.'),
      findsOneWidget,
    );
  });

  testWidgets('language menu switches and persists the selected language',
      (tester) async {
    final store = _MemoryLocaleStore('zh_TW');
    final controller = LocaleController(store);
    await controller.load();

    await tester.pumpWidget(_switchableApp(controller));
    await tester.pumpAndSettle();
    expect(find.text('聊天'), findsOneWidget);

    await tester.tap(find.byTooltip('語言'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('英文'),
        matching: find.byType(CheckedPopupMenuItem<AppLanguage>),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chats'), findsOneWidget);
    expect(controller.language, AppLanguage.english);
    expect(store.value, 'en');
    controller.dispose();
  });
}

Widget _localizedApp(Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _page(),
    );

Widget _switchableApp(LocaleController controller) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        locale: controller.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _page(localeController: controller),
      ),
    );

Widget _page({LocaleController? localeController}) => ConversationListPage(
      repository: ChatRepository(FakeChatDao(), EventBus()),
      ids: IdGenerator(),
      currentUserId: 'user-a',
      currentDeviceId: 'device-a',
      localeController: localeController,
    );

class _MemoryLocaleStore implements LocalePreferenceStore {
  _MemoryLocaleStore(this.value);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
