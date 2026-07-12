# Presence API v1

Presence 是低頻、best-effort metadata，不代表即時連線。App 僅在前景約每 60 秒更新；hidden、paused、detached 時停止 heartbeat。

## API

- `POST /api/v1/presence/{deviceId}/heartbeat`：JWT 使用者只能更新自己的未撤銷裝置，成功回 `204`。
- `GET /api/v1/presence/contacts`：只回傳呼叫者既有聯絡人的 `userId`、主要未撤銷 `deviceId` 與 `lastSeenAt`；不可查詢任意使用者。

## 顯示規則

- `lastSeen <= 90 秒`：在線
- `90 秒 < lastSeen <= 5 分鐘`：剛剛在線
- 無資料或超過 5 分鐘：離線

Presence 失敗不得阻塞本機聊天、P2P 或 mailbox；App 不在背景維持 timer 或 heartbeat。
