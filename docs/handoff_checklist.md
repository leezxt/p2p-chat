# P2P Modular Messenger 交接清單

本文件是接手開發與驗收進度的單一清單。完整依賴與驗收條件仍以
[`project_tasks.md`](project_tasks.md) 為準。

目前依使用者指示只實作 v1.2 藍圖的 V1；V1.5～V5 暫停於 backlog。

## 勾選規則

- `[ ]`：尚未完成，或已有程式但尚未通過指定驗證。
- `[x]`：實作、測試與必要文件均已完成，且驗證結果可重現。
- 每完成一項工作，必須在同一次變更中勾選本清單，並更新受影響的 README 或 `docs/` 文件。
- 不可只因程式碼存在就勾選；需要實機、容器或外部服務的項目，必須完成對應環境驗證。

## 目前交接（2026-07-14 01:27 +08:00）

目前目標：建立可重複執行、同時支援 Android Emulator 與 USB 真機的 V1 雙裝置 encrypted P2P 驗收入口；本輪先以兩台 AVD 驗證，不以模擬器取代真機發布門檻。

- [x] **已完成**：確認既有雙裝置 test、registration/invite/contact ACL、signaling 與 backend 啟動資料流
- [x] **已完成**：將 E2E backend/signaling URL 改為可由 `--dart-define` 注入，保留 Emulator 預設值
- [x] **已完成**：兩個 App process 在 contact ACL 建立後才連線，不再依賴外部殘留測試資料
- [x] **已完成**：新增 `tool/verify_android_v1.ps1`，自動啟動乾淨 H2 backend、註冊協調、建立 contact、執行兩裝置測試、收集 log 與清理 backend
- [x] **已完成**：PowerShell parser、Dart format 與 `flutter analyze` 通過
- [x] **已完成**：新 runner 在 `emulator-5554` / `emulator-5556` 通過 encrypted WebRTC/DataChannel E2E
- [ ] **已實作未驗證**：USB 真機 `adb reverse` 路徑與兩台 Android 真機完整流程
- [x] **已完成**：更新 testing、mobile README 與 V1-01 任務狀態
- [x] **已完成**：runner backend 與兩台 AVD 均乾淨停止
- [x] **已完成**：backend loopback-only bind 與 port-in-use fail-fast 防護，雙 AVD 回歸通過
- [x] **已完成**：功能 commit `0a4c7f2` 經 PR #18 合併至 `main`，merge commit `2a0a283`

驗證：PowerShell parser、Dart format、`flutter analyze` 與 `two_device_p2p_test.dart` 通過。`verify_android_v1.ps1 -SenderDevice emulator-5554 -ReceiverDevice emulator-5556` 首次完整執行 186.8 秒通過；加入 loopback/port 防護後以 build cache 重跑 96.1 秒再次通過。backend 使用 H2、Flyway V1～V9，兩端完成 registration、invite/contact ACL、JWT WebSocket signaling、offer/answer/ICE、真實 libsodium encrypted envelope 與 DataChannel。

Runtime：第二次 runner 建立的 backend 已自動停止，port 8081 已釋放。AVD `emulator-5554`、`emulator-5556` 已在本文件停止前更新後正常關閉；`adb devices` 無殘留裝置。

限制：目前 runner 驗證 registration、雙向 contact ACL、JWT WebSocket signaling、offer/answer/ICE、真實 libsodium encrypted envelope 與 DataChannel；mailbox fallback、DELIVERED/READ UI 與斷網/kill process 仍需後續擴充及真機驗收，因此 V1-01/V1-04 尚不可勾選完成。

續接順序：擴充 mailbox/DELIVERED/READ 與 kill-process/斷網腳本，再以兩台 Android 真機執行完整 V1-01/V1-04 驗收；真機通過後進行 V1-03 資源量測。

## 上次交接（2026-07-13 23:51 +08:00）

目前目標：完成 S8-02 FCM outbox worker 的 provider-neutral 核心與 FCM HTTP v1 adapter；真實 Firebase credentials 與 Android/iPhone 實機通知留待外部驗收。

- [x] **已完成**：新增 Flyway V9 `PROCESSING`、dispatch time、lease、lease token、error code 與 dispatch index
- [x] **已完成**：多 instance 短交易 claim、過期 lease recovery 與 stale worker completion 防護
- [x] **已完成**：最多 8 次、5 秒起始、15 分鐘上限退避，以及成功/無 token/暫時/永久/tamper/max-attempt 分類
- [x] **已完成**：以 FCM HTTP v1、Java `HttpClient` 與 Google ADC 取代較大的 Firebase Admin SDK
- [x] **已完成**：`UNREGISTERED` / `NOT_FOUND` 自動撤銷 token、清 ciphertext，並以 token ID/hash 防止舊 response 撤銷新 token
- [x] **已完成**：payload 僅含 `schemaVersion=1`、`type=MAILBOX_AVAILABLE`，HTTP 測試確認不含 notification/sender/conversation/ciphertext/plaintext
- [x] **已完成**：Java 51 tests、PostgreSQL 18.4 worker 8 tests 與 Flyway V1～V9 schema/constraint/index 驗證
- [x] **已完成**：輕量 backend image 建置成功，大小 140,960,449 bytes；新容器 readiness `UP`
- [ ] **已實作未驗證**：真實 FCM credentials、Android 系統通知、cold/warm start、token invalidation 與耗電
- [x] **已完成**：功能 commit `bb6e5cf` 經 PR #16 合併至 `main`，merge commit `540eab0`

本輪另修正 PostgreSQL worker test 的可重複性：stale-token 案例原本固定使用 `replacement-token`，持久化測試 DB 第二次執行會命中跨使用者唯一約束；現在每個 fixture 使用唯一 replacement token，並直接揭露 callback setup 例外。

