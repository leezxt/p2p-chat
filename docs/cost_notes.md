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
- Mailbox 僅在前景自動同步（一般 60s、Low Power 5 分鐘），進背景停止排程；
  增加的是受限的密文 mailbox request，不建立常駐連線。
- 背景依賴推播喚醒，不維持長連線 → 降低連線與頻寬。
- 圖片 / 大檔案不自動下載 → 降低頻寬。
- TURN 只在 P2P 直連失敗時 fallback → 控制最貴的頻寬成本。

## 目前 V1 實作

- App 本機聊天與 P2P 路徑本身不產生中央訊息流量成本。
- 已實作的 Spring Boot signaling/mailbox/presence/push backend 需要 Java runtime 與
  PostgreSQL；目前 Docker Compose 是開發/驗收環境，不代表免費 production hosting。
- FCM HTTP v1 adapter 使用免費 FCM，但正式啟用仍需 Firebase project、Google ADC；
  iOS 通知另需 APNs 設定與 Apple Developer Program 資格。
- Cloudflare Worker/D1/KV 仍是後續低成本替代方案，尚未取代目前 Spring Boot backend。
- TURN 尚未實作，因此 V1 沒有 TURN 頻寬費；受限 NAT 下改走有 TTL/quota 的密文
  mailbox。若後續加入 TURN，必須另設流量上限與成本警示。
- Production Compose 使用自架 Caddy TLS proxy、Spring Boot 與 PostgreSQL，軟體本身無
  授權費，但需要網域、主機、持久磁碟、備份、log/monitoring 與對外流量預算；Caddy
  自動 ACME certificate 不代表主機或網域免費。
- 備份成本至少包含加密 off-host object storage、版本 retention 與定期 restore drill 的
  暫存資料庫空間；不能只保留與 production volume 同一主機上的 dump。本機 staging
  retention 工具已能只清除具有效 off-host receipt 的過期驗證備份，但不負責上傳或刪除
  遠端 object；正式成本仍須包含遠端 object 驗證、receipt 簽發、排程與告警。
- Production containers 已限制本機 JSON log 為每服務預設 5 × 10 MiB；one-shot monitor
  可接既有排程。若採用付費 log aggregation、uptime/告警服務，仍須另外估算 ingest、
  retention、probe frequency 與通知成本。

正式發布前需依預估活躍裝置數、mailbox 留存量、request rate、log/monitoring 與備份
需求建立月成本上限；候選版 Gate 見 [`release_candidate_v1.md`](release_candidate_v1.md)。
