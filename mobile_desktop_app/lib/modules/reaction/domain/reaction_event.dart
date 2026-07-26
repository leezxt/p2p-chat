import '../../../shared/models/message_envelope.dart';
import '../../../shared/models/message_type.dart';

/// Versioned reaction event carried inside the existing encrypted message
/// envelope. The reactor identity is taken from the authenticated envelope,
/// never duplicated in the payload.
class ReactionEvent {
  const ReactionEvent({
    required this.eventId,
    required this.targetMessageId,
    required this.reactorUserId,
    required this.emoji,
    required this.active,
    required this.updatedAt,
    this.version = currentVersion,
  });

  static const int currentVersion = 1;
  static const Set<String> supportedEmoji = {
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
  };

  final String eventId;
  final String targetMessageId;
  final String reactorUserId;
  final String emoji;
  final bool active;
  final int updatedAt;
  final int version;

  factory ReactionEvent.fromEnvelope(MessageEnvelope envelope) {
    if (envelope.type != MessageType.reaction) {
      throw const FormatException('Envelope is not a reaction event.');
    }
    final payload = envelope.payload;
    const expectedKeys = {
      'reactionVersion',
      'targetMessageId',
      'emoji',
      'active',
      'updatedAt',
    };
    if (payload.keys.toSet().difference(expectedKeys).isNotEmpty ||
        expectedKeys.difference(payload.keys.toSet()).isNotEmpty) {
      throw const FormatException('Reaction payload fields are invalid.');
    }
    final version = payload['reactionVersion'];
    final targetMessageId = payload['targetMessageId'];
    final emoji = payload['emoji'];
    final active = payload['active'];
    final updatedAt = payload['updatedAt'];
    if (version != currentVersion ||
        targetMessageId is! String ||
        targetMessageId.trim().isEmpty ||
        emoji is! String ||
        !supportedEmoji.contains(emoji) ||
        active is! bool ||
        updatedAt is! int ||
        updatedAt < 0 ||
        updatedAt != envelope.createdAt ||
        envelope.messageId.trim().isEmpty ||
        envelope.senderUserId.trim().isEmpty) {
      throw const FormatException('Reaction payload values are invalid.');
    }
    return ReactionEvent(
      eventId: envelope.messageId,
      targetMessageId: targetMessageId,
      reactorUserId: envelope.senderUserId,
      emoji: emoji,
      active: active,
      updatedAt: updatedAt,
      version: currentVersion,
    );
  }

  MessageEnvelope toEnvelope({
    required String conversationId,
    required String senderDeviceId,
  }) =>
      MessageEnvelope(
        messageId: eventId,
        conversationId: conversationId,
        senderUserId: reactorUserId,
        senderDeviceId: senderDeviceId,
        type: MessageType.reaction,
        payload: {
          'reactionVersion': version,
          'targetMessageId': targetMessageId,
          'emoji': emoji,
          'active': active,
          'updatedAt': updatedAt,
        },
        createdAt: updatedAt,
      );
}
