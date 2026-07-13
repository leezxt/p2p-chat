# Offline Mailbox API v1

本文件定義 Sprint 7 的密文離線信箱契約。Mailbox server 是不可信中轉站，只保存 routing 所需 metadata 與 `EncryptedEnvelope`，不得接收或記錄聊天明文、私鑰、聯絡人顯示名稱或 conversation title。

## 不變條件

- 所有端點使用 JWT；JWT 的 user 必須擁有請求中的 local device，且 device 未撤銷。
- 上傳者只能宣告自己的 `senderDeviceId`；下載與 ACK 只允許 `recipientDeviceId` 的擁有者。
- Server 不接受一般 `MessageEnvelope`，只接受 `P2P_BOX_V1` encrypted envelope。
- `(senderDeviceId, messageId)` 是上傳冪等鍵；相同密文重送回傳原紀錄，不建立副本。相同鍵但內容不同回 `409 MAILBOX_IDEMPOTENCY_CONFLICT`。
- 狀態只可 `STORED -> DELIVERED -> READ`，或未送達前 `STORED -> EXPIRED`；相同狀態重送是冪等成功，任何倒退皆拒絕。
- 未取得 `DELIVERED` ACK 前不得主動刪除未過期密文。收到 `DELIVERED` 後可刪 ciphertext，但 ACK/tombstone 至少保留至原 TTL，讓 sender 可重試查詢且避免重新上傳。

## 限制

| 項目 | V1 限制 |
|---|---:|
| Ciphertext | 1 MiB，與 `EncryptedEnvelope.maxCiphertextBytes` 一致 |
| 單次拉取 | 預設 50，最大 100 |
| TTL | 預設 7 天，最短 1 小時，最長 30 天 |
| 每 recipient device pending 數 | 1,000 |
| 每 recipient device pending bytes | 100 MiB |
| 每 sender device 上傳速率 | 60 requests/minute |
| 每 device 拉取/ACK 速率 | 120 requests/minute |

超限回 `413 MAILBOX_MESSAGE_TOO_LARGE`、`429 MAILBOX_RATE_LIMITED` 或 `429 MAILBOX_QUOTA_EXCEEDED`；回應可附 `Retry-After`，但不得揭露其他使用者 quota 資訊。

## 上傳密文

`POST /api/v1/mailbox/messages`

```json
{
  "schemaVersion": 1,
  "expiresInSeconds": 604800,
  "envelope": {
    "cryptoVersion": 1,
    "suite": "P2P_BOX_V1",
    "senderDeviceId": "device_a",
    "recipientDeviceId": "device_b",
    "senderKeyId": "key_a",
    "recipientKeyId": "key_b",
    "messageId": "msg_123",
    "nonce": "base64url",
    "ciphertext": "base64url"
  }
}
```

成功回 `201`；冪等重送回 `200`。

```json
{
  "mailboxMessageId": "mbx_123",
  "messageId": "msg_123",
  "status": "STORED",
  "storedAt": 1780000000,
  "expiresAt": 1780604800
}
```

ACL 驗證：JWT user 擁有 sender device、sender 未撤銷、recipient 存在且未撤銷，且雙方已有 contact relationship。不存在與無權限一律回一般化 `404 MAILBOX_TARGET_UNAVAILABLE`，避免枚舉裝置。

## 拉取收件密文

`GET /api/v1/mailbox/messages?deviceId=device_b&cursor=<opaque>&limit=50`

只回傳該 device 尚未 `DELIVERED` 且未過期的紀錄，依 `(storedAt, mailboxMessageId)` 穩定排序。Cursor 是無 padding 的 base64url token，payload 包含版本、用途、device ID 與最後一筆 mailbox message ID，並以 server secret 衍生的 HMAC-SHA256 驗證完整性。Cursor 綁定 `INBOX` 用途與指定 device，不接受任意 offset，也不可跨裝置或跨 ACK API 重用。

