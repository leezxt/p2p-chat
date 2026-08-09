# 測試指南

本文件是 repository 的測試入口。各子專案 README 保留平台細節；日常變更應先跑與變更範圍相符的快速驗證，合併前再完成可用環境支援的完整驗證。

Pull request 與 `main` push 會執行 `.github/workflows/v1-ci.yml`：Java 21 完整 tests、
Flutter 3.44.6 的 locked dependency/format/analyze/unit/widget tests、Windows Desktop
debug build，以及 isolated PostgreSQL container smoke。CI 不取代 production topology、
Android/iOS integration test 或真機 Gate。

## 測試矩陣

| 範圍 | 快速驗證 | 完整驗證 | 主要覆蓋 |
|---|---|---|---|
| Java backend | `mvn test` | `scripts/smoke.ps1` | REST/WebSocket、JWT、ACL、mailbox、presence、push、PostgreSQL migration |
| Flutter/Dart | `dart analyze`、相關 `flutter test <file>` | `flutter test` | Core lifecycle、SQLite、localization、crypto schema、P2P、mailbox、presence、push |
| Windows Desktop | `flutter test --no-pub test/modules/device_key_service_test.dart` | `tool/verify_windows_desktop.ps1 -Build -Runtime`；CI 再加跑 Desktop Companion、module-route 與 App-entry runtime integrations | libsodium native runtime、Credential Manager、crypto failure paths、WebRTC DataChannel、Desktop Companion QR／challenge flow、ModuleRegistry／RouteRegistry／Navigator route selection、正式 bootstrap／P2pChatApp／聊天室工具選單 App-entry、Runner 與 plugins 編譯 |
| Android native | 相關 Dart 單元測試 | crypto／App Lock runtime tests、雙 AVD E2E | libsodium、secure storage、Argon2id、App lifecycle、WebRTC DataChannel、完整訊息流程 |
| Android cloud device | `bash tool/build_firebase_test_lab.sh` | `Firebase Test Lab Android` 手動 workflow | instrumentation APK、遠端實體機 secure storage、libsodium、replay、WebRTC |
| iOS native | `bash tool/verify_ios.sh` | 設定 `IOS_DEVICE_ID` 後執行同一腳本 | build、Keychain、libsodium、WebRTC |
| Backend + App | `scripts/app-integration.ps1` | Android 雙裝置流程 | 真實 HTTP、JWT、邀請碼與裝置註冊 |

## 必要工具

- Java backend：Java 21、Maven 3.6.3 以上。
- Flutter app：Flutter 3.44.0 以上、Dart 3.12.0 以上；CI 鎖定 Flutter 3.44.6／Dart 3.12.2。
- PostgreSQL smoke test：Docker 與 Docker Compose。
- Android native：Android SDK 36、Build Tools 36.0.0、NDK 28.2.13676358。
- Windows Desktop：Visual Studio 2022 Desktop development with C++、CMake tools、Windows SDK。
- iOS native：macOS、Xcode、CocoaPods；實機驗證另需 signing 設定。

先確認工具版本，避免把「工具不存在」誤判成程式測試失敗：

```bash
java -version
mvn -version
flutter --version
dart --version
```

## Java backend

一般開發與 API/domain 回歸測試：

```bash
cd java_backend
mvn test
```

測試使用 `src/test/resources/application-test.yml` 與 H2，不需要先啟動 PostgreSQL。涉及
migration、容器設定或 production profile 的變更，還必須在 PowerShell 執行 isolated
container smoke。腳本使用隨機 process-only credentials、獨立 Compose project 與可用
host ports，完成後移除 test volumes 並恢復原環境：

```powershell
cd java_backend
.\scripts\smoke.ps1
```

成功條件包含 readiness `UP`、backend user `app`、Flyway 1～9 與 10 個 public tables。
失敗時先輸出最後 200 行 logs，再清除本輪 containers/networks/volumes。

Backend 候選版 JAR、Docker image 與 checksum manifest：

```powershell
cd java_backend
.\scripts\build-candidate.ps1
```

