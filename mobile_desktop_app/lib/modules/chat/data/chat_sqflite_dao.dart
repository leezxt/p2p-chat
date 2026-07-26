import 'package:sqflite/sqflite.dart';

import '../../../shared/models/message_envelope.dart';
import '../../../shared/models/message_status.dart';
import '../../../shared/models/message_type.dart';
import '../domain/conversation.dart';
import 'chat_dao.dart';

/// sqflite 實作的 [ChatDao]。
class ChatSqfliteDao implements ChatDao {
  ChatSqfliteDao(this._db);
  final Database _db;

  @override
  Future<void> upsertConversation(Conversation conversation) async {
    await _db.insert(
      'chat_conversations',
      conversation.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Conversation>> listConversations() async {
    final rows = await _db.query(
      'chat_conversations',
      orderBy: 'last_message_at DESC, updated_at DESC',
    );
    return rows.map(Conversation.fromRow).toList();
  }

  @override
  Future<Conversation?> getConversation(String id) async {
    final rows = await _db.query(
      'chat_conversations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Conversation.fromRow(rows.first);
  }

  @override
  Future<void> insertMessage(MessageEnvelope message) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.insert(
        'chat_messages',
        {
          'id': message.messageId,
          'conversation_id': message.conversationId,
          'sender_user_id': message.senderUserId,
          'sender_device_id': message.senderDeviceId,
          'type': message.type.wire,
          'payload_json': message.encodePayload(),
          'status': message.status.wire,
          'created_at': message.createdAt,
          'updated_at': now,
          'schema_version': message.schemaVersion,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<List<MessageEnvelope>> loadRecentMessages(
    String conversationId, {
    required int limit,
    int? beforeCreatedAt,
  }) async {
    final where = StringBuffer('conversation_id = ? AND type != ?');
    final args = <Object?>[conversationId, MessageType.reaction.wire];
    if (beforeCreatedAt != null) {
      where.write(' AND created_at < ?');
      args.add(beforeCreatedAt);
    }
    // 先取最近 limit 則（DESC），再反轉為由舊到新供 UI 顯示。
    final rows = await _db.query(
      'chat_messages',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.reversed.map(_rowToEnvelope).toList();
  }

  @override
  Future<void> updateMessageStatus(
      String messageId, MessageStatus status) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.update(
      'chat_messages',
      {'status': status.wire, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  MessageEnvelope _rowToEnvelope(Map<String, Object?> row) => MessageEnvelope(
        messageId: row['id'] as String,
        conversationId: row['conversation_id'] as String,
        senderUserId: row['sender_user_id'] as String,
        senderDeviceId: row['sender_device_id'] as String,
        type: MessageType.fromWire(row['type'] as String),
        payload: MessageEnvelope.decodePayload(row['payload_json'] as String),
        createdAt: row['created_at'] as int,
        status: MessageStatus.fromWire(row['status'] as String),
        schemaVersion: (row['schema_version'] as int?) ?? 1,
      );
}
