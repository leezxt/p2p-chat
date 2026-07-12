# cloudflare_worker（後續，待辦）

低成本 signaling / invite code / offline mailbox 的 Cloudflare Workers 實作。

用途（規格 §3.2）：
- Signaling：交換 WebRTC offer / answer / ICE candidate
- 邀請碼 / 短連結
- 離線密文信箱：Cloudflare D1 / KV（只存密文 + TTL）

正式低成本部署時，可將 java_backend 的部分功能改由此承接。尚未開始實作。
