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

不得加入 plaintext、ciphertext、sender、conversation、message preview 或 mailbox ID。

FCM worker 使用 HTTP v1 與 Google ADC。Outbox 流程為 `PENDING -> PROCESSING -> SENT/FAILED`；暫時錯誤回到 `PENDING`，最多 8 次，5 秒起始且最多等待 15 分鐘。每次 claim 都有兩分鐘 lease 與隨機 lease token，可由其他 instance 回收過期工作，舊 worker 無法覆寫新結果。成功、沒有 active token，或所有 token 已失效時結束工作；`429`、`5xx`、`UNAVAILABLE` 等暫時錯誤重試，永久錯誤與被竄改 payload 直接失敗。

FCM 回覆 `UNREGISTERED` / `NOT_FOUND` 時會撤銷 token 並清除 ciphertext，但必須同時符合 token ID 與送出時的 SHA-256 hash，避免延遲的舊 response 撤銷剛更新的新 token。Worker 與 HTTP v1 adapter 已完成自動化與 PostgreSQL 驗證；真實 Firebase credentials、Android 系統通知與實機 cold/warm start 尚未驗證。