```json
{
  "items": [
    {
      "mailboxMessageId": "mbx_123",
      "storedAt": 1780000000,
      "expiresAt": 1780604800,
      "envelope": {}
    }
  ],
  "nextCursor": null
}
```

下載本身不代表送達；App 必須先通過 envelope 認證、replay 檢查並成功寫入本機 SQLite，之後才送 `DELIVERED` ACK。

## 寫入 ACK

`PUT /api/v1/mailbox/messages/{mailboxMessageId}/ack`

```json
{
  "schemaVersion": 1,
  "mailboxMessageId": "mbx_123",
  "messageId": "msg_123",
  "acknowledgingDeviceId": "device_b",
  "status": "DELIVERED",
  "occurredAt": 1780000010
}
```

`status` 只接受 `DELIVERED` 或 `READ`。只有 recipient device owner 可 ACK；server 以自己的時間記錄 `acceptedAt`，client `occurredAt` 只作顯示與診斷，不參與 TTL 或授權判斷。

冪等鍵為 `(mailboxMessageId, acknowledgingDeviceId, status)`。`READ` 前必須已有 `DELIVERED`；重送相同 ACK 回 `200`，倒退或跳級回 `409 MAILBOX_INVALID_STATE_TRANSITION`。

## Sender 查詢 ACK

`GET /api/v1/mailbox/acks?deviceId=device_a&cursor=<opaque>&limit=50`

只允許原 sender device owner 查詢，依 `(updatedAt, mailboxMessageId)` 穩定分頁，回傳 `DELIVERED`/`READ`/`EXPIRED` 狀態，不回 ciphertext。Cursor 使用與 inbox 相同的 signed opaque 格式，但綁定 `ACKS` 用途與 sender device；不可拿 inbox cursor 查詢 ACK。Sender 以 `(mailboxMessageId, status)` 冪等更新本機訊息狀態。

```json
{
  "items": [
    {
      "mailboxMessageId": "mbx_123",
      "messageId": "msg_123",
      "status": "DELIVERED",
      "acceptedAt": 1780000010
    }
  ],
  "nextCursor": null
}
```

Flutter client 會持續拉取 `nextCursor` 直到為 `null`，每頁最多要求 100 筆；重複 cursor 或超過安全頁數會中止並回報錯誤，避免不可信 server 造成無限分頁。

## 過期與刪除

- Cleanup 使用 server `expiresAt`，不可相信 client clock。
- `STORED` 到期改為 `EXPIRED`，清除 ciphertext，保留最小 tombstone 供 sender 查詢。
- `DELIVERED` 後可立即清除 ciphertext；`READ` 只更新 ACK metadata。
- Tombstone/ACK 保留至 `max(expiresAt, lastAckAt + 24h)` 後才可刪除。
- Cleanup、ACK 與拉取必須以 transaction/conditional update 實作，避免下載與過期競態造成狀態倒退。

## 最小 Server Metadata

允許保存：mailbox message ID、message ID、sender/recipient device ID、sender/recipient key ID、nonce、ciphertext、byte size、state、stored/expiry/ACK timestamps。

禁止保存：inner message type、聊天文字、conversation ID、sender user display name、contact name、解密後 payload、secret/private key、access token。

## 穩定錯誤碼

- `MAILBOX_INVALID_ENVELOPE`
- `MAILBOX_TARGET_UNAVAILABLE`
- `MAILBOX_MESSAGE_TOO_LARGE`
- `MAILBOX_QUOTA_EXCEEDED`
- `MAILBOX_RATE_LIMITED`
- `MAILBOX_IDEMPOTENCY_CONFLICT`
- `MAILBOX_MESSAGE_NOT_FOUND`
- `MAILBOX_INVALID_STATE_TRANSITION`
- `MAILBOX_MESSAGE_EXPIRED`
- `MAILBOX_INVALID_CURSOR`
