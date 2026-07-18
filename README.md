# P2P Modular Messenger

Mobile-first、模組化、低成本、去中心化優先的 P2P 通訊軟體。

依據《P2P Modular Messenger Codex 開發總規格 v1.2》建置。核心原則：**先核心、後模組；先手機、後電腦；先文字、後影音；先低資源、後高功能。**

## Monorepo 結構

```text
p2p-chat/
  ├─ mobile_desktop_app/   Flutter 手機主端 + Desktop 副端（Dart）
  ├─ java_backend/         Java Spring Boot 原型後端（signaling / mailbox / admin）
  ├─ cloudflare_worker/    低成本 signaling / invite code / mailbox（後續）
  └─ docs/                 架構、訊息 schema、安全、成本說明
```

## 開發順序（Stage / Sprint）

本專案嚴格依規格 §22 執行順序推進，每個 Sprint 完成後保持「可編譯、可測試、可回退」。

| Sprint | 內容 | 狀態 |
|---|---|---|
| 0 | Repo 與規範初始化 | ✅ 已完成 |
| 1 | Flutter Core 架構（Module / EventBus / Registry / Service） | ✅ 已完成 |
| 2 | SQLite 與本機聊天 UI | ✅ 已完成 |
| 3 | Java Spring Boot 原型後端 | ✅ 已完成（Docker Compose + PostgreSQL smoke test 通過） |
| 4 | Identity / Contact / Device 整合 | ✅ Android 雙 AVD 邀請、雙向聯絡人同步與公鑰信任通過 |
| 5 | Signaling 與 WebRTC P2P | 🚧 Android 雙 AVD authenticated encrypted E2E 通過；Desktop/資源驗收待補 |
| 6 | Crypto 與安全儲存 | 🚧 Android 實作與 runtime 驗證完成；iPhone 驗收依使用者指示暫停 |
| 7 | Offline Mailbox 與 ACK | ✅ S7-01～06 與 Android alpha 雙 AVD 驗收完成 |
| 8+ | Push / Presence / V1.5 安全 / 低功耗 / 貼圖 / 多媒體 / 多裝置 / 通話 … | 🚧 低頻 Presence、FCM HTTP v1 worker 完成；V1.5 Low Power 的 SQLite 偏好、即時策略、Presence 降頻、P2P 連線／閒置限制、自動下載與設定 UI 已完成，Safety Number 核心/scanner adapter 與 App Lock PIN／Argon2id／生物辨識／通知隱私策略／背景自動鎖定亦完成；真實耗電、FCM、相機掃碼、生物辨識與雙實機待驗 |

完整路線圖見 [`docs/architecture.md`](docs/architecture.md)。

Offline Mailbox v1 契約見 [`docs/mailbox_api.md`](docs/mailbox_api.md)。

低頻 Presence 契約見 [`docs/presence_api.md`](docs/presence_api.md)。

Push token 與 notification outbox 契約見 [`docs/push_api.md`](docs/push_api.md)。

可執行、具依賴與驗收條件的工作分解見 [`docs/project_tasks.md`](docs/project_tasks.md)。

日常、完整、native 與端對端測試指令及結果判讀見 [`docs/testing.md`](docs/testing.md)。

不持有本機 Android 手機時，可使用 GitHub OIDC 將 instrumentation APK 送至 Firebase
Test Lab 實體裝置；workflow 預設只做免費 preflight，付費 submission 具容量 Gate、
有界排隊與遠端 matrix 取消清理。設定與限制見 [`docs/firebase_test_lab.md`](docs/firebase_test_lab.md)。

接手順序與逐項完成狀態見 [`docs/handoff_checklist.md`](docs/handoff_checklist.md)。每完成一項工作，需在同一次變更中勾選並更新相關文件。

V1 候選版的建置、操作、真機驗收、發布 Gate 與已知限制見
[`docs/release_candidate_v1.md`](docs/release_candidate_v1.md)。目前仍是內部 Android
測試版；雙真機、正式簽章、真實 Push 與 iOS 實機 Gate 完成前不可對外標示為 V1 RC。

## 快速開始（mobile_desktop_app）

需求：Flutter SDK 3.29.0 以上、Dart SDK 3.7.0 以上。本 repo 骨架不含編譯好的產物。

```bash
cd mobile_desktop_app
flutter pub get          # 安裝依賴
flutter run              # 執行（手機模擬器 / 桌面）
flutter test             # 執行單元測試
dart analyze             # 靜態分析
```

目前 Sprint 0–2 產物「不連後端也能在本機建立聊天室、寫入 / 讀取文字訊息」。

## Android Alpha 測試版

目前可安裝的 Android Emulator alpha：

```text
dist/android-alpha/p2p-messenger-android-alpha-debug.apk
SHA-256: 4C9B0117C7D1E299AEC3FD9CBB93A09273D30E597E493641792B49889924F8A0
```

此 APK 以 `10.0.2.2:18080` 連接開發電腦上的 Docker backend，只適用 Android Emulator 與本機測試，不可公開發布。先啟動 backend：

```powershell
cd java_backend
.\scripts\alpha-up.ps1
```

已用兩台 Android 15 x86_64 AVD 驗證：註冊、邀請碼、雙向聯絡人與 fingerprint 同步、1:1 加密文字、P2P 失敗 fallback mailbox、`STORED → DELIVERED → READ`、sender「已讀」，以及前景 60 秒 Presence／背景零 heartbeat。停止 backend 使用 `.\scripts\alpha-down.ps1`。

## 核心開發規則（摘自規格 §0、§26）

1. 所有功能模組化；Core 不依賴任何單一功能模組。
2. 模組之間只透過 Event Bus 溝通，不直接呼叫彼此內部實作。
3. 聊天內容不得以明文送到伺服器；私鑰不得明文保存。
4. 手機端不長時間背景維持 WebRTC；預設低耗能、低記憶體、低網路。
5. 第一版專注 1 對 1 文字通訊；高耗能功能作為後續可選模組。
6. 每個模組都要有 `init / activate / sleep / dispose` 生命週期。
7. 新功能新增 module，不大改 Core；資料庫 migration 可追蹤。
8. 每個 Sprint 保持可編譯、可測試、可回退。

詳見 [`AGENTS.md`](AGENTS.md)。
