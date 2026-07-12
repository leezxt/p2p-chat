import 'dart:convert';

import 'message_status.dart';
import 'message_type.dart';

/// 統一訊息 envelope（規格 §12）。所有訊息類型共用此外層結構，
/// 差異只在 [type] 與 [payload]，確保新增類型不破壞既有 schema。
class MessageEnvelope {
  const MessageEnvelope({
    required this.messageId,
    required this.conversationId,
    required this.senderUserId,
    required this.senderDeviceId,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.status = MessageStatus.pending,
    this.schemaVersion = 1,
  });

  final String messageId;
  final String conversationId;
  final String senderUserId;
  final String senderDeviceId;
  final MessageType type;
  final Map<String, Object?> payload;

  /// Unix epoch 秒（規格 §12）。
  final int createdAt;

  /// 本機狀態，不屬於對外傳輸 envelope，但存於本機 DB。
  final MessageStatus status;
  final int schemaVersion;

  /// 文字訊息便捷取值（type 非 text 時回傳 null）。
  String? get text =>
      type == MessageType.text ? payload['text'] as String? : null;

  MessageEnvelope copyWith({MessageStatus? status}) => MessageEnvelope(
        messageId: messageId,
        conversationId: conversationId,
        senderUserId: senderUserId,
        senderDeviceId: senderDeviceId,
        type: type,
        payload: payload,
        createdAt: createdAt,
        status: status ?? this.status,
        schemaVersion: schemaVersion,
      );

  /// 對外傳輸用 JSON（不含本機 status）。
  Map<String, Object?> toWireJson() => {
        'messageId': messageId,
        'conversationId': conversationId,
        'senderUserId': senderUserId,
        'senderDeviceId': senderDeviceId,
        'type': type.wire,
        'payload': payload,
        'createdAt': createdAt,
        'schemaVersion': schemaVersion,
      };

  factory MessageEnvelope.fromWireJson(Map<String, Object?> json) =>
      MessageEnvelope(
        messageId: json['messageId'] as String,
        conversationId: json['conversationId'] as String,
        senderUserId: json['senderUserId'] as String,
        senderDeviceId: json['senderDeviceId'] as String,
        type: MessageType.fromWire(json['type'] as String),
        payload: Map<String, Object?>.from(json['payload'] as Map),
        createdAt: json['createdAt'] as int,
        schemaVersion: (json['schemaVersion'] as int?) ?? 1,
      );

  /// payload 序列化為字串，供 SQLite payload_json 欄位存放。
  String encodePayload() => jsonEncode(payload);

  static Map<String, Object?> decodePayload(String raw) =>
      Map<String, Object?>.from(jsonDecode(raw) as Map);
}
