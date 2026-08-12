# 訊息 Schema

所有訊息採用通用 envelope，內容以 `type + payload` 擴充。**新增訊息類型只能新增 `type`，不可破壞既有欄位。**

## 通用 Envelope

```json
{
  "messageId": "msg_123",
  "conversationId": "conv_001",
  "senderDeviceId": "device_a",
  "senderUserId": "user_a",
  "type": "text",
  "payload": {},
  "createdAt": 1780000000,
  "schemaVersion": 1
}
```

| 欄位 | 型別 | 說明 |
|---|---|---|
| messageId | string | 全域唯一訊息 ID |
| conversationId | string | 會話 ID |
| senderUserId | string | 發送者使用者 ID |
| senderDeviceId | string | 發送者裝置 ID |
| type | string | 訊息類型（見下） |
| payload | object | 依 type 而定 |
| createdAt | int | Unix epoch 秒 |
| schemaVersion | int | schema 版本，預設 1 |

## payload 依 type

- **text**：`{ "text": "你好" }`
- **sticker**：`{ "packId": "cute_cat", "stickerId": "happy" }`（只傳 ID，資源本機載入）
- **reaction**：`{ "targetMessageId": "msg_001", "reaction": "❤️", "operation": "add" }`
- **image**：Attachment v1 `{ "schemaVersion": 1, "attachmentId", "mimeType": "image/jpeg" | "image/png", "byteSize", "ciphertextSha256" }`；上限 10 MiB，只描述密文，不內嵌檔案 bytes。
- **voice_message**：Attachment v1 `{ "schemaVersion": 1, "attachmentId", "mimeType": "audio/ogg" | "audio/m4a", "byteSize", "ciphertextSha256" }`；上限 25 MiB，必須手動下載。
- **file**：`{ "fileId", "fileName", "size", "mimeType", "sha256" }`
- **system**：`{ "event": "contact_added" }`
- **call_event**：`{ "callType": "video", "event": "missed", "durationSeconds": 0 }`（不存影音，只存事件）

## 翻譯結果 metadata（不建立新訊息）

翻譯結果存本機 metadata，避免污染原始聊天紀錄：

```json
{
  "messageId": "msg_123",
  "translation": {
    "sourceLanguage": "th",
    "targetLanguage": "zh-TW",
    "translatedText": "你好，今天過得怎麼樣？",
    "engine": "local_or_cloud",
    "createdAt": 1780000000
  }
}
```

## 訊息狀態機

```text
PENDING   本機等待送出
SENT      已從本機送出
STORED    離線信箱已保存密文
DELIVERED 對方已下載並保存
READ      對方已讀
FAILED    失敗
EXPIRED   超過保存期限
```

規則：離線訊息在未收到 ACK 前不可刪除。所有網路傳輸失敗都要落到 FAILED 並可 retry。

Mailbox ACK 使用獨立 schema，只接受 `DELIVERED` 或 `READ`；`STORED` 是 server upload receipt，`EXPIRED` 是 server terminal state，不由 recipient ACK 宣告。完整契約見 [`mailbox_api.md`](mailbox_api.md)。
