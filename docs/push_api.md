# Push API 與 Notification Outbox v1

Push 只用來喚醒 App 同步 mailbox，不承載聊天內容。

## Token API

- `PUT /api/v1/push/devices/{deviceId}/token`
  - body：`provider`（`FCM` / `APNS`）、`token`
  - JWT 使用者只能註冊或更新自己的未撤銷裝置。
- `DELETE /api/v1/push/devices/{deviceId}/token/{provider}`
  - 冪等撤銷自己的 token。

Token 不由 API 回傳，也不得寫入 log。Prototype backend 必須保存原 token 供 provider 發送，另存 SHA-256 hash 作唯一性與稽核；正式部署需啟用資料庫磁碟加密與 secrets/access control。

同一 token 不可被另一個使用者的裝置搶註冊，衝突回 `409`；同一使用者換機時才允許轉移綁定。

## Notification Outbox

新 mailbox message 在同一交易中冪等建立 `MAILBOX_AVAILABLE` outbox。Push payload 固定為：

```json
{"schemaVersion":1,"type":"MAILBOX_AVAILABLE"}
```

不得加入 plaintext、ciphertext、sender、conversation、message preview 或 mailbox ID。FCM/APNs worker 成功後才把 outbox 從 `PENDING` 更新為 `SENT`；本階段尚未連接 provider credentials。
