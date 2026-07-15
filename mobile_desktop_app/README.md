# mobile_desktop_app

Flutter 手機主端與 Desktop 副端。

V1 候選版的完整驗收與發布阻塞統一記錄於
[`../docs/release_candidate_v1.md`](../docs/release_candidate_v1.md)。Android release
build 已禁止 fallback 至 debug signing，但正式 application ID 與 upload keystore 尚未
提供，因此目前只可建立內部測試產物，不可上架或公開散佈。

統一候選版產物腳本會建立 APK/AAB、SHA-256 與 JSON manifest：

```powershell
.\tool\build_android_candidate.ps1 -Mode Profile -TargetPlatform android-arm64
```

正式 AAB 用法與 fail-closed 條件見候選版驗收文件。

## Android 建置

需求：Android SDK 36、Build Tools 36.0.0、NDK 28.2.13676358、Java 17 以上。Windows host 另需 Git Bash 與 GNU make 4.x，供 `sodium` native build hook 交叉編譯 libsodium。Android runner 已建立，debug APK 可用下列指令建置：

```powershell
flutter build apk --debug
```

APK 產物位於 `build/app/outputs/flutter-apk/app-debug.apk`。目前已驗證 Android debug 編譯、真實 libsodium/secure storage、production WebRTC adapter，以及兩個 Android AVD/App process 的 authenticated encrypted E2E；真機資源量測仍待補。

本機 Android Emulator x86_64 alpha 位於 `../dist/android-alpha/p2p-messenger-android-alpha-debug.apk`。它固定連線 `10.0.2.2:18080`，需搭配 `java_backend/scripts/alpha-up.ps1`，不可用於公開發布、ARM 真機或外部網路環境。雙 AVD 已驗證邀請、聯絡人同步、encrypted mailbox fallback、DELIVERED/READ ACK、sender 已讀顯示、前景 Presence／背景停止 heartbeat，以及不含敏感資料的 notification outbox。

可用同一個 PowerShell runner 驗證兩台 Emulator 或兩台以 USB 連接的 Android 裝置：

```powershell
.\tool\verify_android_v1.ps1 `
  -SenderDevice emulator-5554 `
  -ReceiverDevice emulator-5556
```

Runner 會啟動乾淨的 test-profile H2 backend、等待兩端註冊、建立 contact ACL，然後執行 JWT signaling、offer/answer/ICE、真實 libsodium encrypted envelope 與 WebRTC DataChannel。實體裝置會自動設定並清除 `adb reverse`；需要 Git for Windows、GNU make 與兩個 `adb devices` 狀態為 `device` 的不同序號。Log 位於 `build/v1-android-e2e/`。

Offline mailbox、ACK 遺失與 App process restart 使用另一個 runner：

```powershell
.\tool\verify_android_mailbox_recovery.ps1 `
  -SenderDevice emulator-5554 `
  -ReceiverDevice emulator-5556
```

它會上傳真實 sodium 密文，在接收端寫入 SQLite 後模擬 DELIVERED ACK 遺失，執行 `am force-stop`，再重啟同一 DB 驗證重投冪等、DELIVERED/READ 與 sender 本機 READ 狀態。雙 AVD 已通過；兩個 runner 都不能取代真機實際斷網、OS kill、USB `adb reverse` 與資源量測。

V1 冷啟動、記憶體與背景連線基線可使用 profile APK 量測：

```powershell
flutter build apk --profile --target-platform android-x64
.\tool\measure_android_resources.ps1 `
  -Device emulator-5554 `
  -ApkPath build\app\outputs\flutter-apk\app-profile.apk `
  -ClearAppData
