import '../../../shared/models/message_envelope.dart';
import '../../../shared/models/message_type.dart';

class StickerMessage {
  const StickerMessage({
    required this.packId,
    required this.stickerId,
  });

  static final RegExp _idPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');

  final String packId;
  final String stickerId;

  factory StickerMessage.fromEnvelope(MessageEnvelope envelope) {
    if (envelope.type != MessageType.sticker ||
        envelope.payload.keys.toSet().difference(
          const {'packId', 'stickerId'},
        ).isNotEmpty ||
        envelope.payload.length != 2) {
      throw const FormatException('Invalid sticker envelope.');
    }
    final packId = envelope.payload['packId'];
    final stickerId = envelope.payload['stickerId'];
    if (packId is! String ||
        stickerId is! String ||
        !_idPattern.hasMatch(packId) ||
        !_idPattern.hasMatch(stickerId)) {
      throw const FormatException('Invalid sticker identifiers.');
    }
    return StickerMessage(packId: packId, stickerId: stickerId);
  }

  MessageEnvelope toEnvelope({
    required String messageId,
    required String conversationId,
    required String senderUserId,
    required String senderDeviceId,
    required int createdAt,
  }) =>
      MessageEnvelope(
        messageId: messageId,
        conversationId: conversationId,
        senderUserId: senderUserId,
        senderDeviceId: senderDeviceId,
        type: MessageType.sticker,
        payload: {
          'packId': packId,
          'stickerId': stickerId,
        },
        createdAt: createdAt,
      );
}
