# V1 Release Candidate 驗收

本文件是 V1 候選版的單一發布入口。它彙整建置、安裝、操作、驗收與已知限制；
詳細測試方法仍以 [`testing.md`](testing.md) 為準。所有硬性門檻通過前，產物只能標示
為開發測試版，不得對外宣稱 V1 release candidate 或正式版。

## 候選版資訊

| 項目 | 目前值 | 狀態 |
|---|---|---|
| App version | `0.1.0+1` | 開發版 |
| Android application ID | 預設 `com.p2pchat.p2p_chat_app` | release 必須注入正式唯一 ID |
| Android signing | release 不再 fallback 至 debug key | 正式 keystore 尚未提供 |
| Backend | Spring Boot + PostgreSQL | Docker smoke test 已通過 |
| Android 驗證 | Android 15 雙 AVD | 開發基線通過，雙真機待驗 |
| iOS 驗證 | runner、Pods 與 signing 設定已建立 | 目標 iPhone 需相容 Xcode 重驗 |
| Push | provider-neutral 流程與 FCM HTTP v1 worker | 真實 Firebase/APNs 待驗 |

## 已通過範圍

- 身份與裝置註冊、邀請碼、雙向聯絡人與 fingerprint 信任。
- 1 對 1 文字訊息的 authenticated signaling、WebRTC DataChannel 與
  `P2P_BOX_V1` libsodium 密文傳輸。
- P2P 失敗後 offline mailbox fallback、SQLite replay protection、
  `STORED -> DELIVERED -> READ`、ACK 遺失後冪等復原。
- App 進入背景後釋放 P2P，前景 Presence 最快每 60 秒更新。
- Flutter gen-l10n/ARB 繁體中文與英文介面；支援跟隨系統、App 內切換、SQLite
  跨重啟保存與 unsupported locale fallback 至 `zh_TW`。
- 安全與隱私自動化稽核；殘餘風險見 [`security_audit_v1.md`](security_audit_v1.md)。
- Android 15 AVD profile 資源基線；數值與限制見
  [`resource_measurement_v1.md`](resource_measurement_v1.md)。
- GitHub Actions V1 CI：Java 21 backend tests、Flutter 3.44.6 locked dependency/format/
  analyze/unit/widget tests、Windows libsodium/Credential Manager/WebRTC native integration、
  Credential Manager 跨獨立 App process 持久化與 Desktop debug build，以及 isolated
  PostgreSQL container smoke。

## 建置與安裝

### Android 開發候選版

在正式 application ID 與 release keystore 完成前，只建立 profile APK 供真機驗收：

```powershell
cd mobile_desktop_app
flutter pub get
dart analyze
flutter test
flutter build apk --profile
adb -s <android-device-id> install -r build\app\outputs\flutter-apk\app-profile.apk
```

正式 Android build 機器需將 `android/key.properties.example` 複製為被 Git 忽略的
`android/key.properties`，填入 upload keystore 路徑與密碼，並透過 Gradle property 或
環境變數提供正式 application ID：

```powershell
$env:P2P_APPLICATION_ID='com.example.p2pchat'
flutter build appbundle --release
```

缺少 `key.properties` 或仍使用預設 application ID 時，release task 會直接失敗，且不會
退回 debug signing。密碼與 keystore 不得提交至 repository、CI log 或 artifact。

候選版產物必須由統一腳本建立。沒有正式憑證時可產生明確標示為
`INTERNAL_PROFILE` 的 ARM64 APK：

```powershell
.\tool\build_android_candidate.ps1 -Mode Profile -TargetPlatform android-arm64
```

具備正式 ID 與被 Git 忽略的 `android/key.properties` 後，從乾淨工作樹建立 AAB：

```powershell
.\tool\build_android_candidate.ps1 `
  -Mode Release `
  -ApplicationId 'com.example.p2pchat'
```

腳本將 artifact 與 JSON manifest 寫入 `build/v1-release-candidate/`。Manifest 記錄
application ID、version、來源 commit、Flutter/Dart 版本、檔案大小與 SHA-256；不讀取
或輸出 keystore 密碼。Release 模式拒絕 dirty working tree、預設 application ID 與缺少
keystore 的環境。

Production backend 不得使用 H2、local development key 或 HTTP。正式環境必須提供
PostgreSQL、JWT secret、HTTPS/WSS endpoint 與精確 WebSocket origin allowlist。環境變數
與容器檢查方式見 [`../java_backend/README.md`](../java_backend/README.md)。

Production topology 已提供 `compose.production.yml`、Caddy TLS/WSS proxy、internal data
network 與 `preflight-production.ps1`。本機隔離驗證已通過 HTTPS readiness、HSTS、HTTP
308、WebSocket 101、Flyway 1～9、prod API docs 404 與 non-root backend；bounded Docker
logs 與 one-shot HTTPS/WSS monitor 亦已在 localhost 通過。公開 DNS/ACME、registry
digest、firewall、外部告警接收器與真實 HTTPS endpoint 仍是發布 Gate。
WebSocket 101 只驗證 transport upgrade；連線後仍須以第一個 `AUTH` frame 完成
JWT/device ownership 認證。

`backup-production.ps1` 與 `restore-production.ps1` 已在隔離 PostgreSQL 完成 custom dump、
SHA-256、完整性檢查、新 DB restore、既有 test DB replacement、Flyway 1～9、10 tables
與 probe data 比對。`prune-production-backups.ps1` 已以 Windows fixture 與 GitHub-hosted
Ubuntu runner 驗證本機 staging retention：預設 dry-run，只有具有效 off-host receipt、
通過 manifest/hash/custom-format 驗證、超過期限且不在最新保留數內的 backup 才能在
精確確認後刪除。正式環境仍需加密 off-host storage、外部 receipt 簽發、排程與定期演練。