驗證：`mvn -q test` 共 51 tests、0 failures、0 errors；`NotificationOutboxWorkerTest` 直接連 PostgreSQL 18.4 共 8 tests 全通過。Flyway V1～V9 全部 `success=true`；V9 13 欄、`PENDING/PROCESSING/SENT/FAILED` constraint、attempt constraint 與 `idx_notification_outbox_dispatch` 均存在。新 Docker image 大小 140,960,449 bytes，backend 重建後 readiness `UP`；本段寫入後將停止隔離 Compose project。

Runtime：隔離 Compose project `p2p_fcm_worker_verify` 已在本文件停止前更新後乾淨關閉；backend/PostgreSQL containers、network 與測試 volume 均已移除，ports 55435/18083 已釋放。本輪未啟動 AVD。

限制：`FCM_ENABLED=false`、`PUSH_DELIVERY_ENABLED=false` 預設關閉；啟用需 `FCM_PROJECT_ID` 與 Google ADC。Windows native sodium test 仍缺 Visual C++ workload；iOS/Android 真機、真實 FCM/APNs、斷網/kill process、資源量測仍未完成。

續接順序：取得 Firebase credentials 後驗收 S8-01～S8-03/S8-05；credentials 尚不可用時，進行 V1-01 雙真機 E2E、V1-04 斷網/kill process、V1-03 資源量測，最後整理 V1-05 release candidate。

## 已完成基線

- [x] Sprint 0：Repository 與開發規範初始化
- [x] Sprint 1：Flutter Core 架構與單元測試程式
- [x] Sprint 2：SQLite、本機聊天 UI、分頁與測試程式
- [x] Sprint 3：Java Spring Boot 原型後端實作與核心 API 測試
- [x] S4-01：Identity、Contacts、Devices 模組骨架與本機 schema
- [x] S4-02：產生並保存穩定的 local userId、deviceId
- [x] S4-03：Backend user/device 註冊程式
- [x] S4-04：邀請碼、QR payload 與聯絡人保存程式
- [x] S5-01：Signaling schema 與 session 狀態機
- [x] S5-02：Spring WebSocket signaling

> 上述 Flutter 項目已有程式與測試，但仍須完成下方「環境與基線驗證」，才能視為目前環境可重現。

## 立即接手項目

### 環境與基線驗證

- [x] 安裝並記錄 Flutter `>=3.27.0`、Dart `>=3.6.0` 的實際版本
- [x] 在 `mobile_desktop_app` 執行 `flutter pub get`
- [x] 執行 `dart format --output=none --set-exit-if-changed lib test`
- [x] 執行 `dart analyze` 並修正所有錯誤
- [x] 執行完整 `flutter test` 並記錄結果
- [x] 在 Docker 環境完成 Java backend、PostgreSQL migration 與 health endpoint smoke test

### Sprint 4：Identity、Contact、Device 驗收

- [x] 執行 Identity schema 測試，確認 App 重啟後 userId、deviceId 穩定
- [x] 以真實 backend 驗證 user/device 註冊與授權
- [x] 以兩個獨立 Android AVD 驗證邀請碼加好友與邀請建立方聯絡人同步
- [x] 驗證失效、重複與錯誤邀請碼不會建立聯絡人
- [x] 完成 S4-05 Android alpha 整合測試並同步更新 README 與任務狀態

### Sprint 5：Signaling 與 WebRTC P2P 驗收

- [x] 建立 Android runner，確認 `flutter_webrtc` 可完成 Android debug 編譯
- [ ] 建立並確認 `flutter_webrtc` 可完成 Desktop runner 編譯
- [x] 執行 `flutter test test/modules/two_device_p2p_test.dart`
- [x] 以兩個獨立 Android AVD/App process 完成 authenticated signaling 連線
- [x] 完成 WebRTC offer、answer、ICE 與 DataChannel 建立流程
- [x] 經 DataChannel 傳送 encrypted envelope，且收件端只顯示一次
- [x] 驗證 session close、sleep、timeout、retry 與錯誤狀態
- [x] 驗證 App 進入背景後不維持 WebRTC 常駐連線
- [ ] 記錄雙裝置 E2E 與資源檢查結果，關閉 S5-03～S5-06

## V1 後續實作

### Sprint 6：Crypto 與安全儲存

- [x] 撰寫並審查 threat model，選定維護中的標準加密協定與函式庫
- [ ] 使用 libsodium 產生裝置私鑰，以 Android Keystore / iOS Keychain-backed secure storage 保存，且不對上層提供明文匯出 API（已實作，待 Windows 單元測試與 Android/iOS 實機驗證）
- [x] 定義並實作具版本、nonce、key id 與認證標記的 encrypted envelope
- [x] 將 P2P 文字訊息改為只傳密文，拒絕竄改、重放與錯誤金鑰
- [x] 實作 key fingerprint、公鑰變更偵測與重新信任流程
- [x] 完成 Crypto round-trip、竄改、nonce、版本與敏感日誌測試

### iPhone / iOS 平台驗收（Android 完成後立即執行）

- [x] 在 macOS + Xcode 環境驗證並提交 Flutter `ios/` runner、workspace 與 Podfile.lock
- [x] 設定 Bundle ID、Development Team、automatic signing、最低 iOS 版本與 CocoaPods
- [x] 設定 Keychain entitlements、網路、相機與麥克風用途說明
- [ ] 驗證 `flutter_secure_storage` Keychain 資料跨重啟保存，移除 App 後行為符合安全政策
- [ ] 驗證 iOS libsodium 真實 round-trip、竄改、錯 key、replay 與 inner/outer mismatch
- [ ] 驗證 iPhone WebRTC signaling、offer/answer/ICE、DataChannel 密文與背景 sleep
- [ ] 以兩台 iPhone，或 iPhone + Android，完成雙裝置 E2E 與資源檢查
- [ ] 執行 `flutter analyze`、`flutter test`、`flutter build ios --debug --no-codesign` 與簽章實機 build
- [ ] 完成 iOS README、security、architecture 與本交接文件驗收後，才可關閉 Sprint 6（S6-05 已因 macOS 阻塞先行完成）

### Sprint 7：Offline Mailbox 與 ACK

