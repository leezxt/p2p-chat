import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/core/events/event_bus.dart';
import 'package:p2p_chat_app/modules/chat/data/chat_repository.dart';
import 'package:p2p_chat_app/modules/chat/domain/conversation.dart';
import 'package:p2p_chat_app/modules/chat/events/chat_events.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_status.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';

import 'fake_chat_dao.dart';

MessageEnvelope _text(String conv, String text, int at) => MessageEnvelope(
      messageId: 'msg_$at',
      conversationId: conv,
      senderUserId: 'me',
      senderDeviceId: 'dev',
      type: MessageType.text,
      payload: {'text': text},
      createdAt: at,
    );

MessageEnvelope _incomingText(String conv, String text, int at) =>
    MessageEnvelope(
      messageId: 'incoming_$at',
      conversationId: conv,
      senderUserId: 'peer-user',
      senderDeviceId: 'peer-device',
      type: MessageType.text,
      payload: {'text': text},
      createdAt: at,
    );

void main() {
  late FakeChatDao dao;
  late EventBus bus;
  late ChatRepository repo;

  setUp(() {
    dao = FakeChatDao();
    bus = EventBus();
    repo = ChatRepository(dao, bus);
  });

  test('saveOutgoingMessage 寫入為 sent 並發出 MessageStored', () async {
    await repo.createConversation(
        const Conversation(id: 'c1', title: '測試', createdAt: 0, updatedAt: 0));
    MessageStored? event;
    bus.on<MessageStored>((e) => event = e);

    await repo.saveOutgoingMessage(_text('c1', '你好', 100));

    expect(dao.messages.single.status, MessageStatus.sent);
    expect(event, isNotNull);
    expect(event!.message.text, '你好');
  });

  test('送出訊息會更新會話預覽與時間', () async {
    await repo.createConversation(
        const Conversation(id: 'c1', title: '測試', createdAt: 0, updatedAt: 0));

    await repo.saveOutgoingMessage(_text('c1', '最後一句', 200));

    final conv = await repo.getConversation('c1');
    expect(conv!.lastMessagePreview, '最後一句');
    expect(conv.lastMessageAt, 200);
  });

  test('loadRecentMessages 回傳最近 N 則、由舊到新', () async {
    await repo.createConversation(
        const Conversation(id: 'c1', title: '測試', createdAt: 0, updatedAt: 0));
    for (var i = 1; i <= 5; i++) {
      await repo.saveOutgoingMessage(_text('c1', '訊息$i', i));
    }

    final page = await repo.loadRecentMessages('c1', limit: 3);

    expect(page.map((m) => m.text), ['訊息3', '訊息4', '訊息5']);
  });

  test('beforeCreatedAt 可分頁載入更舊訊息', () async {
    await repo.createConversation(
        const Conversation(id: 'c1', title: '測試', createdAt: 0, updatedAt: 0));
    for (var i = 1; i <= 5; i++) {
      await repo.saveOutgoingMessage(_text('c1', '訊息$i', i));
    }

    final older =
        await repo.loadRecentMessages('c1', limit: 2, beforeCreatedAt: 3);

    expect(older.map((m) => m.text), ['訊息1', '訊息2']);
  });

  test('未知會話收到訊息時自動建立 1 對 1 會話', () async {
    await repo.saveIncomingMessage(_incomingText('remote-c1', '離線訊息', 300));

    final conversation = await repo.getConversation('remote-c1');
    expect(conversation, isNotNull);
    expect(conversation!.title, 'peer-user');
    expect(conversation.peerUserId, 'peer-user');
    expect(conversation.lastMessagePreview, '離線訊息');
    expect(conversation.lastMessageAt, 300);
  });

  test('未知會話的同一收件訊息重送不會重複保存', () async {
    final message = _incomingText('remote-c1', '只顯示一次', 301);

    await repo.saveIncomingMessage(message);
    await repo.saveIncomingMessage(message);

    expect(dao.conversations, hasLength(1));
    expect(dao.messages, hasLength(1));
  });
}
