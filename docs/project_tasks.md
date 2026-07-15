# P2P Modular Messenger 專案任務清單

依據《P2P Modular Messenger Codex 開發總規格 v1.2》整理。此文件以可執行、可驗收及可追蹤依賴為原則；`P0` 為 V1 MVP 必要工作，`P1` 為 V1.5，`P2` 以後為後續版本。

> 目前執行範圍以 v1.2 藍圖的 **V1 核心可用版** 為限。V1.5～V5
> 僅保留 backlog，不在 V1 release candidate 完成前開始實作。

## 狀態定義

- `DONE`：已有實作與文件；仍須以專案測試確認環境可重現。
- `TODO`：尚未開始或尚無可驗收產物。
- `BLOCKED`：前置任務未完成。
- 每項任務完成時，需同時更新測試、README 與受影響的 `docs/` 文件。

## V1 MVP 里程碑

### EPIC-00 Repository 與規範（Sprint 0，P0）— DONE

| ID | 任務 | 依賴 | 驗收條件 |
|---|---|---|---|
| S0-01 | 建立 monorepo 與 App、Java backend、Worker、docs 目錄 | — | 目錄與 README 可讓新開發者理解各元件責任 |
| S0-02 | 建立開發規範與架構文件 | S0-01 | `AGENTS.md`、架構、訊息、安全、成本文件齊全 |
| S0-03 | 建立 Git 忽略規則與快速開始指令 | S0-01 | 不追蹤建置產物或機密；README 列出執行與測試方式 |

### EPIC-01 Flutter Core（Sprint 1，P0）— DONE

| ID | 任務 | 依賴 | 驗收條件 |
|---|---|---|---|
| S1-01 | 實作 `AppModule` 與生命週期狀態 | S0-01 | 模組支援 init、activate、sleep、dispose；非法轉換可預期 |
| S1-02 | 實作 Module Registry 與依賴注入 | S1-01 | 至少三個模組可註冊、查找並按順序釋放 |
| S1-03 | 實作型別化 Event Bus | S1-01 | 可訂閱、發布、取消訂閱，dispose 後不洩漏 listener |
| S1-04 | 實作 Route、Config、Logging、Resource Policy service | S1-02 | App Shell 可啟動，服務可由 context 取得 |
| S1-05 | Core 單元測試與靜態分析 | S1-01..04 | `flutter test` 與 `dart analyze` 通過 |

### EPIC-02 SQLite 與本機聊天（Sprint 2，P0）— DONE

| ID | 任務 | 依賴 | 驗收條件 |
|---|---|---|---|
| S2-01 | 建立 SQLite service 與版本化 migration | S1-02 | 可建立、升級資料庫；schema 變更可追蹤 |
| S2-02 | 建立 conversation、message model 與 DAO/repository | S2-01 | 訊息符合 `type + payload` schema，狀態值受約束 |
| S2-03 | 建立聊天室列表與聊天頁 | S2-02 | 不連後端可建立聊天室並寫入、讀取文字訊息 |
| S2-04 | 實作最近 50 則與舊訊息分頁 | S2-03 | 初次最多載入 50 則；向上滑可載入更舊訊息且無重複 |
| S2-05 | Repository、schema 與分頁測試 | S2-02..04 | 正常、空資料與分頁邊界測試通過 |

> 現況註記：README 將 Sprint 0–2 標為完成，且已有相應程式與測試；正式關閉里程碑前仍應在具 Flutter SDK 的環境執行 S1-05、S2-05。

### EPIC-03 Java Spring Boot 原型後端（Sprint 3，P0）— DONE