腳本預設要求乾淨 Git working tree 並執行完整 Maven tests；內部開發驗證才可使用
`-AllowDirtyWorkingTree`。輸出 JSON 會將 local image ID/RepoDigests 與尚待驗證的 registry
digest 分開，且不得包含資料庫密碼、JWT secret、push encryption key 或 Firebase
credential。

Production Compose/TLS preflight：

```powershell
cd java_backend
.\scripts\preflight-production.ps1 -EnvFile .\production.env
docker compose --env-file .\production.env -f .\compose.production.yml config --quiet
```

Preflight 拒絕 placeholder、短密碼、無效 base64 key、HTTP/wildcard WebSocket origin、
未 pin registry digest 的 image、公開 backend/PostgreSQL port、非 internal data network、
非 `prod` profile 與無效 log rotation。本機 `-AllowLocalVerification` 僅供隔離測試，不是
production 通過。
WSS probe 回 `101` 只代表 TLS proxy 成功升級 transport；signaling client 仍必須在第一個
frame 送 `AUTH`，backend 才以 JWT subject 與 device ownership 建立已認證 session。

Production topology 啟動後的 one-shot monitor：

```powershell
.\scripts\monitor-production.ps1 -EnvFile .\production.env
```

`PASS`/exit 0 表示 HTTP 轉 HTTPS、readiness `UP`、HSTS/`nosniff`/無 `Server` header 與
WSS 101 均通過；`FAIL`/非零 exit code 可直接供排程器或外部監控觸發告警。正式驗收
必須從 deployment host 外部執行，且不得使用 `-AllowLocalVerification`。

不需要 production endpoint 的 scheduled runner／webhook transition fixture：

```powershell
.\scripts\test-production-monitor-alerting.ps1
```

Fixture 使用 loopback receiver 驗證 failure／recovery POST、Bearer header、payload 去敏、
相同狀態抑制、HTTP 500 後 state 不前進與下次重試、正式模式 HTTPS 限制，以及同一 state
file 的重疊執行互斥。此測試會在 V1 CI Ubuntu runner 執行；正式 scheduler 與 alert
receiver 仍需在 deployment environment 驗收。

PostgreSQL backup/restore drill：

```powershell
cd java_backend
.\scripts\backup-production.ps1 -EnvFile .\production.env
.\scripts\restore-production.ps1 `
  -BackupPath .\target\production-backups\<backup>.dump `
  -TargetDatabase p2p_chat_restore_verify `
  -EnvFile .\production.env `
  -CreateTargetDatabase
```

Backup 需通過 `pg_restore --list`、SHA-256 與 manifest 敏感欄位檢查。Restore drill 必須
使用獨立 DB，並比對 Flyway versions、public table count 與已知 probe data；不得只因
`pg_restore` exit 0 就宣稱備份可用。任何既有 DB replacement 都需要精確確認字串。

不需要 Docker 的 backup retention safety fixtures：

```powershell
.\scripts\test-backup-offhost-export.ps1
.\scripts\test-backup-retention.ps1
```

Off-host export fixture 驗證 dump／manifest 重新計算 hash、schema 2 原子 receipt、重跑冪等、
retention 相容、匯出後 manifest binding、來源竄改、目的地衝突與 credential-like
reference 拒絕。Retention fixture 驗證 dry-run、精確 Apply confirmation、最少保留數、
receipt/hash、corrupt/orphan protection、刪除範圍與重跑冪等；兩項測試都會在 V1 CI 執行。

只需要驗證 Flutter client 與 Spring backend 契約、且不使用 Docker 時：

```powershell
cd java_backend
.\scripts\app-integration.ps1
```

## Flutter/Dart

先執行格式與靜態分析，再跑測試：

```bash
cd mobile_desktop_app
flutter pub get
dart format --output=none --set-exit-if-changed lib test
dart analyze
flutter test
```

開發中的快速回饋可只跑受影響檔案，例如：

```bash
flutter test test/modules/pending_mailbox_queue_test.dart
flutter test test/modules/p2p_session_lifecycle_test.dart
flutter test test/core/app_lifecycle_coordinator_test.dart
```