- [x] 定義 mailbox API、ACL、quota、TTL 與 ACK 狀態機
- [x] Backend 實作密文上傳、拉取、刪除與 TTL 清理
- [x] App 建立可跨重啟保存的 pending queue 與有上限的退避重試
- [x] P2P 失敗時 fallback 至 mailbox，避免重複顯示訊息
- [x] 實作冪等的 DELIVERED、READ ACK 與密文刪除條件
- [x] 完成離線、過期、重送、重複投遞與 ACK 遺失測試

### Sprint 8：Push 與低頻 Presence

- [ ] 實作 FCM token 註冊、更新與撤銷（API/Flutter service 已完成，真實 Firebase token 待 credentials）
- [ ] Mailbox 新訊息觸發不含明文或敏感 metadata 的推播（安全 outbox 已完成，FCM worker 待 credentials）
- [ ] 驗證 cold start、warm start 可開啟正確聊天室並冪等同步 mailbox（provider-neutral parser/coordinator 與單元測試已完成；真實 FCM 待 credentials）
- [x] 實作前景低頻 Presence、lastSeen 與背景停止更新（Android 雙 AVD 驗證）
- [ ] 驗證通知權限拒絕、App 生命週期、背景連線與耗電行為（無 provider／後端離線時的手動同步 fallback 與 tests 已完成）

### V1 發布門檻

- [x] 建立可安裝的 Android Emulator alpha APK，完成邀請、1:1 加密文字、offline mailbox 與 DELIVERED/READ 可視驗收

- [ ] 建立兩台真機的完整 E2E 測試腳本並通過
- [x] 完成安全與隱私稽核，確認私鑰、明文與敏感資料不上傳且不進 log
- [ ] 量測並記錄冷啟動、閒置記憶體、背景連線、網路與電量
- [ ] 完成斷網、殺程序、DB migration、重複訊息與 ACK 遺失的恢復測試（SQLite 重啟、ACK 遺失重投、v1～v5 migration matrix 已通過）
- [ ] 更新 README、架構、安全、成本、操作說明與已知限制
- [ ] 完成 V1 release candidate 驗收

## 本次環境已知限制

- 2026-07-12：專案內已安裝 Flutter 3.44.6 / Dart 3.12.2，路徑為 `.tools/flutter`；未修改系統 PATH。
- Android SDK 36、Build Tools 36.0.0、NDK 28.2.13676358 與 CMake 3.22.1 已安裝；Android alpha 與雙 AVD 已驗證，兩台真機仍待驗。
- Windows runner 缺少 Visual Studio「Desktop development with C++」workload，尚不能完成 Windows Desktop 建置。
- `sodium` 4.0.3 的 Windows host 測試同樣需要 Visual C++ toolchain；目前 `DeviceKeyService` 測試尚不能在 Windows 執行。
- Windows 交叉編譯 Android 的 libsodium 需要 Git Bash 與 GNU make 4.x；本機已安裝 GNU make 4.4.1。
- Docker Desktop 4.79.0、Engine 29.5.3、Compose 5.1.4 已可用；Java backend/PostgreSQL smoke test 已通過。

## 驗證紀錄

### 2026-07-12