| ID | 任務 | 依賴 | 驗收條件 |
|---|---|---|---|
| S3-01 | ✅ 建立 Spring Boot 專案、profiles 與健康檢查 | S0-01 | App 可啟動，health endpoint 回傳 healthy |
| S3-02 | ✅ 建立 PostgreSQL 開發環境與 migration | S3-01 | Docker Compose 一鍵啟動；空 DB 可自動 migration |
| S3-03 | ✅ 實作 users、devices、contacts domain | S3-02 | 可註冊 user 與 device public key；唯一性與輸入驗證完備 |
| S3-04 | ✅ 實作 invite code 建立與兌換 API | S3-03 | 有效碼可加好友；過期、重用、猜測攻擊有防護 |
| S3-05 | ✅ 實作認證與授權 | S3-03 | JWT 短效存取流程；使用者不可讀寫他人裝置資料 |
| S3-06 | ✅ 建立 OpenAPI、整合測試與 Dockerfile | S3-03..05 | OpenAPI、核心 API 與 Docker Compose/PostgreSQL 容器 smoke test 通過 |

### EPIC-04 Identity、Contact、Device（Sprint 4，P0）— DONE（Android Alpha）

| ID | 任務 | 依賴 | 驗收條件 |
|---|---|---|---|
| S4-01 | ✅ 完成 Identity、Contacts、Devices 模組骨架與本機 schema | S2-01 | 各模組遵守生命週期及分層規範 |
| S4-02 | ✅ 產生並保存 local userId、deviceId | S4-01 | 重啟後 ID 穩定；重設身份需明確確認 |
| S4-03 | ✅ 整合 backend 的 user/device 註冊 | S3-03,S4-02 | App 可註冊裝置及 public-key placeholder，不記錄私鑰 |
| S4-04 | ✅ 實作邀請碼與 QR payload 加好友 | S3-04,S4-03 | 兩台測試裝置能建立聯絡人 |
| S4-05 | ✅ 建立整合測試 | S4-04 | Flutter client/backend 與雙 Android AVD 邀請、雙向聯絡人/fingerprint 同步通過；真機納入 V1-01 |

### EPIC-05 Signaling 與 WebRTC P2P（Sprint 5，P0）— IN PROGRESS（Android 雙 AVD 完成，Desktop/真機資源待驗）

| ID | 任務 | 依賴 | 驗收條件 |
|---|---|---|---|
| S5-01 | ✅ 定義 signaling message schema 與 session 狀態機 | S4-05 | offer、answer、ICE、close、error 具版本與關聯 ID |
| S5-02 | ✅ 實作 Spring WebSocket signaling | S3-05,S5-01 | 僅驗證過的聯絡人裝置可交換 signaling；production 使用精確 origin allowlist 並禁止 `*` |
| S5-03 | ✅ Flutter 整合 WebRTC DataChannel | S5-01 | Android production adapter、debug build 與雙 AVD encrypted DataChannel 通過；Desktop 另行驗收 |
| S5-04 | ✅ 實作 P2P session lifecycle | S5-02,S5-03 | close、sleep、timeout、有限重試、error 與 App 背景釋放測試通過 |
| S5-05 | ✅ 經 P2P 傳送文字 envelope | S2-02,S5-04 | deterministic two-device envelope test 通過；實機由 S5-06 驗收 |
| S5-06 | 🚧 雙裝置端對端測試與資源檢查 | S5-05 | 雙 Android AVD authenticated encrypted E2E 通過；兩台真機與資源量測納入 V1-01/V1-03 |

### EPIC-06 Crypto 與安全儲存（Sprint 6，P0）— IN PROGRESS

