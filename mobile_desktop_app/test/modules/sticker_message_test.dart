import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/modules/sticker/domain/sticker_message.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';

void main() {
  test('sticker envelope contains identifiers only', () {
    const sticker = StickerMessage(packId: 'simple_shapes', stickerId: 'hello');

    final envelope = sticker.toEnvelope(
      messageId: 'message-1',
      conversationId: 'conversation-1',
      senderUserId: 'user-a',
      senderDeviceId: 'device-a',
      createdAt: 1,
    );

    expect(envelope.type, MessageType.sticker);
    expect(envelope.payload, {
      'packId': 'simple_shapes',
      'stickerId': 'hello',
    });
    expect(StickerMessage.fromEnvelope(envelope).stickerId, 'hello');
  });

  test('rejects paths, URLs, bytes, and unknown payload fields', () {
    for (final payload in [
      {'packId': '../private', 'stickerId': 'hello'},
      {'packId': 'pack', 'stickerId': 'https://tracker.invalid/a.png'},
      {'packId': 'pack', 'stickerId': 'hello', 'bytes': 'base64'},
      {'packId': 'pack'},
    ]) {
      expect(
        () => StickerMessage.fromEnvelope(_envelope(payload)),
        throwsFormatException,
      );
    }
  });
}

MessageEnvelope _envelope(Map<String, Object?> payload) => MessageEnvelope(
      messageId: 'message-1',
      conversationId: 'conversation-1',
      senderUserId: 'user-a',
      senderDeviceId: 'device-a',
      type: MessageType.sticker,
      payload: payload,
      createdAt: 1,
    );
