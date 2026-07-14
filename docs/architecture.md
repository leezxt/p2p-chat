# 架構總覽

完整 UML 視圖請見 [`uml.md`](uml.md)，包含部署、元件、訊息循序、模組生命週期與訊息狀態圖。

## 裝置角色

```text
手機 App：主裝置        電腦端：副裝置          免費 / 低成本中轉
  ├─ 身份與私鑰           ├─ 由手機掃碼授權         ├─ Signaling（交換 offer/answer/ICE）
  ├─ 聯絡人               ├─ 只同步必要資料         ├─ Presence（低頻上線狀態）
  ├─ 聊天紀錄             ├─ 預設不常駐            ├─ Offline Mailbox（暫存密文）
  ├─ 貼圖包 / 佇列        └─ 開啟時才連線          └─ Push（推播通知）
  └─ 本機 SQLite

聊天內容：優先 WebRTC P2P，不存中央伺服器。
```

## Core + Modules

```text
Core 系統
  ├─ Module Registry      模組註冊、生命週期管理
  ├─ Event Bus            模組間鬆耦合溝通
  ├─ Dependency Injection 服務定位 / 注入
  ├─ Routing              路由註冊表
  ├─ Local Database       SQLite + migration
  ├─ Crypto Service       加解密、金鑰（後續 Sprint 6）
  ├─ Network Service      signaling / P2P（後續 Sprint 5）
  ├─ Storage Service      檔案 / 快取
  ├─ Permission Service   權限請求
  ├─ Logging Service      分級日誌
  └─ Resource Policy      省電 / 低記憶體 / 連線數策略

Foundation Modules：Identity / Contacts / Chat / P2P / Crypto / Mailbox /
                    Notification / Presence / Settings
Experience Modules：Reaction / Sticker / Sticker Creator / Voice / Image /
                    Translation / Smart Notification
Device/Security：App Lock / Safety Number / Low Power / Storage Manager /
                 Desktop Link / Device Sync / Device Revoke
Advanced：File Transfer / Voice Call / Video Call / Small Group / Broadcast /
          Shared Notes / Shared Todo / Live Caption / Writing Assist / Chat Summary
```

## 模組生命週期

```text
installed → enabled → active
                 ↘  sleeping
                 ↘  disabled
```

| 狀態 | 意義 |
|---|---|
| installed | 已安裝，未啟用 |
| enabled | 已啟用，隨 App 啟動 init |
| active | 目前正在使用，持有資源 |
| sleeping | 休眠，釋放大部分資源，可快速喚醒 |
| disabled | 停用，不 init（高耗能模組預設值） |

平常狀態建議：Chat=enabled、P2P=sleeping、Sticker/File/Sync=sleeping、
Voice/Video Call=disabled、Presence=low-power、Mailbox=scheduled。

## 運行模式

正確：平常休眠 → 收推播或開聊天室 → 建立 P2P → 傳完短暫維持 → 閒置斷線 → 進背景關閉 P2P。
避免：一啟動就永久連線、每幾秒 heartbeat、同時跟所有好友維持 P2P、背景長時間 WebRTC。

## App 啟動流程

`main.dart` → 建立 `ModuleContext`（EventBus / Config / Logging / ResourcePolicy / DB）
→ 只 `init` 基礎模組（見 §9 規格範例）→ 高耗能模組不 active。

## 資源佔用目標（規格 §21 摘要）

冷啟動 < 3s；閒置記憶體 < 150MB；背景 P2P 預設關閉；前景 heartbeat 60s；
同時 P2P 連線 1–3 條；聊天室載入最近 50 則；離線密文保存 7–30 天；圖片自動下載預設關閉。

## 版本路線圖

- **V1** 核心可用：1:1 文字、P2P DataChannel、離線密文信箱、推播、SQLite、Presence、E2EE、模組化、低功耗。
- **V1.5** 安全 / 省資源：App Lock、Low Power、Safety Number、背景斷 P2P、閒置斷線、通知隱藏內容。
- **V2** 體驗：Emoji、Reaction、貼圖、語音 / 圖片訊息、單則翻譯、Storage Manager、Smart Notification、Username。
- **V3** 多裝置 / 進階：電腦副端、多裝置同步、裝置撤銷、檔案傳輸、語音通話、匯出匯入、Contact Discovery。
- **V4** 社群 / 視訊：視訊通話、小群組、廣播、共享筆記 / 待辦、訊息排程。
- **V5** AI / 生態：即時字幕、寫作輔助、聊天摘要、離線翻譯語言包、貼圖開源生態。

## Offline Mailbox v1

P2P 連線失敗時，App 才把既有 `EncryptedEnvelope` 上傳 mailbox。Server 只保存必要 routing metadata 與 ciphertext；recipient 完成認證、replay 檢查及本機 SQLite 寫入後才送 `DELIVERED` ACK。

狀態只允許 `STORED → DELIVERED → READ`，未送達密文可因 TTL 轉為 `EXPIRED`，不得倒退。完整 API、ACL、quota、TTL、冪等與刪除條件見 [`mailbox_api.md`](mailbox_api.md)。

Flutter 本機 schema v5 使用 `mailbox_pending_queue` 保存尚未上傳的 encrypted envelope。Queue 以 message ID 冪等、使用短期 lease 防止並行處理，crash 後 lease 到期可重新 claim；失敗最多重試 8 次，採 5 秒起始、15 分鐘上限並含 jitter 的 exponential backoff。

`MessageTransportCoordinator` 對每則訊息只加密一次：優先送 P2P，失敗時把同一 encrypted envelope 寫入 pending queue 並呼叫 mailbox。Queue 等待時訊息為 `PENDING`，server 接受後更新為 `STORED`；本機測試聊天室沒有 peer device 時不啟動網路傳送。