| ID | 任務 | 依賴 | 驗收條件 |
|---|---|---|---|
| S6-01 | ✅ 撰寫 threat model 與選定加密協定/函式庫 | S4-05 | 定義 `P2P_BOX_V1`、重放防護、輪替、遺失與限制；選用 libsodium 高階 API |
| S6-02 | 🚧 產生裝置金鑰並接 Android Keystore / iOS Keychain | S6-01 | 已實作 libsodium `SecureKey`、平台 secure storage、穩定錯誤碼與 Android native build；Windows 測試待 Visual C++ toolchain，實機 secure storage 待驗 |
| S6-03 | ✅ 實作有版本的 encrypted envelope | S6-01 | `P2P_BOX_V1`、24-byte nonce、sender/recipient key id、combined MAC+ciphertext、版本與大小驗證；5 項 schema tests 通過 |
| S6-04 | ✅ P2P 改傳密文並驗證完整性 | S5-05,S6-02,S6-03 | Android 真實 libsodium failure paths、SQLite replay、encrypted-only DataChannel 與兩個 AVD/App process authenticated E2E 通過；iOS 由 S6-IOS tasks 驗收 |
| S6-05 | ✅ 建立 key fingerprint 與變更偵測 | S6-02 | App 本機重算 fingerprint；同裝置 key 變更保存 pending、發出安全事件並阻斷傳送，明確重新信任後才啟用 |
| S6-06 | ✅ Crypto 測試與敏感資訊日誌稽核 | S6-03..05 | round-trip、竄改、nonce 唯一性、版本、錯 key、replay 與 key change 測試通過；統一 logger 遮蔽 token/key/plaintext/ciphertext/payload |
| S6-IOS-01 | 🚧 建立 iOS runner 與 Xcode 簽章設定 | Android S6-02,S6-04 驗收 | macOS Pods/workspace、Podfile.lock、Team 與 automatic signing 已完成；Xcode 16.4 不支援 iOS 26.5.2，build/安裝待 Xcode 26.x |
| S6-IOS-02 | iPhone Keychain、libsodium 與 WebRTC 實機驗收 | S6-IOS-01 | secure storage 跨重啟、真實 crypto failure paths、encrypted DataChannel 與背景 sleep 通過 |
| S6-IOS-03 | iPhone 跨平台雙裝置 E2E 與文件 | S6-IOS-02 | 兩台 iPhone 或 iPhone+Android 完成 E2E、資源檢查與文件更新；S6-05 已因 Windows/macOS 環境阻塞先行完成，但本項仍是關閉 Sprint 6 的必要條件 |

### EPIC-07 Offline Mailbox 與 ACK（Sprint 7，P0）— IN PROGRESS

| ID | 任務 | 依賴 | 驗收條件 |
|---|---|---|---|
| S7-01 | ✅ 定義 mailbox API、ACL、quota、TTL 與 ACK 狀態機 | S6-03 | 僅收件裝置可下載；嚴格 `STORED → DELIVERED → READ`/`EXPIRED`；具大小、容量與速率限制；13 項 schema 回歸通過 |
| S7-02 | ✅ 實作密文上傳、拉取與刪除 backend | S7-01 | Flyway V4/V8、JWT/device/contact ACL、冪等 upload、HMAC signed opaque inbox/ACK cursor、穩定分頁、PostgreSQL 多 instance 共用 rate limit、quota/TTL cleanup 與 ciphertext 清除完成 |
| S7-03 | ✅ 建立本機 pending queue 與退避重試 | S2-01,S7-01 | SQLite v5 queue 可跨重啟保存；lease 可回收 crash 中工作；最多 8 次、5 秒起始/15 分鐘上限 exponential backoff + 20% jitter |
| S7-04 | ✅ P2P 失敗 fallback 至 mailbox | S5-04,S6-04,S7-02,S7-03 | 同一密文先走 P2P；失敗後冪等 enqueue/upload，等待重試為 PENDING，mailbox 成功為 STORED，不重複建立訊息 |
| S7-05 | ✅ 實作 DELIVERED、READ ACK 與冪等處理 | S7-04 | 認證並本機保存後才 DELIVERED；receipt mapping 支援 READ；重複下載/replay 重送 ACK，不重複寫入 |
| S7-06 | ✅ 離線與故障整合測試 | S7-05 | Queue 跨重啟、lease recovery、過期狀態、upload retry、重複投遞、replay 與 ACK 遺失重送測試通過 |