```

Runner 產生 JSON/Markdown 報告並依冷啟動中位數 3 秒、閒置 PSS 150MB、背景 established TCP 0 執行自動判定。兩次 Android 15 AVD 結果已通過自動門檻；最大單次啟動仍略高於 3 秒，且 Emulator 無法提供有效電量結果，因此 V1-03 仍需真機驗收。

## Push notification 啟動流程

App 已提供 provider-neutral 的 notification launch adapter 邊界。只接受
`{"schemaVersion":1,"type":"MAILBOX_AVAILABLE"}`，通知資料不得包含 sender、
conversation、message 或密文資訊。Cold/warm launch 會走同一個冪等 coordinator，
先同步聯絡人與 mailbox，再回到聊天列表。Production 目前使用 no-op source；待有
Firebase credentials 後再由 `firebase_messaging` adapter 提供真實 token、initial
message 與 opened-message stream。

若通知權限被拒絕、provider 尚未設定或背景通知未送達，聊天列表右上角的
「同步訊息」按鈕仍可手動執行相同 refresh。同步失敗不會阻止本機聊天室操作，
同步進行中也會防止重複請求。

## iPhone / iOS 建置

`ios/` runner 已建立，最低版本為 iOS 13，並已設定 Keychain entitlements、相機、麥克風與區網用途說明。實際建置必須使用 macOS、Xcode 與 CocoaPods：

```bash
flutter pub get
cd ios
pod install
cd ..
flutter build ios --debug --no-codesign
```

也可在 macOS 專案根目錄執行 `bash tool/verify_ios.sh`。設定 `IOS_DEVICE_ID` 時，腳本會額外執行 iPhone native crypto、Keychain 與 WebRTC integration test。

接著在 Xcode 設定唯一 Bundle ID、Development Team 與 signing profile，再以 iPhone 實機驗證 Keychain、libsodium 與 WebRTC。Windows Flutter 不提供 `build ios`。

2026-07-12 Mac 驗證已完成 CocoaPods workspace、Podfile.lock、Development Team 與 automatic signing；`flutter analyze` 與完整 71 tests 通過。現有 Intel Mac 的 Xcode 16.4 無法為 iOS 26.5.2 建置或安裝，實機驗收仍需 Xcode 26.x 相容環境。

```bash
flutter test integration_test/ios_crypto_runtime_test.dart \
  -d <iphone-device-id> \
  --dart-define=RUNTIME_PLATFORM=iOS
```

## 本機後端整合

開發環境以 compile-time define 注入端點與本機 bootstrap key；不要將 key 寫入程式碼或提交到版本庫。

```powershell
flutter run `
  --dart-define=BACKEND_URL=http://localhost:8080 `
  --dart-define=SIGNALING_URL=ws://localhost:8080/ws/signaling `
  --dart-define=LOCAL_DEV_AUTH_KEY=<local-development-key>
```

## 驗證

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
dart analyze
flutter test
flutter test test/modules/two_device_p2p_test.dart
```

## 多語言介面

V1 使用 Flutter gen-l10n/ARB 支援繁體中文與英文。預設跟隨系統，也可從聊天列表的
語言選單切換；偏好保存於 SQLite，App 重啟後仍有效。不支援的系統語言會 fallback
至繁體中文。修改 `lib/l10n/*.arb` 後執行：

```powershell
flutter gen-l10n
flutter test test/core/locale_controller_test.dart `
  test/modules/locale_preference_store_test.dart `
  test/modules/localization_ui_test.dart
```

`two_device_p2p_test.dart` 會建立兩個獨立裝置 session，走完 offer、answer 與文字 envelope 傳送。真實 Android WebRTC plugin 已以雙 AVD 補充驗證；兩台真機與 Desktop runner 仍待驗。

`device_key_service_test.dart` 會載入原生 libsodium；Windows 執行測試需要 Visual Studio 的 Desktop development with C++ workload。缺少該 workload 時仍可建置 Android，但不可把 Windows 測試標記為通過。

`mailbox_restart_integrity_test.dart` 會在首次 ACK 遺失後關閉並重開同一個
SQLite DB，驗證 server 重投不會重複建立 conversation/message/replay/receipt，
且 App 重啟後仍會補送 DELIVERED ACK。

`database_migration_matrix_test.dart` 會建立 v1～v5 舊版 SQLite fixtures，逐一
升級至目前 v7，驗證聊天、身份、聯絡人、replay、key trust、mailbox queue 與
語言偏好設定表的資料保留，以及 contact key trust backfill。

`p2p_session_lifecycle_test.dart` 驗證連線完成前禁止傳訊、offer 有限重試、timeout/error 釋放資源、close 與 sleep 後重新連線。

`logging_sensitive_data_test.dart` 驗證統一 logger 不輸出 bearer/JWT、token、secret/private key、plaintext、ciphertext 或 payload；Crypto 測試另驗證連續加密 nonce 不重用。

App 進入 hidden、paused 或 detached 時會強制將 P2P 模組切到 sleeping；回到 resumed 不會自動重建連線。

P2P DataChannel 現在只傳 `EncryptedEnvelope`。Production code 已移除明文測試後門，並在解密後比對 outer/inner message、device 與 key IDs；SQLite v4 會保存 replay record 與 remote key trust。App 會本機驗證 fingerprint，同裝置公鑰變更時阻斷傳送，直到明確重新信任。Android 真實 libsodium runtime 與兩個 AVD 的 encrypted E2E 已通過；iPhone 實機驗收仍待 macOS/Xcode 環境。

啟動 backend 後，可用真實 HTTP 連線驗證註冊、JWT、邀請碼與 QR payload：

```powershell
$env:BACKEND_URL='http://127.0.0.1:18080'
$env:LOCAL_DEV_AUTH_KEY='<local-development-key>'
dart run tool/backend_integration_check.dart
```