- `mvn test`：通過，13 tests、0 failures、0 errors、0 skipped；包含過期邀請碼與 error-dispatch 回歸測試。
- `mvn package -DskipTests`：通過，產生 Spring Boot executable JAR。
- `flutter pub get`：通過，共解析 69 個 dependencies。
- `dart format lib test`：通過，已統一 62 個 Dart 檔案格式。
- `flutter analyze`：通過，No issues found。
- `flutter test`：通過，24 tests、All tests passed。
- `flutter test test/modules/two_device_p2p_test.dart`：通過，1 test、All tests passed。
- `flutter build apk --debug`：通過，Android runner 與 `flutter_webrtc` 原生 plugin 編譯成功。
- `apksigner verify --verbose`：通過，debug APK 使用 v2 signature，1 signer。
- `aapt dump permissions`：確認 APK 具 `INTERNET` 與 `ACCESS_NETWORK_STATE` 權限。
- `java_backend/scripts/app-integration.ps1`：通過，Flutter client 對真實 Spring/H2 backend 完成註冊、JWT、邀請與錯誤路徑驗證。
- 修正 Spring Security ERROR dispatcher：重複註冊與邀請碼錯誤可保留預期的 409/400，不再被改寫成 401。
- `flutter test`：增至 29 tests、All tests passed；新增 P2P connecting、close、sleep/reconnect、timeout/retry 與 signaling error 測試。
- `flutter build apk --debug`：P2P/signaling 生命週期修改後回歸建置通過。
- `flutter test`：增至 32 tests、All tests passed；App hidden/paused/detached 會去重觸發 P2P sleep，resumed 不自動重連。
- `docs/security.md`：完成 S6-01 threat model 與 `P2P_BOX_V1` 選型；查證 `sodium` 4.0.3、`flutter_secure_storage` 10.3.1、libsignal、MLS 與 HPKE 現況。
- `flutter test`：增至 33 tests、All tests passed；production P2P 預設拒絕未加密的 `MessageEnvelope`。
- `flutter build apk --debug`：Threat model 安全閘加入後回歸建置通過。
- S6-02 已實作 `CryptoModule`、`DeviceKeyService`、`SecureKey` 生命週期、平台 secure storage adapter、key id/fingerprint 與 storage failure/corruption handling；Android manifest 已停用 backup。
- `flutter analyze`：加入 S6-02 後通過，No issues found。
- `flutter build apk --debug`：加入 `sodium` 4.0.3 後乾淨建置通過；產物 `app-debug.apk` 為 197,455,958 bytes。Windows 交叉編譯環境使用 Git Bash、GNU make 4.4.1 與 NDK 28.2.13676358。
- `flutter test test/modules/device_key_service_test.dart`：尚未執行成功；Windows 缺少 Visual Studio C++ workload，sodium native build hook 無法建立 Windows libsodium。
- S6-03 新增 `EncryptedEnvelope`：嚴格驗證 crypto version、suite、routing/key IDs、24-byte nonce、combined MAC+ciphertext 與 1 MiB 大小上限；binary getter 回傳副本，`toString` 遮蔽密文。
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test test/modules/encrypted_envelope_test.dart`：5 tests、All tests passed。此測試只載入純 Dart envelope schema，不執行或驗證 libsodium；不得視為 S6-02 或加解密測試通過。
- S6-04 已實作 `EncryptedMessageService`、`SodiumMessageBox`、stored remote key resolver、inner/outer device/key/message binding、穩定 crypto 錯誤碼與 SQLite v3 replay 唯一約束。
- `P2pSessionManager` 已移除 `allowInsecureTestMessages` 後門；DataChannel 只接受/傳送 `EncryptedEnvelope`，無效、錯 session 或解密失敗資料不會發出 `MessageReceived`。
- Backend registration 改送真實 base64url device public key；新增受 JWT、device ownership、revoked 狀態與 fingerprint 限制的 `PUT /api/v1/devices/{deviceId}/key`，可把舊 `pending:` 記錄安全初始化，任意 rotation 回 409。
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test ...`：15 項 crypto schema、fake-box round-trip/竄改/錯 key/mismatch/replay、P2P 與 DB v3 tests 全通過；此結果不包含真實 libsodium primitive。
- 完整 `flutter test`：44 個非原生案例執行通過，`device_key_service_test.dart` 的 native setup 因跳過 hook 無法載入 `sodium_init`，因此完整 suite 不標記通過。
- `mvn test`：公鑰註冊與 key 初始化 API 修改後 13 tests、0 failures、0 errors。
- `NIX_SKIP_SODIUM_BUILD_HOOKS=0 flutter build apk --debug`：production Android build 通過；APK SHA-256 `4127407CF3251EC72CFB5C282640F9E93F919083FB897BE876902FAD8E1ADFEF`。
- 建立 `p2p_api35` 與 `p2p_api35_b` 兩個 Android 15 Google APIs x86_64 AVD；Android Emulator 36.6.11 已安裝。
- `flutter test integration_test/android_crypto_runtime_test.dart -d emulator-5554`：3 tests 全通過；真實 Android secure storage 重載、libsodium round-trip/竄改/錯 key/mismatch/replay，以及 production WebRTC adapter encrypted DataChannel 均通過。
- 雙 AVD E2E：receiver `emulator-5556` 與 sender `emulator-5554` 均通過 `android_two_device_e2e_test.dart`；使用 H2 Spring backend port 8081、JWT device ownership、真實 WebSocket signaling、SDP/ICE、兩個 App process 與 sodium encrypted envelope。
- 修正真實 E2E 發現的 DataChannel readiness race：`PeerAdapter.waitUntilReady` 會在 P2P 傳送前等待 channel open 或 timeout。
- `flutter create --platforms=ios --org com.p2pchat .`：Windows 已成功產生標準 `ios/` runner、Xcode project/workspace、AppDelegate、SceneDelegate、assets 與 RunnerTests。
- iOS 設定：deployment target 13.0、Bundle ID `com.p2pchat.p2pChatApp`、顯示名稱 `P2P Messenger`；Debug/Profile 與 Release 均設定 Keychain entitlements，Info.plist 已補相機、麥克風與區網用途說明。
- iOS plist/entitlements 已以 XML parser 驗證；`flutter analyze` 零問題，P2P 7 項回歸測試通過。
- 已依 Flutter 3.44.6 內建 CocoaPods template 新增 iOS 13 `Podfile`；`flutter_webrtc` podspec 最低 iOS 13，secure storage/sqflite 最低 iOS 12，與 project target 相容。
- 新增 `tool/verify_ios.sh`：macOS 上依序執行 pub get、pod install、analyze、完整 tests、no-codesign build，設定 `IOS_DEVICE_ID` 後再跑 iPhone native integration test。
- `flutter build ios`：Windows Flutter 不提供 iOS build subcommand；Podfile/CocoaPods、Development Team、Xcode build、簽章與 iPhone runtime 必須在 macOS 完成。
- S6-05 新增 SQLite schema v4 `remote_key_trust`；App 會本機重算 remote fingerprint，首次邀請建立 TOFU 信任，同裝置 key 變更只保存 pending、發出 `RemoteDeviceKeyChanged` 並阻斷 resolver，呼叫 `trustPendingKey` 後才恢復。
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test test/modules/remote_key_trust_test.dart test/modules/contact_service_test.dart test/modules/identity_schema_test.dart test/modules/encrypted_message_service_test.dart test/modules/two_device_p2p_test.dart`：9 tests、All tests passed。此組使用 fake crypto 或純 Dart/SQLite 路徑，不取代先前 Android 真實 libsodium 實機驗證。
- `flutter analyze`：S6-05 修改後通過，No issues found。
- `java_backend/scripts/smoke.ps1`：Docker image 建置完成，PostgreSQL 與 Spring readiness smoke test 通過；測試結束後 Compose containers 已停止並移除。
- 獨立 Compose project `p2p_smoke_verify2`：PostgreSQL 與 backend container health 均為 `healthy`，readiness `UP`；Flyway v1～v3 全部 `success=true`，建立 `app_metadata`、`contacts`、`devices`、`invite_codes`、`users` 與 `flyway_schema_history`，OpenAPI 可讀取 6 條 paths。臨時 containers、network、volume 已移除。
- S6-06：`LoggingService` 統一遮蔽 bearer/JWT、token、secret/private key、plaintext、ciphertext 與 payload，包含錯誤 stack trace；新增可注入 `LogSink` 供自動化驗證。
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test test/core/logging_sensitive_data_test.dart test/modules/encrypted_envelope_test.dart test/modules/encrypted_message_service_test.dart test/modules/sqlite_replay_protection_test.dart test/modules/remote_key_trust_test.dart test/modules/two_device_p2p_test.dart`：16 tests、All tests passed；包含 nonce 不重用與敏感輸出遮蔽。
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test test/modules/p2p_session_lifecycle_test.dart`：6 tests、All tests passed。
- `flutter analyze`：S6-06 修改後通過，No issues found。
- `flutter build apk --debug`：第一次因 process PATH 只找到 WSL bash 而失敗；加入 Git Bash/GNU make 後重跑超過 4 分鐘工具上限，被 timeout 中止，未取得新的 build 成功結果。本次遺留的 `dart` PID 32256、`dartvm` PID 22336、`bash` PID 7540/30360 與 `make` PID 7820/15028/22860/24012/25112/30756 將於本交接更新後停止；既有 Gradle daemon 不處理。
- 上述 timeout 遺留的 `dart/dartvm/bash/make` 子程序已在交接更新後停止，檢查無殘留；未停止既有 Gradle daemon 或其他較早啟動的程序。
- 使用者指示暫停 iPhone/macOS 驗收，保留 S6-IOS-01～03 與 iOS 實機項目未完成；目前開發主線改為 Sprint 7。
- S7-01 新增 `docs/mailbox_api.md` 與 Flutter `MailboxDeliveryState`/`MailboxAck`：定義 JWT/device ownership ACL、contact relationship、冪等鍵、1 MiB 密文、7 天預設/30 天上限 TTL、device quota、rate limit、opaque cursor、ACK/tombstone 刪除條件與穩定錯誤碼。
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test test/modules/mailbox_ack_test.dart test/modules/message_envelope_test.dart test/modules/encrypted_envelope_test.dart`：13 tests、All tests passed；狀態倒退、未知狀態、錯版本與非法 ACK 均拒絕。
- `flutter analyze`：S7-01 修改後通過，No issues found。