### EPIC-08 Push 與低頻 Presence（Sprint 8，P0）— IN PROGRESS

> Android Emulator alpha 已於 2026-07-12 完成邀請、1:1 encrypted message、mailbox fallback、DELIVERED/READ、sender 已讀、低頻 Presence 與 notification outbox。2026-07-13 已完成多 instance FCM HTTP v1 worker、Flyway V9 lease/retry 與 token invalidation；實際 FCM 仍因 Firebase credentials 未提供而未驗證。

| ID | 任務 | 依賴 | 驗收條件 |
|---|---|---|---|
| S8-01 | 🚧 註冊、更新與撤銷 FCM token | S4-03 | API/Flutter service、JWT ownership、AES-GCM at-rest、key rotation、撤銷清除與 retention 完成；Firebase SDK 真實 token 待 credentials |
| S8-02 | 🚧 mailbox 新訊息觸發不含明文的推播 | S7-02,S8-01 | FCM HTTP v1 adapter、Flyway V9、多 instance claim/lease、8 次 bounded retry、stale worker/token 防護與 data-only payload 已通過 51 項 Java tests 及 PostgreSQL worker tests；真實 credentials/實機通知待驗證 |
| S8-03 | 🚧 推播開啟聊天室並同步 mailbox | S7-05,S8-02 | provider-neutral payload parser、cold/warm launch source、冪等 coordinator 與 mailbox refresh 已完成並通過單元測試；真實 FCM 導向待 credentials |
| S8-04 | ✅ 實作低頻 Presence 與 lastSeen 顯示 | S4-03 | JWT/device ownership、contact ACL、Flyway V5；前景約 60 秒更新、背景停止，雙 AVD timestamp/UI 驗收通過 |
| S8-05 | 🚧 推播、生命週期與耗電驗證 | S8-03,S8-04 | 背景無 WebRTC/heartbeat；聊天列表手動同步、失敗保留本機聊天與防重入 tests 已完成；通知權限拒絕實機與耗電量測待驗 |

### EPIC-09 V1 整合、品質與發布門檻（P0）— BLOCKED

| ID | 任務 | 依賴 | 驗收條件 |
|---|---|---|---|
| V1-01 | 🚧 建立兩台真機的完整 E2E 測試腳本 | S8-05 | 雙 AVD 已分別通過 encrypted P2P runner，以及真實 sodium offline mailbox、ACK 遺失、App force-stop/restart、DELIVERED/READ 與 sender 本機 READ 狀態；兩台真機、實際斷網與資源量測待驗 |
| V1-02 | ✅ 安全與隱私稽核 | S6-06,S7-06,S8-05 | 私鑰/明文不上傳、不進 log；修復 ACK/origin/cursor、signaling concurrent writes、push token at-rest、共享 mailbox rate limit 與 FCM outbox worker；Java 52 tests、Flutter 82 tests、analyze 通過，殘餘風險見 `security_audit_v1.md` |
| V1-03 | 🚧 資源目標量測 | V1-01 | Android 15 AVD profile 基線已重跑兩次：冷啟動中位數 2646/2690ms、閒置 PSS 110.22/111.54MB、背景 TCP 0；真機 release candidate、最差啟動時間、實際網路與電量仍待驗 |
| V1-04 | 🚧 故障恢復與資料完整性測試 | V1-01 | SQLite 關閉／重開、ACK 遺失重投、v1～v5 升級至 v7，以及 Android AVD `am force-stop` 後同一 DB 重啟與 READ 閉環已通過；真機 OS kill 與實際斷網待驗 |
| V1-06 | ✅ 已完成：多語言介面與語言切換 | S2-03 | Flutter gen-l10n/ARB 首批支援繁體中文與英文；預設跟隨系統，App 內可切換並以 SQLite 跨重啟保存；主要 UI、日期、訊息狀態、Presence、錯誤與 tooltips 已 localization；unsupported locale fallback 至 `zh_TW`，7 項 localization 專項、90 項可執行 host tests 與 analyze 通過 |
| V1-05 | 🚧 發布候選版文件與已知限制 | V1-02..04,V1-06 | RC、artifacts、Java/Flutter/PostgreSQL CI、Compose/Caddy/preflight、backup/restore、staging retention、bounded logs/monitor 與多語言介面已建立；localhost TLS/WSS、restore drill 與 retention fixtures 通過。V1-01/03/04 真機、正式簽章/registry、公開 DNS/ACME、真實 off-host object/receipt、排程/外部告警、Push/iOS 與最終 artifact 待完成 |

