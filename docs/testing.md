# 測試指南

本文件是 repository 的測試入口。各子專案 README 保留平台細節；日常變更應先跑與變更範圍相符的快速驗證，合併前再完成可用環境支援的完整驗證。

## 測試矩陣

| 範圍 | 快速驗證 | 完整驗證 | 主要覆蓋 |
|---|---|---|---|
| Java backend | `mvn test` | `scripts/smoke.ps1` | REST/WebSocket、JWT、ACL、mailbox、presence、push、PostgreSQL migration |
| Flutter/Dart | `dart analyze`、相關 `flutter test <file>` | `flutter test` | Core lifecycle、SQLite、crypto schema、P2P、mailbox、presence、push |
| Android native | 相關 Dart 單元測試 | `integration_test/android_crypto_runtime_test.dart`、雙 AVD E2E | libsodium、secure storage、WebRTC DataChannel、完整訊息流程 |
| iOS native | `bash tool/verify_ios.sh` | 設定 `IOS_DEVICE_ID` 後執行同一腳本 | build、Keychain、libsodium、WebRTC |
| Backend + App | `scripts/app-integration.ps1` | Android 雙裝置流程 | 真實 HTTP、JWT、邀請碼與裝置註冊 |

## 必要工具

- Java backend：Java 21、Maven 3.6.3 以上。
- Flutter app：Flutter 3.27.0 以上、Dart 3.6.0 以上。
- PostgreSQL smoke test：Docker 與 Docker Compose。
- Android native：Android SDK 36、Build Tools 36.0.0、NDK 28.2.13676358。
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

測試使用 `src/test/resources/application-test.yml` 與 H2，不需要先啟動 PostgreSQL。涉及 migration、容器設定或 production profile 的變更，還必須在 PowerShell 執行：

```powershell
cd java_backend
.\scripts\smoke.ps1
```

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

完成變更時仍應回到完整 `flutter test`，避免跨模組生命週期或 Event Bus 回歸。

## Native 與端對端測試

Android crypto runtime：

```bash
cd mobile_desktop_app
flutter test integration_test/android_crypto_runtime_test.dart -d <android-device-id>
```

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
