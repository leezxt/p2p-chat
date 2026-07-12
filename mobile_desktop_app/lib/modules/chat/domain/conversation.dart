/// 會話（聊天室）領域模型，對應 chat_conversations 表。
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    this.peerUserId,
    this.lastMessagePreview,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;

  /// 對方 userId（1 對 1）。第一版群組尚未支援，故可為 null。
  final String? peerUserId;

  /// 聊天室列表顯示用的最後一則訊息預覽。
  final String? lastMessagePreview;
  final int? lastMessageAt;
  final int createdAt;
  final int updatedAt;

  Conversation copyWith({
    String? lastMessagePreview,
    int? lastMessageAt,
    int? updatedAt,
  }) =>
      Conversation(
        id: id,
        title: title,
        peerUserId: peerUserId,
        lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'peer_user_id': peerUserId,
        'last_message_preview': lastMessagePreview,
        'last_message_at': lastMessageAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Conversation.fromRow(Map<String, Object?> row) => Conversation(
        id: row['id'] as String,
        title: row['title'] as String,
        peerUserId: row['peer_user_id'] as String?,
        lastMessagePreview: row['last_message_preview'] as String?,
        lastMessageAt: row['last_message_at'] as int?,
        createdAt: row['created_at'] as int,
        updatedAt: row['updated_at'] as int,
      );
}