## V1.5 安全與省資源（P1）

| Epic | 範圍 | 前置 | 完成條件摘要 |
|---|---|---|---|
| EPIC-10 | Low Power Mode | V1-05 | 可降低 presence、停用自動下載、限制連線；背景保持零 P2P |
| EPIC-11 | App Lock | V1-05 | PIN/生物辨識、離開後自動鎖定、通知隱藏；不得取代裝置金鑰保護 |
| EPIC-12 | Safety Number | S6-05 | 顯示與 QR 驗證；key/device 變更有阻斷式警告與重新信任流程 |

## V2–V5 Backlog

| 優先序 | Epic | 版本 | 核心驗收焦點 |
|---|---|---|---|
| P2 | Emoji、Reaction、內建貼圖 | V2 | 事件冪等；貼圖只傳 ID；離線同步可用 |
| P2 | 貼圖包管理與製作 | V2 | manifest schema、大小/格式限制、zip-slip 防護、授權資訊 |
| P2 | 語音與圖片訊息 | V2 | 按需取得資源、加密保存、行動網路不自動下載大檔 |
| P2 | 單則翻譯 | V2 | 原文不改寫；本機快取；雲端須明確 opt-in |
| P2 | Storage Manager、Smart Notification | V2 | 清理行為可預期且不刪私鑰；通知可按聊天室設定 |
| P3 | Desktop Link、Device Sync、Revoke | V3 | 手機授權；只同步新訊息；撤銷後副端不能再解密新訊息 |
| P3 | File Transfer、Export/Import | V3 | P2P、進度/取消/重試、SHA-256；備份必須加密 |
| P3 | 1 對 1語音通話 | V3 | 通話結束立即釋放音訊資源，不在背景常駐 |
| P4 | 1 對 1 視訊通話 | V4 | 按需相機/麥克風、不錄影、低功耗畫質與資源釋放 |
| P4 | Small Group、Broadcast | V4 | 3–10 人、群組金鑰；廣播對每位收件者獨立加密 |
| P4 | Shared Notes、Shared Todo | V4 | 本機保存、衝突策略明確、P2P 同步冪等 |
| P5 | Live Caption、Writing Assist、Chat Summary | V5 | AI 預設不上傳；雲端 opt-in；結果可清除 |
| P5 | 模組 marketplace | V5 | 只散佈資料/資產，不動態執行未信任第三方程式碼 |

## 建議執行順序

逐項接手與勾選狀態統一維護於 [`handoff_checklist.md`](handoff_checklist.md)。

1. 先建立符合 `pubspec.yaml` 的 Flutter / Dart 環境，重跑 format、analyze 與完整測試。
2. 補完 S4-05 與 S5-03～S5-06 的真實 backend、實機及雙裝置驗證。
3. Sprint 3 的 Docker Compose、PostgreSQL migration 與 health endpoint smoke test 已完成；後續 backend 變更需重跑。
4. `S6-01` 的安全設計必須在實作加密前完成審查；Crypto、Mailbox 不可只用 placeholder 宣告完成。
5. 完成每個 Epic 後建立里程碑驗收紀錄，V1 必須通過 EPIC-09 才算可發布。
