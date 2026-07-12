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

iOS 驗證：

```bash
cd mobile_desktop_app
bash tool/verify_ios.sh
IOS_DEVICE_ID=<iphone-device-id> bash tool/verify_ios.sh
```

兩裝置 E2E 需要 backend、兩個獨立 App process 與各自 device ID。執行前先確認測試資料庫、連接埠與 emulator/實機沒有沿用上一次執行的狀態；詳細現況與待驗項目見 [`handoff_checklist.md`](handoff_checklist.md)。

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