## 目前續接點

### 2026-07-13 Session Close

- **已完成**：PR #6 `Test SQLite migration matrix` 已合併至 GitHub `main`，merge commit `612d024`；本機已 fast-forward 同步。
- **已完成**：本日完成 provider-neutral notification launch coordinator、手動 mailbox sync、SQLite/ACK 跨重啟完整性與 v1～v5 升級至 v6 migration matrix。
- **已完成**：目前非 Windows-native Flutter suite 79 tests 全通過，`flutter analyze` 零問題；V1.5～V5 已依使用者指示暫停於 backlog。
- **已實作未驗證**：真實 FCM/APNs、iPhone Keychain/libsodium/WebRTC、兩台真機 E2E、通知權限與資源量測仍需要 credentials、相容 Xcode 或實機環境。
- **未完成**：V1-02 安全與隱私總稽核、真機斷網／kill process、V1 資源量測與 release candidate 文件。
- 本次收尾未啟動、停止或修改 Docker、AVD 與其他外部程序；既有 runtime 狀態未重新檢查。
- 下次第一步：從 `main` 建立新分支，執行 V1-02 安全與隱私稽核；發現問題時依風險分級修復並補測試。

### 2026-07-13 V1 Scope And SQLite Migration Matrix

- Git 狀態：branch `codex/sqlite-migration-matrix`，功能 commit `a6f5ac1`，Draft PR [#6 Test SQLite migration matrix](https://github.com/leezxt/p2p-chat/pull/6)。
- **已完成**：依使用者指示將目前開發範圍鎖定為 v1.2 藍圖的 V1 核心可用版；V1.5～V5 只保留 backlog。
- **已完成**：PR #5 `Test mailbox integrity across restart` 已合併至 `main`，本機同步至 merge commit `cfc7d41`。
- **已完成**：新增 v1、v2、v3、v4、v5 五種舊版 SQLite fixture，全部使用 production `kMigrations` 建立與升級至 v6。
- **已完成**：驗證 conversation/message、identity/device/contact、crypto replay、remote key trust 與 pending queue 依其版本保留；v2/v3 contact public key 可在 v4 migration 正確 backfill 至 trust table。
- **已完成**：migration matrix 5 tests 全通過；非 Windows-native Flutter suite 79 tests 全通過，`flutter analyze` 零問題，format 通過。
- **已實作未驗證**：V1-04 剩餘 Android/iOS 真機 kill process 與實際網路切換；SQLite migration matrix 已完成。
- 本輪未啟動或停止 Docker、AVD 或其他長時間程序；既有 runtime 狀態未重新檢查。
- 下一步：在沒有 Firebase credentials 時進行 V1-02 安全與隱私稽核；取得 credentials 後優先完成 S8-01～S8-05 真實推播。

### 2026-07-13 V1-04 Mailbox Restart Integrity

- Git 狀態：branch `codex/mailbox-restart-integrity`，功能 commit `38d9631`，Draft PR [#5 Test mailbox integrity across restart](https://github.com/leezxt/p2p-chat/pull/5)。
- **已完成**：PR #4 `Add manual mailbox refresh` 已合併至 `main`，本機同步至 merge commit `6fc3e5e`。
- **已完成**：新增使用 production SQLite migration、`ChatSqfliteDao`、`SqliteReplayProtection`、`SqliteMailboxReceipts` 與 `MailboxSyncService` 的跨重啟整合測試。
- **已完成**：模擬首次 DELIVERED ACK 遺失後關閉 DB，再以新 service instance 重開同一 DB；server 重投後 conversation、message、replay record、receipt 均維持一筆，且 ACK 成功補送。
- **已完成**：`mailbox_restart_integrity_test.dart` 通過；非 Windows-native Flutter suite 74 tests 全通過，`flutter analyze` 零問題，format 通過。
- **已實作未驗證**：V1-04 的 Android/iOS 真機 kill process、實際斷網切換與舊版 DB migration upgrade matrix 尚未執行。
- 本輪未啟動或停止 Docker、AVD 或其他長時間程序；既有 runtime 狀態未重新檢查。
- 下一步：建立舊 schema fixture，逐版驗證 v1→v6 migration 後 identity、conversation、message、replay、queue 與 receipt 資料仍完整。

### 2026-07-12 Sprint 8 Manual Mailbox Refresh

- Git 狀態：branch `codex/manual-mailbox-refresh`，功能 commit `f2acdd4`，Draft PR [#4 Add manual mailbox refresh](https://github.com/leezxt/p2p-chat/pull/4)。
- **已完成**：PR #3 `Add push launch mailbox coordinator` 已合併至 `main`，本機同步至 merge commit `eaca2ec`。
- **已完成**：聊天列表 AppBar 新增「同步訊息」控制；沒有 push provider 或通知權限時，使用者仍可手動執行 contact sync、mailbox pull 與 sender status sync。
- **已完成**：同步期間按鈕停用並顯示固定尺寸進度，避免重複網路請求；成功顯示「訊息已同步」，失敗顯示「無法同步訊息，本機聊天仍可使用」。
- **已完成**：3 個 widget tests 驗證初始離線後重試、失敗時本機功能保留、連續點擊防重入；非 Windows-native Flutter suite 73 tests 全通過，`flutter analyze` 零問題，format 通過。
- **已實作未驗證**：Android/iOS 系統通知權限拒絕的實機操作、背景推播 cold/warm launch 與耗電量測；仍需 Firebase/APNs credentials 與真機。
- 本輪未啟動或停止 Docker、AVD 或其他長時間程序；既有 runtime 狀態未重新檢查。
- 下一步：取得 Firebase credentials 時接真實 adapter；credentials 尚不可用時，可轉做 V1-04 的 App 重啟、重複同步與資料完整性測試腳本。

### 2026-07-12 Sprint 8 Notification Launch Coordinator

- Git 狀態：branch `codex/push-launch-coordinator`，功能 commit `2c30f58`，Draft PR [#3 Add push launch mailbox coordinator](https://github.com/leezxt/p2p-chat/pull/3)。
- **已完成**：PR #2 `Record Mac iOS verification results` 已轉 Ready、合併至 `main`，本機同步至 merge commit `08d74dc`。
- **已完成**：新增只接受 `schemaVersion=1`、`type=MAILBOX_AVAILABLE` 且拒絕額外 metadata 的 notification payload parser。
- **已完成**：新增 provider-neutral cold/warm `NotificationLaunchSource` 與序列化 coordinator；以 provider launch ID 冪等去重，失敗同步不會被誤標已處理，可用相同 ID 重試。
- **已完成**：抽出共用 `MailboxRefreshService`，通知開啟與聊天列表手動同步都依序執行 contact sync、mailbox pull、sender status sync；通知完成後回到聊天列表，由既有 incoming message 流程建立新 conversation。
- **已完成**：新增 4 項 parser/coordinator tests；排除需要 Windows native libsodium 的 `device_key_service_test.dart` 後，其餘 Flutter suite 70 tests 全通過，`flutter analyze` 零問題，format check 通過。
- **已實作未驗證**：真實 FCM/APNs adapter、Android notification permission、系統通知點擊 cold/warm start 與實機導向；目前 production 使用 no-op launch source，不建立假 token 或 provider。
- **未完成**：取得 Firebase credentials 後接上 `firebase_core`/`firebase_messaging` 與 backend FCM outbox worker，再做 Android 實機通知與 token invalidation 驗收。
- 已知環境限制：Windows 完整 `flutter test` 的 `device_key_service_test.dart` 因未安裝 Visual Studio Desktop development with C++，無法建立 sodium native asset；Mac 既有完整 71-test baseline 已通過。
- 本輪未啟動或停止 Docker、AVD 或其他長時間程序；既有 runtime 狀態未重新檢查。

### 2026-07-12 Mac iOS 同步結果

- **已完成**：Mac branch `agent/add-tests-and-ios-setup` 經 PR #1 合併至 `main`，merge commit `d5710ad`；Windows 已 fast-forward 同步。
- **已完成**：CocoaPods workspace、`Podfile.lock`、Runner/RunnerTests Pods xcconfig、automatic signing 與 Development Team `6S3F74Y3QN` 已提交。
- **已完成**：Mac `flutter analyze` 零問題、完整 `flutter test` 71 tests、`mvn test` 與 `git diff --check` 通過；Windows 回歸 `mvn test` 19 tests、`flutter pub get`、`flutter analyze` 通過。
- **已實作未驗證**：Intel Mac 的 Xcode 16.4 可辨識並配對 iPhone，但目標 iPhone 為 iOS 26.5.2，需要 Xcode 26.x；目前硬體/工具鏈無法完成 `flutter build ios`、簽章安裝與 native integration test。
- **未完成**：iPhone Keychain 跨重啟、真實 libsodium failure paths、WebRTC encrypted DataChannel、背景 sleep，以及 iPhone+Android E2E。
- 下一步：使用可安裝 Xcode 26.x 的 Mac，或將 iPhone 降至 Xcode 16.4 支援版本，再設定 `IOS_DEVICE_ID` 執行 `bash tool/verify_ios.sh`。

### 2026-07-12 Private GitHub 同步

- **已完成**：`p2p-chat` 已初始化為獨立 Git repository，branch `main`；初始 commit `87f5798`。
- **已完成**：GitHub CLI 已登入 `leezxt`，具 `repo` 權限；目標 repo 名稱尚未存在。
- **已完成**：敏感檔案掃描未發現私鑰、Firebase 設定或未忽略 `.env`；`google-services.json`、`GoogleService-Info.plist`、keystore 均在 ignore 規則內。
- **已完成**：`dist/`、APK、`.tools/`、build、Pods、Gradle cache 與本機設定不納入版本庫；Android Gradle wrapper 腳本與 jar 改為納入，確保 Mac 可重現建置。
- **已完成**：private GitHub repo `https://github.com/leezxt/p2p-chat` 已建立，`origin/main` 推送成功並設定 tracking。
- Mac clone：`git clone https://github.com/leezxt/p2p-chat.git`，之後進入 `p2p-chat/mobile_desktop_app` 執行 `bash tool/verify_ios.sh`。
- 下一步：Mac 登入具 repo 權限的 GitHub 帳號、clone 專案，安裝 Xcode/Flutter/CocoaPods，從 iOS no-codesign build 開始驗收。

### 2026-07-12 Sprint 8 Push 基礎進行中

- **已完成**：provider-neutral push token 註冊／更新／撤銷 API 與 Flutter service；JWT 使用者只能操作自己的未撤銷裝置，token 不回傳、不寫 log，SHA-256 hash 用於唯一性。
- **已完成**：Flyway V6 `device_push_tokens`、`notification_outbox`；mailbox 新建時冪等產生固定 `MAILBOX_AVAILABLE` payload，不含 plaintext、ciphertext、sender 或 conversation。
- **已完成**：Java tests、Flutter push/presence/module 10 tests 與 `flutter analyze` 通過；Docker V1～V6 migration、18080 readiness、雙 AVD 新 APK 啟動通過。
- **已實作未驗證**：真實 Firebase token 取得、FCM worker 發送、Android notification permission/cold start；缺少 Firebase credentials。
- 本次為驗證 outbox 將在本段記錄後暫停 `emulator-5554` App，讓 `emulator-5556` 走 mailbox fallback；完成後重新啟動 A App。
- **已完成**：真實雙 AVD outbox 驗收；A 暫停時 B 傳送 `PushOutboxTest`，mailbox 為 `STORED`，outbox 只有固定 `MAILBOX_AVAILABLE` payload；A 恢復後訊息為 `DELIVERED`。
- **已完成**：backend 改以 18080 避開外部 MyBatis 的 8080；`alpha-up.ps1` 預設 18080 且可用 `-BackendPort` 覆寫。Docker V1～V6 readiness `UP`。
- **已完成**：Java 16 tests、Flutter push/presence/module 10 tests、`flutter analyze`、Android x86_64 build 與雙 AVD 啟動通過。
- **已完成**：目前 APK v2 signature、1 signer，大小 197,455,626 bytes，SHA-256 `4C9B0117C7D1E299AEC3FD9CBB93A09273D30E597E493641792B49889924F8A0`，backend define 為 `10.0.2.2:18080`。
- 下一步：取得 Firebase Android project 設定後加入 `firebase_core`/`firebase_messaging` token provider 與 FCM outbox worker；再驗證權限拒絕、cold/warm start 與 token invalidation。

### 2026-07-12 Sprint 8 Presence 進行中

- **已完成**：Presence JWT/device ownership heartbeat、contact ACL lastSeen API、PostgreSQL Flyway V5 migration；Java tests 與 Docker V1～V5 migration 通過。
- **已完成**：Flutter 前景低頻 heartbeat、背景停止、resumed 恢復、網路等待期間 stop 競態防護與粗粒度在線狀態；Presence/lifecycle 7 tests 與 `flutter analyze` 通過。
- **已完成**：聊天列表顯示「在線／剛剛在線／離線」；兩台 AVD heartbeat 均寫入。B 背景 70 秒期間 timestamp 不變，A 前景於 60 秒更新；B resumed 後立即更新，兩端無 Flutter/FATAL error。
- **已實作未驗證**：Android presence alpha build；15:29 啟動的 Flutter/Gradle build 超過 5 分鐘無 CPU/產物進展，將於本段記錄後停止本次 PID 6048/26640/2792/21876/560，再以 Git Bash/GNU make PATH 重建。
- **已完成**：上述卡住 build 子程序已停止；改用 emulator-only `--target-platform android-x64` 後 76.6 秒建置通過。
- **已實作未驗證**：完整 Flutter suite 單次傳入 20 個檔案時，CLI PID 9688/27332 在建立 `flutter_tester` 前超過 4 分鐘無進展；將於本段記錄後停止，改以三組 tests 驗證。專項 Presence/lifecycle tests 已通過。
- **已實作未驗證**：分組重跑時第一組完成、第二組 CLI PID 8736/25724 再次在建立 runner 前無進展；將於本段記錄後停止。不可宣稱本次完整 Flutter suite 通過；沿用先前 60-test baseline，本次變更另有 Presence/lifecycle 7 tests、contact/mailbox 3 tests、analyze 與雙 AVD runtime 通過。
- Docker Flyway V5 `add device presence` 與 runtime 驗收時 PostgreSQL/backend 均 healthy；兩台 AVD 保留 online。
- **已完成**：Presence 階段 Android Emulator x86_64 alpha build 已由後續 Push alpha 取代；目前 APK/hash 見下方 Android Alpha 測試版。
- **已完成**：S8-04 Android 驗收；Java 15 tests、Presence/lifecycle 7 tests、contact/mailbox 3 tests、`flutter analyze` 通過。
- **已實作未驗證**：本次完整 Flutter suite 因 Windows Flutter CLI 在 runner 建立前卡住未重跑；先前 60-test baseline 保持，新增/受影響專項均通過。
- 下一步：S8-01～03 FCM 推播，需要 Firebase project、`google-services.json` 與 server credentials；未提供前可先做 provider-neutral push token/backend schema。
- 本輪結束時 runtime：PostgreSQL container 仍 healthy，P2P backend container 曾以 exit 143 停止；重新啟動時發現 8080 已被使用者的 `target/mybatis-0.0.1-SNAPSHOT.jar`（PID 14840）占用，因此未停止該外部程序、也未強制搶占 port。待 8080 空出後執行 `java_backend/scripts/alpha-up.ps1` 即可恢復。AVD `emulator-5554`、`emulator-5556` 仍 online。

### 2026-07-12 Android Alpha 測試版

- **已完成**：未知 conversation 收件時自動建立 1:1 對話；重複 mailbox 投遞不重複保存。
- **已完成**：邀請輸入 dialog 自行管理 controller 生命週期，修正兌換成功後 Flutter `_dependents.isEmpty` 紅屏。
- **已完成**：新增受 JWT 與 contact ACL 限制的聯絡人公鑰同步；App 在 mailbox pull 前驗 fingerprint、套用既有 TOFU/key-change 阻擋並保存聯絡人。
- **已完成**：兩台 Android 15 AVD 完成 `New User` 邀請、B 傳送 `AlphaMailboxTest`、backend `STORED → DELIVERED → READ`、A 自動建立對話、B 顯示「已讀」。兩端 logcat 無 Flutter/FATAL error。
- **已完成**：非 Windows-native Flutter suite 60 tests 全通過，`flutter analyze` 零問題；Java backend 14 tests 全通過；Docker PostgreSQL/backend readiness healthy。
- **已完成**：目前 Android x86_64 alpha APK v2 signature、1 signer，大小 197,455,626 bytes，SHA-256 `4C9B0117C7D1E299AEC3FD9CBB93A09273D30E597E493641792B49889924F8A0`。
- APK：`dist/android-alpha/p2p-messenger-android-alpha-debug.apk`；compile-time backend 為 `http://10.0.2.2:18080`，僅限本機 Android Emulator 測試。
- **已實作未驗證**：iOS runner/entitlements；依使用者指示暫停，待 macOS + Xcode + iPhone 驗收。
- **未完成**：FCM/APNs 需要外部 credentials；兩台 Android 真機、背景推播、耗電/記憶體與 V1 release candidate 驗收。
- 目前執行中：Docker PostgreSQL/backend 在 18080 healthy；AVD `emulator-5554`、`emulator-5556` online。外部 MyBatis App 繼續使用 8080，未被修改。停止 backend 使用 `java_backend/scripts/alpha-down.ps1`，AVD 可用 `adb -s <device> emu kill`。
- 下一步：由使用者實際操作 Android alpha；之後優先進行 Sprint 8 FCM（需 Firebase credentials），或在 Mac 可用時恢復 iOS 驗收。

- 歷史續接點：2026-07-12 早期以完成 Sprint 7 Offline Mailbox 與 ACK 為目標；目前已由上方 Android Alpha 狀態取代。
- **已完成**：Android S6-04；真實 libsodium、secure storage、WebRTC encrypted DataChannel 與雙 AVD authenticated E2E 已通過。
- **已實作未驗證**：S6-02 裝置金鑰服務；Android native runtime/secure storage 已通過，Windows native tests 與 iOS secure storage 實機行為待驗。
- **已實作未驗證**：iPhone/iOS runner、iOS 13 target、Bundle ID、Keychain entitlements 與權限用途說明；尚未經 macOS/Xcode build。
- **未完成**：iPhone Keychain、libsodium、WebRTC runtime 與 iPhone/Android 跨平台雙裝置驗收。
- **已完成**：S6-05 key fingerprint 本機驗證、變更偵測、阻斷傳送與明確重新信任流程；專項與相關回歸 9 tests 通過。
- **已完成**：S6-06 crypto 測試補齊與敏感資訊日誌稽核；22 個相關 tests 與 analyze 通過，Android 真實 libsodium runtime 沿用先前實機驗證。
- **已完成**：S7-01 mailbox API、ACL、quota、TTL 與 ACK 狀態機契約；13 項 schema/回歸 tests 通過。
- **已完成**：S7-02 Java backend Flyway V4、mailbox upload/pull/cursor/ACK/sender status、ACL、quota、rate limit、TTL cleanup 與 ciphertext 清除。
- `mvn test -q`：最終 S7-02 程式 14 tests、0 failures、0 errors；新增 HTTP 整合測試驗證 upload、冪等重送、recipient-only pull、DELIVERED ACK、密文清除與 sender status。
- Docker Compose `p2p_mailbox_verify`：PostgreSQL/backend containers healthy，Flyway v1～v4 全部 `success=true`，`mailbox_messages` 15 欄 schema 正確；驗證後 containers、network、volume 已移除。
- 當時 Rate limit 是單一 Spring instance 的 per-device fixed-window prototype；已於 2026-07-13 改為 Flyway V8/PostgreSQL 共用 atomic counter，解除多 instance 配額分裂風險。
- **已完成**：S7-03 Flutter SQLite schema v5 `mailbox_pending_queue`、冪等 enqueue、lease claim/recovery、成功刪除、最多 8 次 exponential backoff + jitter。
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test test/modules/pending_mailbox_queue_test.dart test/modules/identity_schema_test.dart`：2 tests、All tests passed；跨 service instance、lease expiry、retry delay、success delete 與 schema v5 通過。
- `flutter analyze`：S7-03 修改後通過，No issues found。
- 歷史紀錄：S7-04 後續已完成並納入 Android alpha 驗收。
- **已完成**：S7-04 `MessageTransportCoordinator`、production `HttpMailboxUploader`/`MailboxModule`、1:1 peer device 解析與 ChatController 傳送整合。同一密文先走 P2P；fallback enqueue 後狀態 `PENDING`，mailbox 成功清 queue 並更新 `STORED`，失敗保留 queue/retry。
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test test/modules/message_transport_coordinator_test.dart test/modules/pending_mailbox_queue_test.dart test/modules/p2p_session_lifecycle_test.dart test/modules/contact_service_test.dart`：11 tests、All tests passed。
- `flutter analyze`：S7-04 最終修改後通過，No issues found。
- 歷史紀錄：S7-05 後續已完成並通過 DELIVERED/READ 雙 AVD 驗收。
- **已完成**：S7-05 Flutter schema v6 receipt mapping、mailbox pull、認證/本機保存後 DELIVERED、聊天室 READ ACK、sender status 同步與 Chat 頁同步觸發。
- **已完成**：S7-06 離線與故障測試；ACK 首次遺失後重拉會重送 ACK，replay 不重複保存。
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test` Sprint 7 故障驗收組：17 tests、All tests passed；`flutter analyze` 零問題。
- 歷史紀錄：Android alpha 邀請碼、聯絡人、1:1 chat、Docker 與 APK build 已完成；最終結果見上方 Android Alpha 測試版。
- 建議驗證：具 Visual C++ workload 後執行 `flutter test test/modules/device_key_service_test.dart` 與完整 `flutter test`；Android 端需驗證 secure storage 跨重啟及兩裝置 DataChannel。
- Android E2E Spring backend（port 8081）與 AVD `emulator-5554`／`emulator-5556` 已於交接更新後乾淨停止；`adb devices` 無殘留裝置。Gradle/Kotlin daemon 由建置工具管理。
