import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_chat_app/shared/models/message_envelope.dart';
import 'package:p2p_chat_app/shared/models/message_status.dart';
import 'package:p2p_chat_app/shared/models/message_type.dart';

void main() {
  group('MessageEnvelope / schema', () {
    test('toWireJson 不含本機 status，round-trip 保值', () {
      const env = MessageEnvelope(
        messageId: 'msg_1',
        conversationId: 'conv_1',
        senderUserId: 'user_a',
        senderDeviceId: 'device_a',
        type: MessageType.text,
        payload: {'text': '你好'},
        createdAt: 1780000000,
        status: MessageStatus.sent,
      );

      final json = env.toWireJson();
      expect(json.containsKey('status'), isFalse);
      expect(json['type'], 'text');

      final back = MessageEnvelope.fromWireJson(json);
      expect(back.text, '你好');
      expect(back.conversationId, 'conv_1');
      expect(back.schemaVersion, 1);
    });

    test('MessageType wire 使用 snake_case', () {
      expect(MessageType.voiceMessage.wire, 'voice_message');
      expect(MessageType.callEvent.wire, 'call_event');
      expect(MessageType.fromWire('voice_message'), MessageType.voiceMessage);
    });

    test('MessageStatus wire 為大寫且可反解', () {
      expect(MessageStatus.delivered.wire, 'DELIVERED');
      expect(MessageStatus.fromWire('READ'), MessageStatus.read);
    });

    test('payload 編解碼一致', () {
      const env = MessageEnvelope(
        messageId: 'm',
        conversationId: 'c',
        senderUserId: 'u',
        senderDeviceId: 'd',
        type: MessageType.sticker,
        payload: {'packId': 'cute_cat', 'stickerId': 'happy'},
        createdAt: 1,
      );
      final decoded = MessageEnvelope.decodePayload(env.encodePayload());
      expect(decoded['packId'], 'cute_cat');
    });
  });
}
