# 成本說明

依規格 §26 規則 27：任何會增加伺服器成本的功能，必須在本檔註明。

## 目標

低成本、儘量不依賴自架伺服器；必要時只用免費或低成本中轉服務。

## 服務成本評估

| 用途 | 建議服務 | 成本層級 | 備註 |
|---|---|---|---|
| Signaling | Cloudflare Workers / Spring Boot WebSocket | 免費～低 | Workers 免費額度足夠原型 |
| 離線密文信箱 | Firebase Firestore / Cloudflare D1 / KV | 免費～低 | 只存密文，設 TTL 控制成長 |
| 推播 | Firebase Cloud Messaging / APNs | 免費 | FCM 免費；APNs 需 Apple 開發者帳號 |
| 邀請碼 / 短連結 | Cloudflare Workers | 免費～低 | |
| 管理後台 | Spring Boot | 自架成本 | 開發展示用 |
| 翻譯 fallback | LibreTranslate / 自架 / 第三方 API | 低～中 | 本機翻譯優先，雲端為 opt-in |
| TURN fallback | coturn / 低成本 TURN | 中 | 頻寬成本高，僅 P2P 失敗時啟用，後續再加 |

## 成本控制策略

- 聊天內容走 P2P，不經中央伺服器 → 無流量成本。
- 離線信箱只存密文，預設 TTL 7 天、上限 30 天；每 recipient device 最多 1,000 則/100 MiB，收到 `DELIVERED` 後可清除 ciphertext → 控制儲存成長。
- Presence 低頻（前景 60s、背景不更新）→ 降低請求數。
- 背景依賴推播喚醒，不維持長連線 → 降低連線與頻寬。
- 圖片 / 大檔案不自動下載 → 降低頻寬。
- TURN 只在 P2P 直連失敗時 fallback → 控制最貴的頻寬成本。

## 目前 Sprint 0–2

無任何伺服器成本（純本機）。