Desktop Link／Device Sync／Revoke 的主機安全核心、手機端一次性 QR 請求檢閱、公開金鑰
binding 與私鑰持有 challenge-response gate 可用下列命令驗證：

```powershell
$env:NIX_SKIP_SODIUM_BUILD_HOOKS='1'
flutter test --concurrency=1 test/modules/desktop_link_service_test.dart `
  test/modules/desktop_link_pairing_request_test.dart `
  test/modules/desktop_link_pairing_request_issuer_test.dart `
  test/modules/desktop_link_key_possession_test.dart `
  test/modules/desktop_link_companion_service_test.dart `
  test/modules/desktop_link_companion_page_test.dart `
  test/modules/desktop_link_pairing_service_test.dart `
  test/modules/desktop_link_pairing_page_test.dart `
  test/modules/desktop_link_module_test.dart `
  test/modules/database_migration_matrix_test.dart `
  test/modules/identity_schema_test.dart
dart analyze
```

這組目前共 38 項測試，驗證 v1→v15 SQLite 升級（含安全作廢沒有公開金鑰 binding 的
v14 暫存 request）、手機明確授權、嚴格新訊息切點與撤銷 fail-closed，以及 QR payload
的嚴格版本／欄位／效期驗證、32-byte X25519 公開金鑰與重算 fingerprint binding、canonical
request issuer、一次性 request state，以及用短效 RAM token 建立的雙向 authenticated
challenge-response。後者涵蓋正常 proof、竄改 response、錯誤桌面 key、重放、過期與變更
公開金鑰後不能沿用 proof，也確認沒有有效 proof 時 `confirm` 會 fail-closed。

V3-05 另驗證 desktop companion 以本機公開金鑰建立短效 request、只為本機 desktop key 回覆
手機 challenge，並以 Widget test 檢查「輸入手機 device ID → QR 顯示 → 貼入 challenge → 輸出
encrypted response」的手動交付流程。它不啟動 Windows runner 或任何網路 transport。

`NIX_SKIP_SODIUM_BUILD_HOOKS=1` 會略過這台 Windows 主機缺少 C++ native toolchain 的 sodium
build hook；私鑰持有 protocol 測試因此注入 test-only `MessageBox` fake，僅驗證協定狀態與
binding，不是原生 libsodium／secure storage 的 runtime 驗收。這組也不包含真實相機掃碼、
原生 desktop runner 的 QR／clipboard runtime、目標主裝置自動交付、真實傳輸、per-device 加密，
或已撤銷副端的 runtime 金鑰銷毀驗收。

Localization 變更需重新產生程式碼，並驗證語言解析、SQLite 偏好保存與兩種語言 UI：

```bash
flutter gen-l10n
flutter test test/core/locale_controller_test.dart \
  test/modules/locale_preference_store_test.dart \
  test/modules/localization_ui_test.dart
```

Windows 若未安裝 Visual Studio Desktop development with C++，完整 `flutter test` 會因
無法建立 sodium native asset 而停在 `device_key_service_test.dart`。可先執行其他 host
tests，但必須保留該 native Gate 為未驗證，不能以 `NIX_SKIP_SODIUM_BUILD_HOOKS=1`
取代 Android/iOS runtime 驗收。

Windows Desktop native Gate 的單一入口是：

```powershell
cd mobile_desktop_app
.\tool\verify_windows_desktop.ps1
.\tool\verify_windows_desktop.ps1 -Build -Runtime
```

第一個命令只做 Flutter `doctor`／Windows device preflight；第二個命令執行 locked `pub get`、
debug build、三個獨立 App process 的 secure-storage `write`／`verify`／`full` phases，接著以
真實 `SodiumMessageBox` 驗證 Desktop Companion QR rendering、手動 challenge-response 與同一
runner 內的主裝置角色 proof，再以實際 `ModuleRegistry`、SQLite FFI、`RouteRegistry` 與
`Navigator` test shell 驗證 Windows target 的 `/desktop-link` 會選擇 Companion。最後以無後端設定
執行正式 `bootstrap`、掛載 `P2pChatApp`，並在正式聊天室「應用工具」選單點選 Desktop Link。
若要在本機額外測 copy，需明確加上 `-VerifyClipboard`，因為它會寫入並清除測試 clipboard。CI 在
GitHub-hosted Windows runner 會加上這個旗標。腳本會拒絕設定 `NIX_SKIP_SODIUM_BUILD_HOOKS` 的
native run，避免 fake crypto 成為 runtime evidence。

