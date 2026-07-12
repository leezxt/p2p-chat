/// 訊息狀態（規格 §13）。
///
/// 重要規則：離線訊息在未收到 ACK（DELIVERED 之前）不可刪除。
enum MessageStatus {
  pending, // 本機等待送出
  sent, // 已從本機送出
  stored, // 離線信箱已保存密文
  delivered, // 對方已下載並保存
  read, // 對方已讀
  failed, // 失敗
  expired; // 超過保存期限

  String get wire => name.toUpperCase();

  static MessageStatus fromWire(String value) =>
      MessageStatus.values.firstWhere(
        (s) => s.wire == value.toUpperCase(),
        orElse: () => MessageStatus.pending,
      );
}
