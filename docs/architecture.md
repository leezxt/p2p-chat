# 架構總覽

完整 UML 視圖請見 [`uml.md`](uml.md)，包含部署、元件、訊息循序、模組生命週期與訊息狀態圖。

目前主要發布目標仍是 v1.2 藍圖的 V1，並已在外部 Gate 等待期間先行實作
V1.5 Safety Number 核心與 scanner adapter，以及 App Lock PIN、生物辨識 adapter、通知隱私策略、安全儲存與背景自動鎖定。Android 雙 AVD 已通過加密 P2P、offline mailbox、
ACK/restart 與資源開發基線；雙 Android 真機、真實 Push、iOS 實機與正式簽章仍是
發布 Gate。建置、操作與逐項限制見 [`release_candidate_v1.md`](release_candidate_v1.md)。

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

`AppLockModule` 使用 libsodium `crypto_pwhash_str` 的 Argon2id interactive profile，並在
平台 secure storage 保存版本化 verifier、錯誤次數與冷卻期限；不保存 PIN 明文，也不取代 `CryptoModule` 的裝置私鑰保護。啟用後
App 進入 background 會立即鎖定；根層 `AppLockGate` 遮蔽既有 Navigator 內容直到驗證成功。
可替換的 biometric adapter 在 Android/iOS 只要求 biometric-only 系統驗證；啟用前必須先成功驗證一次，取消、失敗或系統鎖定時仍保留 PIN 備援。生物辨識設定與 verifier 一起保存在 secure storage，但不保存任何生物特徵資料。
App Lock 只透過 Event Bus 發出 enabled／locked／notification privacy flags；Push module 的 privacy-first presentation policy 在狀態未知、App 已鎖定或使用者要求隱藏時只回傳通用通知文字。遠端 push payload 不含 sender 或 preview，只有本機完成解密的資料才可能在明確允許時顯示。

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

Mailbox 在前景進入時立即執行一次冪等同步，之後一般模式每 60 秒、Low Power
每 5 分鐘同步一次；App 進背景即停止排程，仍以 Push 喚醒與使用者手動同步作為
背景／失敗保底，不維持長連線。

Storage Manager 是無網路、無背景常駐的本機模組。它量測 SQLite 實體資料庫、
可重建快取與未來附件範圍；清理流程必須先顯示預覽並再次確認。目前僅會刪除
`storage_cache_entries` 的可重建快取索引，身份、裝置／金鑰、安全設定、聊天紀錄與
`mailbox_pending_queue` 的未送密文永遠不在清理範圍內。

Smart Notification 將每個聊天室的 `muted`／`allow_preview` 偏好保存於 SQLite。
`muted` 直接抑制 provider 的通知建立；預覽則必須同時經聊天室明確允許與
`NotificationPresentationPolicy` 的 App Lock 檢查。狀態未知、App 已鎖定或使用者
開啟通知隱私時，一律回傳不含寄件者與內容的通用文字。此層是 provider-neutral，
不含 FCM/APNs SDK 或系統通知權限處理。

Translation Module 預設沒有 provider，且使用者未設定明確同意前不能呼叫 provider。
翻譯 cache 以 message ID、provider ID、目標語言與原文 SHA-256 組合判定；只保存在
`message_translations`，不改寫 `chat_messages` 的原始 payload。使用者可清除單則
翻譯結果；接入任何雲端 provider 前，必須在 UI 說明實際資料傳送對象與條款。

Attachment Module 預設 disabled，不持有相機、麥克風、檔案控制代碼或背景下載。
圖片與語音訊息只承載版本化 metadata：attachment ID、允許的 MIME、大小與密文
SHA-256；圖片上限 10 MiB、語音上限 25 MiB。下載控制器支援手動下載、取消、
失敗重試與狀態回報；只有使用者明確允許且非 Low Power 的圖片可自動下載，語音
一律手動下載。實際 encrypted transfer／解密、檔案保存與裝置權限留待外部 Gate。

Desktop Link Module 是無網路、無背景常駐的 V3 主機安全核心。SQLite v13
`desktop_link_authorizations` 只保存副端 device ID、顯示名稱、公開金鑰 fingerprint、
授權後同步切點與撤銷時間，不保存私鑰、訊息內容或待傳 payload。手機主裝置必須以明確
操作授權；主裝置自身不得成為副端，同一 device ID 的 fingerprint 改變會 fail-closed。
同步 adapter 必須只取 `MessageEnvelope.createdAt > authorized_after` 的資料，秒級
timestamp 同秒訊息亦保守拒絕；撤銷後 service 立即拒絕新的同步選取並透過 Event Bus
發出狀態變更。