Backend candidate 使用統一腳本執行 Maven tests、建立 executable JAR 與 Docker image，
並輸出 JAR SHA-256、local image ID/size、OCI revision/version labels 與本機
RepoDigests：

```powershell
cd java_backend
.\scripts\build-candidate.ps1
```

產物位於被 Git 忽略的 `target/v1-release-candidate/`。本機 Docker image ID 或
RepoDigests 不等於 registry 已接受的證明；正式推送 image 後仍必須從 registry 記錄部署
所用 digest，不能以 local 值冒充。

### iOS 開發候選版

```bash
cd mobile_desktop_app
flutter pub get
bash tool/verify_ios.sh
IOS_DEVICE_ID=<iphone-device-id> bash tool/verify_ios.sh
```

需使用支援目標 iPhone OS 的 Xcode，並設定唯一 Bundle ID、Development Team 與
distribution signing。現有 Xcode 16.4 不支援先前連接的 iOS 26.5.2，不能作為實機
驗收結果。

## 基本操作驗收

1. 兩台裝置各自完成註冊，確認重啟後 user/device ID 與 private key 不變。
2. A 建立邀請碼，B 兌換後確認雙方聯絡人與 fingerprint 一致。
3. A、B 各送一則文字訊息，確認 P2P 密文路徑與訊息只顯示一次。
4. 關閉收件端網路後送訊息，恢復網路並同步 mailbox，確認狀態到 READ。
5. 在 ACK 尚未完成時由 OS 終止 App，重啟後確認訊息、receipt 與狀態不重複。
6. 將 App 置於背景，確認沒有 WebRTC/P2P 長連線與 Presence heartbeat。
7. 拒絕通知權限或停用 push，確認手動同步仍可取得 mailbox 訊息。

## 自動化與真機驗收

先以 `adb devices` 取得兩個不同且狀態為 `device` 的序號，再依序執行：

```powershell
cd mobile_desktop_app
.\tool\verify_android_v1.ps1 `
  -SenderDevice <android-device-id-a> `
  -ReceiverDevice <android-device-id-b>
.\tool\verify_android_mailbox_recovery.ps1 `
  -SenderDevice <android-device-id-a> `
  -ReceiverDevice <android-device-id-b>
.\tool\measure_android_resources.ps1 `
  -Device <android-device-id-a> `
  -ApkPath build\app\outputs\flutter-apk\app-profile.apk `
  -ClearAppData
```

除 runner 外，必須人工執行 Wi-Fi/行動網路切換、真實斷網、OS kill、低記憶體裝置
與拔除電源後的長時間耗電測試。AVD 的 `am force-stop` 與電量數據不能取代這些門檻。

## 發布 Gate

- [x] V1-02 安全與隱私稽核、自動化測試通過。
- [x] GitHub Actions Java/Flutter host CI、Windows libsodium/Credential Manager/WebRTC integration、Credential Manager 跨獨立 App process 持久化、Desktop build 與 PostgreSQL container smoke 通過；不取代 production、Windows OS 重開機／使用者工作站政策與手機真機 Gate。
- [ ] V1-01 兩台 Android 真機 encrypted P2P 與 mailbox recovery runner 通過。
- [ ] V1-03 真機冷啟動、記憶體、背景連線、網路與長時間耗電達標。
- [ ] V1-04 真機 OS kill、實際斷網/恢復、重複訊息與 ACK 遺失復原通過。
- [ ] 真實 Firebase credentials、FCM/APNs、通知權限拒絕與 cold/warm start 通過。
- [ ] iPhone Keychain、libsodium、WebRTC、背景 sleep 與跨平台 E2E 通過。
- [x] 繁體中文與英文介面、系統語言偵測、App 內切換／跨重啟保存、fallback 與兩種語言 widget tests 通過。
- [ ] 提供正式 Android application ID、version 與 release keystore；安全簽章設定骨架已完成。
- [ ] 設定正式 iOS Bundle ID、version 與 distribution signing。
- [ ] 以 production HTTPS/WSS + PostgreSQL 環境完成最後 smoke test；本機 TLS/WSS、candidate manifest、backup/restore、staging retention、log rotation 與 monitor 已通過，公開 DNS/ACME、registry、真實 off-host object/receipt、排程與外部告警待驗。
- [ ] 產生 Android/iOS 候選版 artifact，記錄 SHA-256、建置時間與來源 commit；Android 產物/manifest 腳本已完成，正式憑證待執行。
- [ ] README、架構、安全、成本、操作說明與已知限制完成最終同步。

## 已知限制

- V1 僅承諾 1 對 1 文字訊息；群組、多媒體、通話、Desktop Link 與 AI 功能不在範圍。
- `P2P_BOX_V1` 使用長期裝置金鑰，不具 Double Ratchet 的 forward secrecy 或
  post-compromise security。
- TURN fallback 尚未納入 V1；受限 NAT 網路下會改走 offline mailbox，而非即時直連。
- Push credentials 尚未驗證時，使用者必須依賴前景同步或手動同步 mailbox。
- 目前 Android alpha/profile 產物是內部測試用途，不能上架或公開散佈。

## Gate 完成時的紀錄

完成每個未勾選項目時，同步更新本文件、[`project_tasks.md`](project_tasks.md) 與
[`handoff_checklist.md`](handoff_checklist.md)。最後候選版至少記錄：

```text
Version:
Git commit:
Android artifact / SHA-256:
iOS artifact / SHA-256:
Backend image digest:
Test devices / OS versions:
Firebase/APNs environment:
V1-01 result:
V1-03 result:
V1-04 result:
Known release exceptions:
```
