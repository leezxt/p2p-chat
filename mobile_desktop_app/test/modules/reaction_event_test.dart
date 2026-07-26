import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/reaction/domain/reaction_event.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';

void main() {
  test('reaction event round-trips through a strict versioned payload', () {
    const event = ReactionEvent(
      eventId: 'reaction-1',
      targetMessageId: 'message-1',
      reactorUserId: 'alice',
      emoji: '👍',
      active: true,
      updatedAt: 100,
    );

    final envelope = event.toEnvelope(
      conversationId: 'conversation-1',
      senderDeviceId: 'alice-phone',
    );
    final decoded = ReactionEvent.fromEnvelope(envelope);

    expect(envelope.type, MessageType.reaction);
    expect(decoded.eventId, event.eventId);
    expect(decoded.targetMessageId, event.targetMessageId);
    expect(decoded.reactorUserId, event.reactorUserId);
    expect(decoded.emoji, event.emoji);
    expect(decoded.active, isTrue);
    expect(decoded.updatedAt, event.updatedAt);
  });

  test('reaction payload rejects extra fields and unsupported emoji', () {
    final valid = _envelope();
    expect(
      () => ReactionEvent.fromEnvelope(MessageEnvelope(
        messageId: valid.messageId,
        conversationId: valid.conversationId,
        senderUserId: valid.senderUserId,
        senderDeviceId: valid.senderDeviceId,
        type: valid.type,
        payload: {...valid.payload, 'unexpected': true},
        createdAt: valid.createdAt,
      )),
      throwsFormatException,
    );
    expect(
      () => ReactionEvent.fromEnvelope(MessageEnvelope(
        messageId: valid.messageId,
        conversationId: valid.conversationId,
        senderUserId: valid.senderUserId,
        senderDeviceId: valid.senderDeviceId,
        type: valid.type,
        payload: {...valid.payload, 'emoji': 'not-an-emoji'},
        createdAt: valid.createdAt,
      )),
      throwsFormatException,
    );
  });

  test('reaction payload timestamp must match the authenticated envelope', () {
    final valid = _envelope();
    expect(
      () => ReactionEvent.fromEnvelope(MessageEnvelope(
        messageId: valid.messageId,
        conversationId: valid.conversationId,
        senderUserId: valid.senderUserId,
        senderDeviceId: valid.senderDeviceId,
        type: valid.type,
        payload: {...valid.payload, 'updatedAt': valid.createdAt + 1},
        createdAt: valid.createdAt,
      )),
      throwsFormatException,
    );
  });
}

MessageEnvelope _envelope() => const ReactionEvent(
      eventId: 'reaction-1',
      targetMessageId: 'message-1',
      reactorUserId: 'alice',
      emoji: '❤️',
      active: false,
      updatedAt: 100,
    ).toEnvelope(
      conversationId: 'conversation-1',
      senderDeviceId: 'alice-phone',
    );