SQLite v14 `desktop_link_pairing_requests` 另保存一次性 QR 配對請求的 request ID、目標
主裝置、宣告的副端名稱／fingerprint、發送與到期秒數及處理狀態；不保存 QR 原文、私鑰
或聊天內容。頁面可掃描或貼入嚴格版本化 payload，先顯示裝置名稱與 fingerprint；只有
使用者在確認對話框明確同意後才呼叫授權。請求必須指向目前主裝置、有效期介於 30–600 秒，
並以 `pending → confirming → confirmed/rejected` 狀態避免重放。QR payload 仍是未驗證
聲明，不等於桌面端私鑰持有證明。

SQLite v15 將短效 pairing request schema 升級為包含 32-byte X25519 `public_key`，並要求
`public_key_fingerprint` 可由 device ID 與該公開金鑰重新推導。`DesktopLinkPairingRequestIssuer`
可由副端公開金鑰產生 canonical request；手機端會拒絕 public key／fingerprint 不一致的 QR。
升級時會作廢 v14 未綁定公開金鑰的暫存 request，因為它們無法安全補齊 binding；Desktop Link
授權、聊天與身份資料不受影響。這只排除了 QR 任意聲稱 fingerprint，仍未證明掃出 QR 的
桌面端持有對應私鑰。

此資料層仍未包含桌面端 pairing requester、signed key-possession challenge、桌面 transport、
每副端重新加密或副端金鑰銷毀，因此不能把它當作「已可同步」、「已驗證桌面身份」或
「已證實撤銷後無法解密」的 runtime 證據。

## 運行模式

正確：平常休眠 → 收推播或開聊天室 → 建立 P2P → 傳完短暫維持 → 閒置斷線 → 進背景關閉 P2P。
避免：一啟動就永久連線、每幾秒 heartbeat、同時跟所有好友維持 P2P、背景長時間 WebRTC。

## App 啟動流程

`main.dart` → 建立 `ModuleContext`（EventBus / Config / Logging / ResourcePolicy / DB）
→ 只 `init` 基礎模組（見 §9 規格範例）→ 高耗能模組不 active。

## 資源佔用目標（規格 §21 摘要）

冷啟動 < 3s；閒置記憶體 < 150MB；背景 P2P 永遠關閉；一般模式前景
heartbeat 60s、同時 P2P 連線最多 3 條、閒置 2 分鐘斷線。Low Power Mode
由獨立模組以 SQLite 保存，切換時透過 Event Bus 即時套用：heartbeat 180s、
同時 P2P 最多 1 條、閒置 1 分鐘斷線、停用圖片自動下載及重型模組自動啟動。
聊天室載入最近 50 則；離線密文保存 7–30 天。

## 版本路線圖

- **V1** 核心可用：1:1 文字、P2P DataChannel、離線密文信箱、推播、SQLite、Presence、E2EE、模組化、低功耗。
- **V1.5** 安全 / 省資源：App Lock、Low Power、Safety Number、背景斷 P2P、閒置斷線、通知隱藏內容。
- **V2** 體驗：Emoji、Reaction、貼圖、語音 / 圖片訊息、單則翻譯、Storage Manager、Smart Notification、Username。
- **V3** 多裝置 / 進階：Desktop Link 主機安全核心、一次性 QR 請求檢閱／明確確認與
  公開金鑰／fingerprint binding 已完成；電腦副端 UI、私鑰持有 proof、實際多裝置同步、
  撤銷後 per-device 加密驗證、檔案傳輸、語音通話、匯出匯入、Contact Discovery 仍待實作。
- **V4** 社群 / 視訊：視訊通話、小群組、廣播、共享筆記 / 待辦、訊息排程。
- **V5** AI / 生態：即時字幕、寫作輔助、聊天摘要、離線翻譯語言包、貼圖開源生態。

## Offline Mailbox v1

P2P 連線失敗時，App 才把既有 `EncryptedEnvelope` 上傳 mailbox。Server 只保存必要 routing metadata 與 ciphertext；recipient 完成認證、replay 檢查及本機 SQLite 寫入後才送 `DELIVERED` ACK。

狀態只允許 `STORED → DELIVERED → READ`，未送達密文可因 TTL 轉為 `EXPIRED`，不得倒退。完整 API、ACL、quota、TTL、冪等與刪除條件見 [`mailbox_api.md`](mailbox_api.md)。

Flutter 本機 schema v5 使用 `mailbox_pending_queue` 保存尚未上傳的 encrypted envelope。Queue 以 message ID 冪等、使用短期 lease 防止並行處理，crash 後 lease 到期可重新 claim；失敗最多重試 8 次，採 5 秒起始、15 分鐘上限並含 jitter 的 exponential backoff。

`MessageTransportCoordinator` 對每則訊息只加密一次：優先送 P2P，失敗時把同一 encrypted envelope 寫入 pending queue 並呼叫 mailbox。Queue 等待時訊息為 `PENDING`，server 接受後更新為 `STORED`；本機測試聊天室沒有 peer device 時不啟動網路傳送。
