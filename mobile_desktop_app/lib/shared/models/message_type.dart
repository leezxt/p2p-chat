/// 訊息類型（規格 §12）。
///
/// 新增類型只能「新增」值，不可破壞既有 envelope 欄位（規格 §26 規則 20）。
/// payload 結構依 type 而定，見 docs/message_schema.md。
enum MessageType {
  text,
  sticker,
  reaction,
  image,
  voiceMessage,
  file,
  system,
  callEvent;

  /// wire 格式使用 snake_case，與 docs/message_schema 一致。
  String get wire => switch (this) {
        MessageType.voiceMessage => 'voice_message',
        MessageType.callEvent => 'call_event',
        _ => name,
      };

  static MessageType fromWire(String value) => switch (value) {
        'voice_message' => MessageType.voiceMessage,
        'call_event' => MessageType.callEvent,
        _ => MessageType.values.firstWhere(
            (t) => t.name == value,
            orElse: () => MessageType.system,
          ),
      };
}