這些測試證明 Windows runner 可載入相關 plugin，並驗證 desktop pairing flow、受限模組路由與 App
入口；[PR #54 V1 CI run 31319510492](https://github.com/leezxt/p2p-chat/actions/runs/31319510492) 已在
`331f88d` 對應版本通過 Companion、module-route 與 App-entry integrations。App-entry test 確實啟動
無後端設定的 `bootstrap`／`P2pChatApp`／聊天室首頁並操作工具選單，但仍不啟動真實手機相機、不建立
Desktop transport、per-device re-encryption、跨裝置訊息同步或撤銷後資料不可解密的端對端情境。

Windows CI 會額外以兩個獨立 App process 執行 secure storage phase。`write` phase 清除
專用測試 key、建立裝置金鑰並保存非秘密 fingerprint marker；`verify` phase 由新的 App
process 重載同一金鑰、比對 fingerprint，並在 `finally` 清除兩筆 Credential Manager
測試資料。此 Gate 驗證 process restart persistence，不等於 Windows OS reboot 或企業
Credential Guard／帳號政策驗收。

完成變更時仍應回到完整 `flutter test`，避免跨模組生命週期或 Event Bus 回歸。

## Native 與端對端測試

Android crypto runtime：

```bash
cd mobile_desktop_app
flutter test integration_test/android_crypto_runtime_test.dart -d <android-device-id>
```

Android App Lock production runtime（PowerShell）：

```powershell
cd mobile_desktop_app
.\tool\verify_android_app_lock.ps1 -Device <android-device-id>
```

乾淨且具 fingerprint HAL、尚未註冊指紋的 AVD 可追加
`-ExpectUnenrolledBiometrics`，驗證 production `local_auth` adapter 回傳 `notEnrolled` 且不解鎖。
已設定鎖屏並以 finger ID `1` 完成 enrollment 的受控 AVD，可驗證系統 biometric
成功與取消路徑：

```powershell
.\tool\verify_android_app_lock.ps1 `
  -Device emulator-5554 `
  -BiometricExpectation success
.\tool\verify_android_app_lock.ps1 `
  -Device emulator-5554 `
  -BiometricExpectation cancel
```

Runner 只允許 emulator 使用自動 biometric assertion；成功路徑會在 production
`local_auth` 對話框出現後送入 finger ID `1`，取消路徑送出 Android 返回鍵。每次執行也會
驗證真實 SodiumSumo Argon2id、Android encrypted storage 與 lifecycle coordinator。
AVD 結果不取代真機 enrollment change、真實感測器差異、跨 OS restart 與系統政策驗收。

沒有本機手機時，可先建立 Firebase Test Lab app/test APK：

```bash
cd mobile_desktop_app
bash tool/build_firebase_test_lab.sh
```

GitHub 手動 workflow 的付費 submission 只接受 `main`；免費 dry-run 可從 WIF 明確授權的
分支執行。Workflow 使用 OIDC 而非 service-account JSON key，且會拒絕非實體 Test Lab
model。預設 `submit_test=false` 只驗證 APK、OIDC、catalog 與 results bucket，不建立付費
matrix；確認費用後才可改為 `true`。付費 submission 預設拒絕低容量裝置，採非同步建立並
保存 matrix ID；排隊／監控逾時或 runner 中止時會取消未完成 matrix。
設定、IAM、裝置選擇與 artifact 證據見
[`firebase_test_lab.md`](firebase_test_lab.md)。首次真正送測前維持「已實作未驗證」；單一
雲端實體機也不取代雙裝置 E2E、真實斷網、OS kill、行動網路與耗電量測。

Android 雙裝置 encrypted P2P（PowerShell）：

```powershell
cd mobile_desktop_app
.\tool\verify_android_v1.ps1 `
  -SenderDevice <android-device-id-a> `
  -ReceiverDevice <android-device-id-b>
```

Runner 會使用乾淨 H2 backend 與 Flyway migration，自動建立雙向 contact ACL；Emulator 使用 `10.0.2.2`，USB 真機使用暫時的 `adb reverse`。2026-07-14 已在 `emulator-5554` / `emulator-5556` 通過。真機與資源量測仍須另外驗收。

Android 雙裝置 offline mailbox 與 process restart（PowerShell）：

```powershell
cd mobile_desktop_app
.\tool\verify_android_mailbox_recovery.ps1 `
  -SenderDevice <android-device-id-a> `
  -ReceiverDevice <android-device-id-b>
```

此 runner 會上傳真實 sodium 密文，在接收端完成 SQLite message/replay/receipt 寫入後模擬 DELIVERED ACK 遺失，使用 `am force-stop` abrupt kill App，再重啟同一 DB 驗證重投冪等、DELIVERED/READ 與 sender 本機 READ 狀態。2026-07-14 已在兩台 Android 15 AVD 完整通過；AVD 不取代真機實際斷網、OS kill、USB `adb reverse` 與耗電/記憶體驗收。

Android V1 資源基線（PowerShell）：

```powershell
cd mobile_desktop_app
flutter build apk --profile --target-platform android-x64
.\tool\measure_android_resources.ps1 `
  -Device <android-device-id> `
  -ApkPath build\app\outputs\flutter-apk\app-profile.apk `
  -ClearAppData
```

Runner 以五次 process-cold launch 的中位數檢查 3 秒目標，以 `dumpsys meminfo` 檢查 150MB 閒置目標，並在 65 秒背景窗檢查 App UID 的 established TCP 與 netstats。結果寫入 `build/v1-android-resources/`；AVD 基線與真機待驗項目見 [`resource_measurement_v1.md`](resource_measurement_v1.md)。

Android 候選版 artifact 與 checksum manifest：

```powershell
cd mobile_desktop_app
.\tool\build_android_candidate.ps1 -Mode Profile -TargetPlatform android-arm64
.\tool\build_android_candidate.ps1 -Mode Release -ApplicationId <production-application-id>
```

Profile 產物只標示為 `INTERNAL_PROFILE`。Release 模式必須使用乾淨工作樹、正式
application ID 與被 Git 忽略的 `android/key.properties`，成功後才會標示為
`RELEASE_CANDIDATE`。輸出的 JSON manifest 不包含簽章密碼或私鑰資料。

iOS 驗證：

```bash
cd mobile_desktop_app
bash tool/verify_ios.sh
IOS_DEVICE_ID=<iphone-device-id> bash tool/verify_ios.sh
```

兩裝置 E2E 需要兩個獨立 App process 與各自 device ID；runner 會建立本次專用的 backend 狀態並於結束時清理。執行前仍須確認 port 8081 未被其他程式使用，且 emulator/實機沒有其他測試佔用；詳細現況與待驗項目見 [`handoff_checklist.md`](handoff_checklist.md)。

## 結果判讀

- 指令 exit code 非零即視為失敗；不可只依最後一行輸出判斷。
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1` 只能驗證純 Dart/schema/fake crypto 路徑，不代表真實 libsodium 通過。
- H2 測試通過不取代 PostgreSQL/Flyway smoke test。
- 單一裝置或 fake adapter 測試通過不取代雙裝置 WebRTC E2E。
- 測試被 skip、runner 未建立或 CLI 卡住時，必須記錄為「未驗證」，不可記為通過。

## 新增測試的原則

1. 優先測信任邊界、狀態轉移、冪等、重試與資源釋放，不只測 happy path。
2. 測試不得記錄 plaintext、token、private key、ciphertext 或完整 payload。
3. 時間、亂數與網路行為應可控制，避免依賴固定等待或外部服務。
4. 修正 bug 時先加入能重現問題的回歸測試。
5. 新增功能時，同步更新本文件、相關 API/安全文件與 [`handoff_checklist.md`](handoff_checklist.md)。
