# Simple Communication 交接清單

本文件是接手開發與驗收進度的單一清單。完整依賴與驗收條件仍以
[`project_tasks.md`](project_tasks.md) 為準。

目前主要發布目標仍是 v1.2 藍圖的 V1；因剩餘 Gate 受真機與外部環境阻塞，
使用者已授權先行實作 V1.5 Safety Number、App Lock 與 Low Power Mode 的電腦端
工作，並於 2026-07-26 授權先行實作可由 Windows 主機／Android AVD 完整驗證的
V2 工作。V1 真機與 production Gate 不因此降級；使用者已接續授權 V3 Desktop Link
的主機安全核心、手機端一次性 QR 請求檢閱、公開金鑰 binding、私鑰持有 challenge-response
授權 gate、Desktop Companion host presentation 與受限的 GitHub-hosted Windows module-route
runtime；完整桌面／跨裝置 runtime 仍保留於 backlog。

## 接手摘要（2026-07-26）

目前品牌名稱為 **Simple Communication**。Repository 名稱、Dart package、
Android application ID、iOS Bundle ID、Firebase project 與加密 domain string
維持既有識別，以避免破壞相容性；Android、iOS、Windows 與 App UI 的使用者可見名稱
已統一。

### 現在可以直接進行

- [x] GitHub README 加入產品動機、應用場景、架構、開發沿革與驗證邊界
- [x] 加入原創 Logo、架構展示圖、技術棧 badges 與英文 README
- [x] 統一 Android／iOS／Windows／App UI 顯示名稱
- [x] Flutter 3.44.6 完成 dependency／l10n generation、format、analyze 與完整自動化測試；
  [V1 CI run 30207910328](https://github.com/leezxt/p2p-chat/actions/runs/30207910328) 全部成功
- [ ] 等待 `flutter_webrtc`／`mobile_scanner` 支援 Built-in Kotlin；目前 Flutter template
  管理的 `android.builtInKotlin=false`／`android.newDsl=false` 必須保留
- [x] Android API 35 模擬器完整 APK 啟動，並產出深色首頁、Low Power Mode、App Lock 截圖
- [x] 產出 34 秒 Android API 35 操作 Demo（首頁、Low Power Mode、App Lock、語言選單）
- [ ] 補充 Android 真機操作影片與截圖

### V2 可由主機先行

- [x] V2-01 Emoji／Reaction 主機範圍：版本化事件、SQLite 冪等、P2P／Mailbox fallback、即時更新與雙語 UI tests
- [ ] V2-01 外部 Gate：雙真機離線同步、系統通知呈現與實際操作驗收
- [ ] V2-02 內建貼圖／貼圖包：🚧 只傳 ID、嚴格 manifest、hash／格式／容量／授權、zip-slip 防護、內建資產與雙語 Widget tests 已完成；AVD UI、離線雙端與真機資源驗收待完成
  - [x] 完整 sodium Android debug APK 建置成功；APK 內含三個 ABI 的 `libsodium.so`、貼圖 manifest 與 PNG。大小 `243287062` bytes，SHA-256 `20BA98AAFE855DF6E988439E9C60085E3AE2C0E37230FF0B701F4F97173A0C76`
  - [ ] AVD Gate：舊 AVD 指向已失效的 `<temp>` data partition；以既有 API 35 image 重建 `Simple_Communication_V2_API35`，但目前桌面工作階段無法維持 qemu／adb，因此尚未宣稱 Android UI runtime 通過
- [x] V2-05 Storage Manager 主機核心：SQLite v10 快取索引、資料庫／快取／附件分類、preview-first 清理與關鍵資料保護；目前只清可重建快取，不刪聊天、身份、金鑰或未送 mailbox
- [ ] V2-05 外部 Gate：真機磁碟壓力、OS 清理、大量資料效能與真實附件驗收
- [x] V2-06 Smart Notification 主機核心：SQLite v11 per-chat 靜音／預覽偏好、App Lock 雙重隱私判定、provider-neutral 通知決策與聊天室設定 UI
- [ ] V2-06 外部 Gate：真實 FCM／APNs、系統權限、cold/warm provider routing 與 OEM 通知行為
- [x] V2-04 單則翻譯主機核心：SQLite v12 cache、provider interface、明確 opt-in、原文不改寫、單則清除與 fake provider tests；預設未設定 provider、不傳送內容
- [ ] V2-04 外部 Gate：選定本機／雲端 provider、費用、資料處理條款與實際網路失敗驗收
- [x] V2-03 圖片／語音主機安全核心：Attachment v1 metadata、MIME／大小限制、按需下載／取消／重試與 Low Power policy，模組預設 disabled
- [ ] V2-03 外部 Gate：真實加密 transfer、相機、麥克風、權限、行動網路、AVD UI 與耗電驗收

詳細主機驗收與外部 Gate 見 [`project_tasks.md`](project_tasks.md#v2-主機可先行範圍)。

### V3 可由主機先行

- [x] V3-01 Desktop Link／Device Sync／Revoke 主機安全核心：獨立 `desktop_link` 模組、
  SQLite v13 `desktop_link_authorizations`、手機主裝置明確授權、主裝置 ID 拒絕、
  fingerprint 變更 fail-closed、嚴格只選授權後新訊息，以及撤銷後拒絕新同步選取。
- [x] V3-02 一次性 QR 配對請求與手機端明確確認：SQLite v14
  `desktop_link_pairing_requests`、嚴格版本／欄位／目標主裝置／30–600 秒到期、一次性
  `pending → confirming → confirmed/rejected` 狀態、掃描或貼入後顯示 fingerprint、拒絕後
  不可重放，以及僅在確認對話框同意後才呼叫 V3-01 授權；首頁入口收進「應用工具」選單，
  避免窄螢幕 AppBar 擠出。
- [x] V3-03 QR 公開金鑰 binding 與 canonical request issuer：QR schema v2 必須含 32-byte
  X25519 `publicKey`，手機端以裝置 ID 與該 key 重算 fingerprint，拒絕不一致內容；
  `DesktopLinkPairingRequestIssuer` 僅以公開金鑰建立短效 canonical request。SQLite v15
  安全作廢沒有 key binding 的 v14 暫存 request，不影響既有授權、聊天、身份或金鑰；檢閱頁
  會明示 key binding 本身不等於桌面端持有私鑰。
- [x] V3-04 私鑰持有 challenge-response 與手機授權 gate：沿用既有 X25519 `MessageBox`
  authenticated `crypto_box`，將短效一次性 token 只放在加密 challenge 與手機 RAM；手機嚴格
  驗證 request／主副裝置／公開金鑰 fingerprint／challenge／token／效期。竄改、錯誤 key、重放、
  逾期或 app restart 均 fail-closed，沒有有效 proof 時 `confirm` 不會授權，proof 成功後仍需
  使用者在確認對話框明確同意。
  `NIX_SKIP_SODIUM_BUILD_HOOKS=1` 下的 proof 測試使用 test-only `MessageBox` fake，不宣稱
  原生 libsodium、secure storage、實機或桌面 runtime 已通過。
- [x] V3-05 Desktop Companion QR／手動 challenge presentation：desktop target 的 Desktop Link
  route 會改為顯示本機公開 X25519 key 產生的短效 pairing QR；使用者手動輸入手機主裝置 ID 與
  桌面名稱，貼入手機 challenge 後取得可複製的 encrypted response。手機檢閱頁同時顯示 primary
  device ID，形成無網路、無背景、無 token persistence 的手動流程。service／Widget 與既有 V3
  專項共 38 項主機測試、`dart analyze` 已於 2026-08-09 通過；
  [GitHub Windows CI run 31318234695](https://github.com/leezxt/p2p-chat/actions/runs/31318234695)
  另以真實 `SodiumMessageBox`、QR rendering、主端角色 proof 與受控 clipboard copy 通過受限
  Windows native flow，並以 SQLite FFI、實際 `ModuleRegistry`、`RouteRegistry` 與 `Navigator`
  test shell 證明 `/desktop-link` 會選擇 Companion 而不是手機 pairing 頁。這不是實體手機與桌面的
  真實跨裝置同步，也不等於完整 `bootstrap`／首頁使用者旅程證據。
- [ ] V3 外部 Gate：macOS／Linux 原生 runner、目前本機 Windows 完整 `bootstrap`／首頁使用者流程、
  目標主裝置 discovery／自動交付，Android／iOS 真實相機權限與掃碼、實際桌面端 transport、
  每副端重新加密、真實多裝置同步／網路故障，以及撤銷後副端無法取得或解密新訊息的
  Windows／Android／iOS runtime 驗收。
  `mobile_desktop_app/tool/verify_windows_desktop.ps1` 現在統一 Windows preflight、debug build、
  secure-storage process restart、Desktop Companion native integration 與 module-route integration；
  native run 一律拒絕 `NIX_SKIP_SODIUM_BUILD_HOOKS`。最後記錄的本機 2026-08-09 preflight 顯示未安裝
  Visual Studio Desktop development with C++／MSVC／CMake／Windows SDK；CI 已通過受限 native flow，
  但本機 runner 仍需安裝後執行此入口，且不能以 CI 成功勾選其餘跨裝置 Gate。

詳細安全邊界與未完成 protocol 見 [`desktop_link.md`](desktop_link.md)。

### 需要 Android API 24+ 真機

- [ ] 兩台真機 encrypted P2P、Mailbox fallback 與 `STORED → DELIVERED → READ`
- [ ] 實際斷網、OS kill、ACK 遺失恢復與重複訊息驗證
- [ ] App Lock 生物辨識、Safety Number 相機掃碼與雙機人工核對
- [ ] 冷啟動、記憶體、背景連線、網路與長時間耗電量測

### 需要正式憑證或部署環境

- [ ] 真實 FCM／APNs 與 Android／iPhone notification runtime
- [ ] Android application ID／keystore 與 iOS Bundle ID／distribution signing
- [ ] 公開 DNS／ACME、registry digest 與 production HTTPS/WSS smoke
- [ ] 正式排程、外部告警、加密 off-host storage 與 restore drill
- [ ] 產生最終 Android／iOS artifacts 並記錄 SHA-256

詳細依賴仍以 [`project_tasks.md`](project_tasks.md) 與
[`release_candidate_v1.md`](release_candidate_v1.md) 為準。下方保留歷次交接紀錄，
供追溯測試證據與決策背景。

## 勾選規則

- `[ ]`：尚未完成，或已有程式但尚未通過指定驗證。
- `[x]`：實作、測試與必要文件均已完成，且驗證結果可重現。
- 每完成一項工作，必須在同一次變更中勾選本清單，並更新受影響的 README 或 `docs/` 文件。
- 不可只因程式碼存在就勾選；需要實機、容器或外部服務的項目，必須完成對應環境驗證。

## 目前交接（2026-07-19 17:43 +08:00）

目前目標：接續不需要手機與正式 alert credentials 的 V1 發布工作，將既有 production
monitor 補成可交給排程器安全執行的 stateful failure／recovery webhook runner。

- [x] **已完成**：新增 `run-production-monitor.ps1`；呼叫既有 one-shot monitor，驗證 PASS／FAIL 與 exit code 一致，輸出仍保留非零 health failure 語意
- [x] **已完成**：同一 state file 使用 OS file lock 阻擋重疊執行；只有取得 lock 的程序可清除 lock，state 以 temporary file 原子替換且拒絕 corrupt／unsupported state
- [x] **已完成**：第一次 PASS 只建立 baseline；首次／轉換為 FAIL 送 `PRODUCTION_HEALTH_FAILED`，FAIL 轉 PASS 送 `PRODUCTION_HEALTH_RECOVERED`，相同狀態不重複告警
- [x] **已完成**：正式 webhook 強制 HTTPS、停用 redirect；可選 Bearer token 只進 Authorization header，不寫 state／payload／輸出，payload 不含 monitor error 或 env secrets
- [x] **已完成**：Webhook 非 2xx／連線失敗時 state 不前進，下次排程會重試 transition；local verification 只允許 loopback HTTP/HTTPS
- [x] **已完成**：新增 `test-production-monitor-alerting.ps1`，實際 loopback POST 驗證 failure、recovery、重複抑制、HTTP 500 重試、payload 去敏、HTTPS 限制與 overlap lock 全部通過
- [x] **已完成**：fixture 接入 V1 CI PostgreSQL job；`production.env.example`、backend README、testing、RC 與 project tasks 已同步
- [x] **已完成**：PowerShell parser、alert／off-host export／retention fixtures、YAML parse、`git diff --check` 與 Java 52 tests 全部通過
- [x] **已完成**：GitHub run `29682241853` 的 Ubuntu fixture 所有斷言回 `PASS`，但 process 沿用最後一個刻意 FAIL monitor 的 exit 1；fixture 清理後新增明確 `exit 0`，獨立 `pwsh -File` 重跑為 PASS／exit 0
- [x] **已完成**：commits `e67715d`／`517b871` 已推送；Draft PR #54 V1 CI run `29682331513` 的 Ubuntu alert／backup fixtures、Flutter、Java、PostgreSQL 與 Windows Desktop 全部成功
- [ ] **已實作未驗證**：正式 systemd timer／Task Scheduler、service-account ACL、真實 alert receiver 與 on-call routing 仍待 deployment environment 驗收

變更範圍：scheduled production monitor／alert fixture、V1 CI、production env example、
backend 操作說明、testing、release candidate、project tasks 與本交接清單。

驗證：Windows PowerShell fixture 回傳 `PASS`；failureAlertSent、overlapRejected、
duplicateSuppressed、recoveryAlertSent、insecureWebhookRejected、placeholderRejected、rejectedDeliveryRetried 與
payloadRedacted 全為 true。Off-host export／retention fixtures PASS；PowerShell parser、YAML、
diff check 與 Java 52 tests／0 failures／0 errors 通過。

Runtime：本輪 fixture 的 loopback TCP jobs 均已完成並移除，temporary test directory 已由
finally 安全清除；未啟動 Docker、backend、AVD 或手機，沒有需停止的 managed runtime。

下一步：取得 production host 與 alert receiver 後建立正式 systemd timer／Task Scheduler、
service-account ACL 與 on-call routing，執行 failure／recovery drill；沒有 credentials 時接續
其他 release artifact 工作，不因 fixture 成功勾選正式 deployment Gate。

## 上次交接（2026-07-19 17:16 +08:00）

目前目標：接續不需要手機與正式雲端 credentials 的 V1 發布工作，補齊 production
backup 從 local staging 到獨立掛載 off-host storage 的可驗證 export／receipt 契約。

- [x] **已完成**：新增 `export-production-backup.ps1`，匯出前驗證 regular dump／manifest、schema、filename、size、custom format 與 SHA-256
- [x] **已完成**：目的地必須為 staging 外的既有 regular directory；dump／manifest 以 temporary file 複製並重讀 hash 後移入，同名相同內容可冪等重跑，不同內容 fail-closed
- [x] **已完成**：storage reference 必須是無 userinfo/query/fragment 的 absolute URI；目的地兩個 hash 驗證完成後才原子建立 schema 2 receipt，綁定 dump hash／size 與 manifest hash
- [x] **已完成**：prune 保留 schema 1 receipt 相容，對 schema 2 強制驗 manifest binding；匯出後 local manifest 被替換時備份轉為 protected
- [x] **已完成**：prune Apply 在刪除前重新驗 manifest schema／filename／size／format／hash，以及 receipt schema／hash／reference／時間與 schema 2 binding，避免掃描後替換
- [x] **已完成**：新增 `test-backup-offhost-export.ps1`，正向匯出、重跑冪等、retention receipt 相容、manifest binding、來源竄改、目的地衝突與 credential-like reference 拒絕全部通過
- [x] **已完成**：off-host export fixture 接入 V1 CI PostgreSQL job；backend README、testing、RC 與 project tasks 已同步
- [x] **已完成**：Windows PowerShell parser、off-host export fixture、既有 retention fixture、YAML parse、`git diff --check` 與 Java 52 tests 全部通過
- [x] **已完成**：commit `8dc2d58` 已推送；Draft PR #54 V1 CI run `29681462407` 的 Ubuntu off-host fixture、Flutter、Java、PostgreSQL 與 Windows Desktop 全部成功
- [ ] **已實作未驗證**：正式環境仍需驗證目標確實為加密 off-host storage、provider retention／存取控制與定期 restore drill；本工具不能由掛載路徑自行證明這些外部屬性

變更範圍：production backup off-host export／fixture、V1 CI、backend 操作說明、testing、
release candidate、project tasks 與本交接清單。

驗證：Windows PowerShell parser 通過；fixture 回傳 `PASS`，exported=1、idempotent、
retentionCompatible、manifestBindingVerified、schema2ApplyVerified、tamperedSourceRejected、destinationCollisionRejected 與
credentialReferenceRejected 全為 true。既有 retention fixture PASS；YAML parse、diff check 與
Java 52 tests／0 failures／0 errors 通過。尚未啟動 Docker、backend、AVD 或手機。

Runtime：本輪只有短命 PowerShell fixture，temporary test directory 已由 finally 安全清除；
目前沒有需停止的 managed runtime。

下一步：取得正式 storage provider／掛載與 access policy 後執行真實 off-host export、
provider-side hash／retention 及 restore drill；未取得 credentials 時可接續 production
排程／外部告警的本機契約，不把 mounted fixture 當成正式 off-host Gate。

## 上次交接（2026-07-19 16:41 +08:00）

目前目標：擴大不使用手機的 App Lock production runtime 驗證，在已 enrollment 的
Android 15 AVD 自動覆蓋 biometric success／cancel；AVD 結果不得取代真機 Gate。

- [x] **已完成**：integration test 改以 `BIOMETRIC_EXPECTATION` 支援 `skip`、`notEnrolled`、`success`、`cancel`，並保留未指定時跳過 biometric assertion
- [x] **已完成**：PowerShell runner 保留 `-ExpectUnenrolledBiometrics` 相容入口，新增受控 emulator 專用的 `-BiometricExpectation`；非 emulator 會直接拒絕自動 assertion
- [x] **已完成**：runner 可等待 production `local_auth` 系統提示；success 自動送入 finger ID `1`，cancel 自動送出 Android 返回鍵，逾時或測試失敗會保留 log 並回傳失敗
- [x] **已完成**：Android 15 API 35 AVD 設定鎖屏 PIN、完成一枚模擬指紋 enrollment；success 與 cancel 各自重跑 2 項 native integration tests，全部通過
- [x] **已完成**：163-file format、全專案 `flutter analyze --no-pub` 與 PowerShell parser 通過
- [ ] **已實作未驗證**：Android/iPhone 真機 enrollment change、真實指紋／Face ID 感測器差異、secure storage 跨 OS restart、備份還原與企業裝置政策仍待真機驗收
- [x] **已完成**：清除本輪 AVD 鎖屏 PIN 與模擬指紋 enrollment，`emulator-5554` 已以 `adb emu kill` 乾淨停止，`adb devices` 無殘留裝置
- [x] **已完成**：App Lock 16 項 host tests、163-file format、全專案 analyze、PowerShell parser 與最終 diff check 通過
- [x] **已完成**：commit `e84d1fd` 已推送；Draft PR #54 V1 CI run `29680341499` 的 Flutter、Java、PostgreSQL 與 Windows Desktop 四項全部成功

變更範圍：Android App Lock runtime integration test、PowerShell runner、testing、
project tasks 與本交接清單。

驗證：`-BiometricExpectation success` 與 `cancel` 各自於 production SodiumSumo、
Android encrypted storage、lifecycle coordinator 與 `local_auth 3.0.2` 執行；兩輪皆為
2 tests、All tests passed。App Lock host tests 首次受本機缺少 Visual Studio `vswhere`
阻擋於 sodium build hook，依既有方式設定 `NIX_SKIP_SODIUM_BUILD_HOOKS=1` 後 16 tests
全通過；該跳過只用於 fake／mock host tests，production sodium 已由 AVD native tests
覆蓋。format 163 files／0 changes、analyze 零問題、PowerShell parser 與 diff check 通過。

Runtime：`emulator-5554`（AVD `p2p_api35`）先以 `locksettings clear --old 246810`
清除測試 PIN；清除後 fingerprint enrollment count 不再出現，再以 `adb emu kill` 乾淨
停止，`adb devices` 無殘留裝置。未啟動 Docker、backend 或其他 App。

下一步：真機可用時再補 Android/iPhone enrollment change、感測器差異、secure storage
跨 OS restart 與系統政策；沒有真機時接續其他不依賴 credentials／production authority
的 V1.5 backlog，不因 AVD 成功關閉真機 Gate。

## 上次交接（2026-07-18 22:31 +08:00）

目前目標：以 Android 15 AVD 補 App Lock production runtime 驗收，覆蓋真實 Argon2id、
secure storage、background lock 與未註冊 biometric fail-closed；不得取代真機 Gate。

- [x] **已完成**：盤點 production App Lock、lifecycle 與 integration runner；本機 `p2p_api35` AVD 具 fingerprint HAL，沒有 enrollment
- [x] **已完成**：新增 `android_app_lock_runtime_test.dart`，使用 production SodiumSumo hasher、Android secure storage、local_auth adapter 與 lifecycle coordinator
- [x] **已完成**：真實 Argon2id verifier 不含 PIN；同一 Android encrypted storage 重載後預設鎖定，錯誤 PIN 不解鎖、正確 PIN 可解鎖，paused 後立即重新鎖定且 resumed 不自動解鎖
- [x] **已完成**：具 fingerprint HAL、未 enrollment 的 Android 15 AVD 上，production local_auth adapter 回傳 `notEnrolled` 且不解鎖
- [x] **已完成**：新增 `verify_android_app_lock.ps1`，驗證裝置、限制 unenrolled assertion 只能用受控 emulator，設定 native build PATH 與低併發後執行測試
- [x] **已完成**：CI format Gate 擴充至 `lib test integration_test`；163 files／0 changes、全專案 analyze、16 項 App Lock 回歸與 runner native 2 tests 均通過
- [ ] **已實作未驗證**：Android/iPhone 真機 enrollment change、biometric 成功／取消、secure storage 跨 OS restart 與系統政策仍待實機驗收
- [x] **已完成**：commit `a74715c` 已推送；Draft PR #54 V1 CI run `29648009386` 的 Flutter、Java、PostgreSQL 與 Windows Desktop 四項全部成功

變更範圍：Android App Lock runtime integration test、PowerShell runner、CI format 範圍、testing、
project tasks 與本交接清單。

驗證：第一次 native build 因三個閒置 Gradle/Kotlin daemon 占約 4.3 GB，使 sodium hook 無法
建立 Dart worker；記錄後正常停止 daemon、限制 2 workers 重跑通過。新 runner 再次獨立重跑
2 tests 通過；163-file format、analyze 與 App Lock 16 tests 通過。GitHub run `29648009386`
完整四項 Gate 全綠。

Runtime：`emulator-5554`（AVD `p2p_api35`）已以 `adb emu kill` 乾淨停止，`adb devices`
無殘留裝置；先前 Gradle/Kotlin daemon 已正常退出。未啟動 Docker、backend 或其他 App。

下一步：有真機時再驗 enrollment change、biometric 成功／取消與 secure storage 跨 OS
restart；沒有實機時接續其他不依賴 credentials／production authority 的項目。AVD 結果
不得關閉真機 Gate。

## 上次交接（2026-07-18 21:58 +08:00）

目前目標：降低 App Lock 生物辨識套件的 AGP 9／舊 API 維護風險，升級至
`local_auth 3.x`，並保留 biometric-only、取消不解鎖與 PIN fallback 語意。

- [x] **已完成**：盤點 App Lock production adapter 與 platform fake；確認公開 API 改為 `biometricOnly`／`persistAcrossBackgrounding`，錯誤改用 `LocalAuthExceptionCode`
- [x] **已完成**：升級 `local_auth 3.0.2`、`local_auth_android 2.0.9`、`local_auth_darwin 2.0.3`、platform interface 1.1.0 與 transitive Windows 2.0.1
- [x] **已完成**：adapter 改用 structured exception mapping；硬體不可用、未註冊、暫時／永久鎖定、使用者／系統取消及其他裝置失敗維持分流，不會因失敗而解鎖
- [x] **已完成**：16 項 App Lock adapter/service/widget tests、158-file format check 與 `flutter analyze --no-pub` 通過
- [x] **已完成**：skip-sodium Android debug APK 建置通過；`local_auth_android` 已不再出現在 KGP future warning，剩餘警告只有既知的 `flutter_webrtc`／`mobile_scanner`
- [x] **已完成**：README／testing 的實際工具鏈下限同步為 Flutter 3.44／Dart 3.12；根 package metadata 暫不提高，以避免無關 formatter migration
- [x] **已完成**：GitHub V1 CI run `29646948250` 的 Windows Desktop debug build 通過，`local_auth_windows 2.0.1`、native crypto、secure storage、WebRTC integration 與跨 App process persistence 均無回歸
- [ ] **已實作未驗證**：Android/iPhone enrollment change、Argon2id、secure storage、background/resume 與 biometric runtime 仍待實機驗收

變更範圍：App Lock `local_auth` adapter／tests、`pubspec.yaml`／lock、README、testing、
project tasks 與本交接清單。

驗證：App Lock 16 tests 全通過；format 158 files／0 changes；analyze 零問題；Android debug
APK `243259582` bytes，SHA-256
`EA964705D52438C82A9DC1BB51FD32FE8E287A2A52A716EE8ED6D5F172DB942A`。Build 使用
skip-sodium，只驗證 Dart／Android plugin／Gradle 編譯，不取代先前真實 sodium runtime。
V1 CI run `29646948250` 的 Flutter、Java、PostgreSQL 與 Windows 四項 jobs 全部成功。

Runtime：本機 Flutter／Gradle build 已完成；未啟動 Docker、ADB、AVD、App 或 backend。
Windows build 未啟動編譯程序，因本機無 Visual Studio C++ toolchain。

下一步：有 Android 或 iPhone 實機時驗證 enrollment change、biometric cancel/success、背景
鎖定與 PIN fallback；沒有實機時接續其他不依賴 credentials／production authority 的項目。

## 上次交接（2026-07-18 21:33 +08:00）

目前目標：降低 Android AGP 9／Kotlin deprecation 風險，先升級可控的 QR scanner，並驗證
Flutter 3.44.6 built-in Kotlin migration 邊界；不得破壞既有 crypto／WebRTC build。

- [x] **已完成**：以 Flutter 3.44.6 官方 template 與 CI log 定位警告；`android.builtInKotlin=false`／`android.newDsl=false` 由 Flutter migrator 管理，非可直接刪除的一般專案設定
- [x] **已完成**：確認 `flutter_webrtc 1.5.2` 已具 AGP 9 conditional KGP 邏輯；`mobile_scanner 6.0.11` 為無條件套用 KGP 的舊版
- [x] **已完成**：升級至 `mobile_scanner 7.3.0`；同步 Dart ≥3.7／Flutter ≥3.29 下限，並依 breaking API 將 scanner `errorBuilder` 改為兩參數
- [x] **已完成**：根 package metadata 保持 Dart 3.6／Flutter 3.27，避免觸發 l10n 與 103 個既有檔案的 formatter migration；scanner dependency 仍使實際解析／執行最低版本為 Dart 3.7／Flutter 3.29
- [x] **已完成**：首次 V1 CI `29645881265` 只有 format step 失敗；根因是提高 root language version 觸發新 formatter，修正後完整 `dart format --output=none --set-exit-if-changed lib test` 為 158 files／0 changes
- [x] **已完成**：新版 scanner 的 Android script 已能依 AGP 9 built-in Kotlin 狀態條件套用 KGP；最低 Android API 23 低於本專案 API 24 Gate
- [x] **已完成**：7 項 Safety Number tests、Dart format、`flutter analyze --no-pub` 與 skip-sodium Android debug APK 建置通過
- [x] **已完成**：debug APK 大小 `218609212` bytes，SHA-256 `CECB076033920B401A2C683E5E6887AAA8286D0C9AC950A09EFA4B7035A95BD7`
- [x] **已完成**：最終 V1 CI run [29646141895](https://github.com/leezxt/p2p-chat/actions/runs/29646141895) 的 format、analyze、完整 Flutter tests、Java、PostgreSQL 與 Windows native／desktop jobs 全部成功
- [x] **已完成**：免費 Test Lab run [29645884176](https://github.com/leezxt/p2p-chat/actions/runs/29645884176) 的 scanner Kotlin compile、debug／androidTest APK、OIDC、catalog、bucket 與 artifact upload 通過；submission／monitor skipped，未建立 matrix
- [ ] **已實作未驗證**：移除 built-in Kotlin 相容旗標的實驗 build 會被 Flutter 3.44.6 migrator 自動重加；已恢復受支援模板設定，完整遷移需等待 Flutter toolchain 開放
- [ ] **已實作未驗證**：模板仍為 `builtInKotlin=false` 時，`flutter_webrtc` 與 `mobile_scanner` 會依相容邏輯套用 KGP，因此 build summary 仍有未來淘汰警告；目前 build 可用且 Kotlin 2.3.20 版本警告已避免
- [ ] **已實作未驗證**：真實相機權限允許／拒絕、QR 掃碼與兩台裝置 Safety Number 一致性仍待 Android/iPhone 實機驗收

變更範圍：`mobile_desktop_app/pubspec.yaml`／lock、Safety Number scanner callback、兩處
generated l10n formatter normalization，以及 README、testing、project tasks 與本交接清單。
實驗性的 Gradle 設定移除與 103-file formatter churn 均未保留。

驗證：`flutter pub get` 成功；Safety Number 7 tests、158-file format、analyze、Android debug
APK、GitHub 完整 V1 CI 與 Test Lab instrumentation build 均通過。Artifact ID `8430113821`、
大小 `111858436` bytes、annotations `[]`。Build 使用 skip-sodium，只驗證 scanner／Gradle
編譯，不取代先前真實 sodium runtime。

Runtime：兩個 GitHub workflows 與本機 Flutter／Gradle build 均已完成；未啟動 Docker、
ADB、AVD、App 或 backend，沒有 Test Lab matrix 或需停止的 managed process。

下一步：Flutter toolchain 未移除兩個相容旗標前，不重複嘗試 built-in Kotlin migration。
真機可用時驗證 camera permission、QR 掃碼與雙裝置 Safety Number；否則改處理其他不依賴
實機／credentials／production authority 的項目。

## 上次交接（2026-07-18 18:57 +08:00）

目前目標：清除 Test Lab workflow 的 GitHub Actions Node.js 20 deprecation，維持 action
commit SHA pinning，並以免費 dry-run 驗證 artifact 上傳；本輪未送出付費 matrix。

- [x] **已完成**：以 GitHub 官方 release／tag API 確認 `actions/upload-artifact v7.0.1`，並鎖定 commit `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`
- [x] **已完成**：Test Lab workflow 由 `upload-artifact v4` 升級至 pinned `v7.0.1`；現有契約測試加入精確 SHA／版本檢查
- [x] **已完成**：本機 Test Lab monitor 契約測試、PyYAML workflow parse 與 `git diff --check` 通過
- [x] **已完成**：V1 CI run [29641319099](https://github.com/leezxt/p2p-chat/actions/runs/29641319099) 的 Java、PostgreSQL、Flutter 與 Windows Desktop 四個 jobs 全部成功
- [x] **已完成**：免費 Test Lab run [29641323307](https://github.com/leezxt/p2p-chat/actions/runs/29641323307) 通過；artifact `firebase-test-lab-29641323307-1` 成功 finalized，submission／monitor steps 明確 skipped
- [x] **已完成**：Test Lab check-run annotations 為空，完整 log 不再出現 Node.js 20 deprecation；確認 action 實際載入上述 pinned SHA
- [ ] **已實作未驗證**：Android build 仍顯示 Kotlin plugin、`android.builtInKotlin`／`android.newDsl` 與 Gradle 10 相容性警告；不影響本項 action runtime 驗收，後續需分開升級 Android toolchain／plugins
- [ ] **已實作未驗證**：首次成功 Test Lab 實體機 runtime、兩台真機 E2E、實際斷網、OS kill、網路／記憶體／耗電 Gate 仍未完成

變更範圍：`.github/workflows/firebase-test-lab.yml`、
`mobile_desktop_app/tool/test_monitor_firebase_test_lab.sh`、`docs/project_tasks.md` 與本交接清單。

驗證：本機 monitor 契約、YAML parse、diff check 通過；GitHub V1 CI 與免費 Test Lab
preflight 均成功。Artifact ID `8428812533`、大小 `110939636` bytes、annotations `[]`；未建立
`matrix-id.txt` 或執行付費 submission。

Runtime：兩個 GitHub workflows 均已完成；沒有 Test Lab matrix、Docker、ADB、AVD、App
或 backend 在本輪執行。

下一步：Android toolchain deprecation 可在電腦繼續處理，但需先分辨 app 自有設定與
`mobile_scanner`／`flutter_webrtc` 等第三方 plugin 警告；不得為消除警告破壞既有 Android
crypto／WebRTC build。真機可用時仍優先完成 V1-01/03/04。

## 上次交接（2026-07-18 18:06 +08:00）

目前目標：將 V1.5 安全／低功耗與 V1-01 Test Lab lifecycle 修正發布至 Draft PR，
並以免費 GitHub dry-run 驗證完整 preflight；本輪未送出付費 matrix。

- [x] **已完成**：依 2026-05-27 官方 gcloud／Testing API 文件確認 `run --async`、device capacity、matrix GET 與 `:cancel` 契約
- [x] **已完成**：workflow job 上限由 45 分鐘調整為 180 分鐘；新增 15～120 分鐘可設定 queue timeout，裝置 instrumentation 仍限制 10 分鐘，開始執行後監控最多 30 分鐘
- [x] **已完成**：submission 改為 `--async --format=json`，立即驗證並保存 `matrix-submit.json`、`matrix-id.txt` 與 GitHub step output，不再讓同步 gcloud 命令獨占整個 job
- [x] **已完成**：新增 `monitor_firebase_test_lab.sh`；透過 Testing API 保存最新 JSON／摘要，只有 `FINISHED / SUCCESS` 通過，其他 terminal outcome fail closed
- [x] **已完成**：監控腳本在 queue/run timeout、連續 API 失敗、SIGINT、SIGTERM 或非 terminal exit 時呼叫 `:cancel`；access token 每次查詢刷新，避免長排隊超過 token 壽命
- [x] **已完成**：preflight 保存 `list-device-capacities` JSON；付費 submission 預設拒絕 `Low`／`None`／Unknown，只有明確 `allow_low_capacity=true` 才允許 Low；免費 dry-run 仍可檢視 Low／Unknown
- [x] **已完成**：新增 matrix ID extractor 與本機契約測試；SUCCESS 不取消、PENDING timeout 取消、FINISHED/FAILURE 不誤判成功、非法 matrix ID 拒絕，workflow async／cleanup wiring 與「非 `main` 只能 dry-run」亦有檢查
- [x] **已完成**：本機 Test Lab monitor tests、3 個 bash scripts syntax、Python compile、workflow YAML parse 與目前 `CPH2449 / API 34 = Low` catalog 查詢通過
- [x] **已完成**：建立 Draft PR [#54](https://github.com/leezxt/p2p-chat/pull/54)；workflow 允許明確授權分支執行 `submit_test=false`，但任何非 `main` 的付費 submission 仍 fail closed
- [x] **已完成**：GitHub run [29639354427 attempt 2](https://github.com/leezxt/p2p-chat/actions/runs/29639354427/attempts/2) 免費 dry-run 通過；APK build、OIDC、實體 catalog、capacity 與 bucket 寫入／刪除成功，submission／monitor steps 明確 skipped
- [x] **已完成**：evidence artifact `firebase-test-lab-29639354427-2` 已下載核對；`CPH2449 / API 34 = Low`、`submit_test=false`，且不存在 `matrix-id.txt` 或 `matrix-submit.json`
- [x] **已完成**：WIF attribute condition 保留不可變 repository／owner ID，僅由 `main` 額外精確允許 `codex/v15-security-low-power-ftl`；未開放任意功能分支
- [ ] **已實作未驗證**：首次成功 Test Lab 實體機 runtime、兩台真機 E2E、實際斷網、OS kill、網路／記憶體／耗電 Gate 仍未完成

變更範圍：`.github/workflows/firebase-test-lab.yml`、
`mobile_desktop_app/tool/monitor_firebase_test_lab.sh`、matrix ID extractor／契約測試，
V1.5 Safety Number／App Lock／Low Power Mode，以及 Firebase Test Lab、testing、release
candidate、project tasks 文件。

驗證：本機 monitor 契約測試、YAML parse 與 `git diff --check` 通過。GitHub run
`29639354427` attempt 2 完整 preflight 成功；artifact 的 APK SHA-256、capacity JSON 與
bucket preflight log 均存在，且沒有 matrix submission 證據。未建立或送出任何 Test Lab
matrix，沒有產生本輪實體裝置費用。

Runtime：GitHub workflow 已完成，沒有執行中的 Test Lab matrix。未啟動 Docker、ADB、
AVD、App 或 backend；本機只保留下載至 `%TEMP%` 的 CI evidence 副本。

下一步：保持 PR #54 為 Draft；選擇 `Medium`／`High` 容量實體 model 後，再由使用者明確
確認一次 `main` 的付費 submission。單一 Test Lab 裝置仍不取代兩台真機 E2E、實際斷網、
OS kill 與資源 Gate。PR 合併並刪除功能分支後，將 WIF provider condition 收回只允許
`refs/heads/main`。

## 上次交接（2026-07-18 14:13 +08:00）

目前目標：完成 V1.5 EPIC-10 Low Power Mode 的電腦端策略、持久化、設定 UI 與
自動化測試，並保留真機資源量測 Gate。

- [x] **已完成**：新增具 `init / activate / sleep / dispose` 的獨立 `LowPowerModule`；預設關閉，沿用 SQLite `app_settings` 保存，不新增 schema migration
- [x] **已完成**：新增 `LowPowerModeChanged`；偏好載入與切換後經 Event Bus 發送，Presence／P2P 不直接呼叫 Low Power 內部實作
- [x] **已完成**：一般／低功耗 Presence heartbeat 為 60／180 秒；前景執行中切換會取消舊 timer 並依新間隔重排，背景仍停止 heartbeat
- [x] **已完成**：一般／低功耗 P2P 上限為 3／1；超額 outbound 被拒絕、inbound 被關閉，切換後會收斂既有 sessions
- [x] **已完成**：一般／低功耗 P2P 閒置斷線為 2／1 分鐘；成功連線、傳送或接收密文後重排 timer，背景 P2P 仍永遠關閉
- [x] **已完成**：低功耗時強制停用圖片自動下載及重型模組自動啟動；一般模式保留既有使用者偏好
- [x] **已完成**：首頁新增會即時反映狀態的電池圖示，設定頁採 toggle；繁中／英文標題、狀態與說明已由 `gen-l10n` 產生
- [x] **已完成**：17 項 Low Power／Presence／P2P 專項測試通過；包含預設值、Event Bus、SQLite 跨重啟、動態 interval、P2P 上限／收斂／idle 與繁中 Widget
- [x] **已完成**：設定 `NIX_SKIP_SODIUM_BUILD_HOOKS=1` 並排除既有 Windows-native `device_key_service_test.dart` 後，125 項 Flutter host tests 全通過；`flutter analyze --no-pub` 零問題
- [x] **已完成**：同一 skip-hook 環境下 Android debug APK 編譯通過，SHA-256 `E674EBEA5868904906B04755628F8F3ED588EBAC29B3D7CD905988D7278D7E98`；此 APK 不含 sodium native asset，只作編譯驗證
- [ ] **已實作未驗證**：Low Power 策略與 UI 已完成，但 Android/iPhone 真實前景 heartbeat、連線收斂、背景零 P2P、耗電、網路與記憶體仍待實機量測
- [ ] **已實作未驗證**：完整 Windows sodium native host test 仍受本機缺少 Visual Studio C++／`vswhere.exe` 阻塞；本輪未修改 device-key 實作

變更範圍：`mobile_desktop_app/lib/modules/low_power/`、`ResourcePolicyService`、
`PresenceService/Module`、`P2pSessionManager/Module`、Bootstrap、聊天列表設定入口、
ARB/generated l10n、Low Power／Presence／P2P tests，以及 README／架構／任務文件。

驗證：`flutter gen-l10n` 成功；17 項專項與 125 項 host suite 通過；
`flutter analyze --no-pub` 零問題；formatter 158 files 零變更；`git diff --check`
通過（只有既有行尾警告）；Android skip-hook debug build 成功。初次未設定 skip hook
的測試因找不到 Visual Studio `vswhere.exe` 失敗，改用既有 host-test skip 方式後通過。

Runtime：本輪未啟動 Docker、AVD、App、backend 或其他長時間程序；Flutter 指令均已
正常結束，沒有需停止的 managed runtime。

下一步：有實機時執行 Low Power 前景／背景資源量測，並接續 App Lock
notification／biometric lifecycle 與 Safety Number QR。iOS 在 Mac 驗證
Keychain／Face ID／相機、Low Power 與 OS 通知；沒有實機時接續下一個 V1.5
電腦端 backlog。

## 上次交接（2026-07-18 14:01 +08:00）

目前目標：在 Safety Number 與生物辨識真機 Gate 等待期間，完成 V1.5 EPIC-11
App Lock notification privacy 的偏好、Event Bus 狀態、Push 呈現策略與電腦端測試。

- [x] **已完成**：新增獨立 `AppLockModule`，沿用 Crypto module 註冊的 `SecureKeyValueStore`；App Lock 不取代裝置私鑰保護
- [x] **已完成**：6 位 PIN 使用 libsodium `crypto_pwhash_str` Argon2id interactive profile；encoded verifier 內含 salt／成本參數，secure storage 不保存 PIN 明文，未自行實作 KDF
- [x] **已完成**：五次錯誤後冷卻 30 秒，錯誤次數與期限可跨重啟保存；設定損壞時 fail-closed，不顯示聊天內容
- [x] **已完成**：根層 `AppLockGate`、繁中／英文解鎖與設定頁、啟用／停用／立即鎖定完成；App 進入 background 立即鎖定
- [x] **已完成**：加入可替換 `AppLockBiometricAuthenticator` 與 `local_auth` Android/iOS adapter；只接受 biometric-only 系統驗證，不接觸或保存生物特徵
- [x] **已完成**：生物辨識啟用前需先成功驗證；opt-in 保存於既有 secure storage，鎖定畫面自動嘗試辨識，取消／失敗／未註冊／系統鎖定不解鎖且 PIN 始終可用
- [x] **已完成**：Android 改用 `FlutterFragmentActivity`、加入 `USE_BIOMETRIC` 與 AppCompat theme；iOS 加入 `NSFaceIDUsageDescription`；`local_auth` federated packages 維持鎖定，專案目前最低工具鏈為 Flutter 3.29／Dart 3.7
- [x] **已完成**：App Lock 3 項 adapter、6 項 service 與 6 項 Widget tests 通過；跨重啟 biometric／notification opt-in、成功／取消／錯誤映射、PIN fallback 及移除 enrollment 後仍可停用均有覆蓋
- [x] **已完成**：新增 `AppLockStateChanged`，只含 enabled／locked／hide flags；Push module 經 Event Bus 訂閱並在 dispose 取消，不直接呼叫 App Lock 內部實作
- [x] **已完成**：新增 privacy-first `NotificationPresentationPolicy`；狀態未知、App 鎖定、預設隱藏或缺少本機資料時強制通用文字，只有已解鎖且明確 opt-out 才允許本機 sender／preview
- [x] **已完成**：App Lock 設定頁新增預設開啟的通知隱私開關與繁中／英文 UI；偏好與 verifier 一起保存於 secure storage
- [x] **已完成**：4 項 notification policy/module wiring tests 通過；排除既有 Windows-native `device_key_service_test.dart` 後，117 項 Flutter host tests 全通過；`flutter analyze --no-pub` 零問題，formatter 151 files 零變更
- [x] **已完成**：設定 `NIX_SKIP_SODIUM_BUILD_HOOKS=1` 後，含最新 Push/App Lock 啟動順序的 Android debug APK 編譯通過；SHA-256 `D906A452984E2567A7319D191483B0AB896697065E33475E67D2523977294371`。此 APK 不含 sodium native asset，只作編譯驗證，不可作 runtime 測試版
- [ ] **已實作未驗證**：未跳過 sodium hook 的 Android build 已找到 Git Bash，但現有 NDK 28 libsodium automake C 編譯失敗；未取得可安裝的本輪完整 native APK
- [ ] **已實作未驗證**：Android/iPhone 生物辨識、enrollment change、App Lock Argon2id／secure storage／background-resume 及 Safety Number 相機掃碼仍待實機驗收
- [ ] **已實作未驗證**：provider-neutral notification privacy policy 已完成；真實 FCM/APNs notification presentation provider、Android/iOS OS lock-screen 呈現仍需 credentials 與實機驗收
- [ ] **已實作未驗證**：iOS `local_auth`／Face ID 設定已完成；Xcode build、Keychain／Face ID runtime、iPhone 相機與跨平台 Safety Number 核對仍需 Mac／實機

- [x] **已完成**：新增獨立 `SafetyNumberModule`，沿用現有 `IdentitySession`、`DeviceKeyMaterial` 與 `ContactRepository`，未修改 Core 契約
- [x] **已完成**：Safety Number 將雙方 user/device ID 與 32-byte 公鑰排序後以版本化 canonical JSON 計算 SHA-512；兩端參與者順序對調仍產生相同 60 位顯示碼
- [x] **已完成**：QR payload 只含 schema version、類型、雙方裝置識別與 digest，不含私鑰或聊天內容；嚴格拒絕額外欄位、竄改、錯誤參與者與 malformed JSON
- [x] **已完成**：SQLite schema 升級至 v8，新增 `safety_number_verifications`；驗證 digest 跨重啟保存，聯絡人公鑰改變時舊驗證自動失效
- [x] **已完成**：聊天室 AppBar 新增安全碼入口；Safety Number 頁支援白底黑碼高對比 QR、12 組五位數、人工確認、貼入 QR 內容比對及繁中／英文介面；深色主題 Widget 測試已鎖定 QR 對比
- [x] **已完成**：新增 `qr_flutter 4.1.0`；`mobile_scanner` 後續已升級至 7.3.0，專案最低工具鏈同步為 Flutter 3.29／Dart 3.7
- [x] **已完成**：新增可注入的 `SafetyNumberQrScanner`、QR-only 相機頁、首次成功後停止掃描、相機初始化／權限失敗 UI；Windows 等不支援平台保留人工貼入流程
- [x] **已完成**：Android manifest 加入 `CAMERA`，iOS `NSCameraUsageDescription` 納入 Safety Number；Android debug APK 建置成功，iOS plist XML 可解析
- [x] **已完成**：Safety Number 核心、service、widget、scanner adapter、schema 與 v1～v7 migration 共 15 項專項測試通過
- [x] **已完成**：Safety Number 專項測試維持通過；已納入本輪 104 項 Flutter host suite
- [ ] **已實作未驗證**：完整 `flutter test` 唯一失敗為本機缺 Visual Studio C++／libsodium native asset 的既有 `device_key_service_test.dart`；先前 Windows CI 已驗證該路徑，本次未修改裝置金鑰實作
- [ ] **已實作未驗證**：Android/iPhone 真實相機權限允許／拒絕、Safety Number QR 掃碼與錯誤畫面尚未實機驗收；iOS 尚需在 Mac 執行 build
- [ ] **已實作未驗證**：QR 產生、嚴格 payload 比對、相機／人工貼入流程已完成；兩台 Android/iPhone 實機顯示一致性與交叉核對尚未驗收
- [ ] **已實作未驗證**：`mobile_scanner 7.3.0` 與 `flutter_webrtc 1.5.2` 均具 AGP 9 conditional KGP 邏輯；Flutter 3.44.6 template 仍強制關閉 built-in Kotlin，因此相容模式下仍會套用 KGP，待 Flutter toolchain 開放完整遷移

Runtime：本輪未啟動 Docker、AVD、App、backend 或其他長時間程序；Flutter test/analyze/formatter 與 Android Gradle build 指令均已正常結束，Gradle/JVM daemon 由建置工具管理。完整 native build 限制仍是 NDK 28 libsodium automake C 編譯失敗。

下一步：沒有 credentials／實機時轉做 EPIC-10 Low Power Mode 的電腦端策略、設定與測試；Android 裝置重新連線後再驗證 App Lock notification／biometric lifecycle 與 Safety Number QR。iOS 在 Mac 驗證 Keychain／Face ID／相機及 OS 通知。

## 上次交接（2026-07-17 01:53 +08:00）

目前目標：完成專用 Firebase Test Lab cloud project、billing、WIF 與 results bucket，並在
首次可能產生費用的實體裝置 matrix 前加入預設不送測的 dry-run Gate。

- [x] **已完成**：依 Flutter 3.44 與 Firebase Test Lab 2026-06 官方文件建立 Android instrumentation runner、app/test APK build 流程與 `gcloud firebase test android run` 契約
- [x] **已完成**：新增 `build_firebase_test_lab.sh`；target 限制於 `integration_test/*_test.dart`，使用 locked dependencies，輸出 app/test APK 與 SHA-256
- [x] **已完成**：本機第一次 build 揭露 Flutter `integration_test` 對 AndroidX Test 的嚴格版本約束；改用 runner 1.3.0／rules 1.2.0／Espresso 3.3.0 後 app/test APK 封裝成功
- [x] **已完成**：test APK manifest 為 API 24～36、`AndroidJUnitRunner`、target package `com.p2pchat.p2p_chat_app`；DEX 包含 `MainActivityTest`
- [x] **已完成**：新增只允許 `main` 手動執行的 `firebase-test-lab.yml`；OIDC WIF、pinned actions/gcloud、physical model/version catalog 驗證、10 分鐘 device timeout、7 天 evidence artifact 與 fail-closed variables 已完成
- [x] **已完成**：新增 Google Cloud IAM、results bucket、GitHub variables、裝置選擇、執行與限制文件；不提交 service-account JSON key
- [x] **已完成**：133 個 Dart 檔案 formatter 零變更、`flutter analyze` 零問題；workflow YAML 結構／權限／action SHA pin、文件連結、shell syntax、非法 target exit 2 與 `git diff --check` 均通過
- [x] **已完成**：Windows 已安裝 workflow 鎖定的 Google Cloud CLI `576.0.0`，Google OAuth 登入成功
- [x] **已完成**：建立專用 project `p2p-chat-ftl-1298124041`（number `160867304686`）、綁定 billing、啟用 Firebase 與 Test Lab APIs；Firebase 狀態為 `ACTIVE`，Google Analytics 停用
- [x] **已完成**：建立 `ftl-github@p2p-chat-ftl-1298124041.iam.gserviceaccount.com`、最小必要 Test Lab roles，以及 `ASIA-EAST1` results bucket `gs://p2p-chat-ftl-1298124041-results`；bucket 禁止公開存取並套用 30 天 lifecycle
- [x] **已完成**：建立只允許 `leezxt/p2p-chat` repository ID、owner ID 與 `refs/heads/main` 的 GitHub WIF provider，且未建立 service-account JSON key
- [x] **已完成**：GitHub repository variables `GCP_PROJECT_ID`、`GCP_WORKLOAD_IDENTITY_PROVIDER`、`GCP_SERVICE_ACCOUNT` 與 `FTL_RESULTS_BUCKET` 已設定並回讀
- [x] **已完成**：workflow 已加入預設 `submit_test=false`；dry-run 會建置 APK、驗證 OIDC／實體 catalog／bucket 寫入刪除，只有明確設為 `true` 才送出可能計費的 10 分鐘 matrix
- [x] **已完成**：本輪 YAML parse、5 個 bash run blocks syntax、Markdown 本機連結與 `git diff --check` 通過；cloud 回讀確認 project/billing/WIF/bucket 與 repository variables 狀態
- [x] **已完成**：PR [#51](https://github.com/leezxt/p2p-chat/pull/51) head `209b75c` run `29514939670` 的 Java、Flutter、PostgreSQL container smoke 與 Windows Desktop 四組 V1 CI 全綠
- [x] **已完成**：PR #51 已 squash merge 為 `main` commit `38eda5d`；合併後 run `29515443738` 四組 V1 CI 全綠，本機 `main` 已 fast-forward 同步
- [x] **已完成**：`main` dry-run `29515993923` 以 `CPH2449`／Android 34／`zh_TW`／`submit_test=false` 通過；OIDC、實體 catalog、bucket 寫入刪除、APK build 與 SHA-256 均成功，付費 Test Lab submission step 明確為 `skipped`
- [x] **已完成**：dry-run artifact `firebase-test-lab-29515993923-1` 已下載稽核；含 app/test APK、catalog、build 與 bucket logs，不含 `test-lab.log`，results bucket run prefix 無殘留物件
- [ ] **已實作未驗證**：使用者確認單一 `CPH2449`／Android 34／10 分鐘 matrix 後，run `29518279373` 成功建立 `matrix-2alql4g631yuq`；裝置容量為 `Low`，matrix 持續 `PENDING` 至 GitHub 45 分鐘 job timeout，實體測試未開始
- [x] **已完成**：GitHub timeout 後以 Testing API 查明孤立 matrix 仍為 `PENDING`，已主動取消避免後續非預期費用；最終 matrix 為 `FINISHED / INCONCLUSIVE`、execution 為 `CANCELLED` 且無 `toolExecutionId`
- [x] **已完成**：產出依目前程式碼盤點的 V1 架構圖；現行 Flutter 十個模組、Spring Boot 八個服務邊界、SQLite／secure storage、PostgreSQL、P2P／mailbox fallback 與 FCM 邊界均已核對，Cloudflare Worker 明確保留為未實作 backlog
- [ ] **未完成**：首次成功的 Test Lab physical-device runtime、兩台真機 E2E、實際斷網與資源量測尚未完成；不得勾選 V1 真機 Gate
- [x] **已完成**：PR [#49](https://github.com/leezxt/p2p-chat/pull/49) 最終 head `e2b0072` run `29503017933` 的 Java、Flutter、PostgreSQL container smoke 與 Windows Desktop 四組 V1 CI 全綠
- [x] **已完成**：PR #49 已 squash merge 為 `main` commit `bdc3dd6`；合併後 run `29503705387` 四組 V1 CI 全綠，本機 `main` 已 fast-forward 同步

Runtime：本輪沒有啟動 Docker、ADB、AVD、App 或 backend。Test Lab matrix
`matrix-2alql4g631yuq` 已透過 Testing API 取消並確認 execution 為 `CANCELLED`，沒有執行中的
GitHub workflow。下載的 evidence artifacts、build 產物與 lifecycle JSON 均位於 ignored
`.tools/`／`build/`，不提交 repository。

下一步：先調整 Test Lab workflow，將 APK build 與 matrix submission 分離或提高 job 等待
上限，並在 runner 中保存 matrix ID、於 job cancellation 時取消遠端 matrix；重新送測前需
再次確認裝置容量與可能費用。單一 Test Lab 實體機仍不取代兩台真機 E2E、實際斷網、
OS kill、行動網路、記憶體與耗電 Gate。

## 上次交接（2026-07-15 22:32 +08:00）

目前目標：補上不需手機的 Windows Credential Manager 跨獨立 App process 持久化
Gate，確認第二次啟動能重載第一次啟動建立的 production 裝置金鑰。

- [x] **已完成**：codebase graph 確認現有 native integration 只在同一 process 內呼叫兩次 `DeviceKeyService.getOrCreate`，且測試結束即清除 key，未覆蓋 process restart persistence
- [x] **已完成**：新增 `SECURE_STORAGE_PHASE=write|verify`；write phase 清除專用 key、建立金鑰並保存非秘密 fingerprint marker，verify phase 由新的 App process 重載、比對並在 `finally` 清除兩筆 Credential Manager 測試資料
- [x] **已完成**：既有 full phase 的 libsodium failure paths 與 encrypted WebRTC DataChannel 維持原流程；write／verify phase 只執行 secure storage 專項，避免重複高成本 native tests
- [x] **已完成**：本機 locked dependencies、Dart formatter、`flutter analyze` 與 `git diff --check` 通過
- [x] **已完成**：PR #47 run `29422374003` 的 full integration 與兩次獨立 App process 均通過；write／verify 各為 1 passed、2 skipped，第二個 process 成功重載第一個 process 留下的同一 fingerprint
- [x] **已完成**：同一 run 的 Java、Flutter、PostgreSQL 與 Windows Desktop 四組 jobs 全綠；Windows job 亦通過 native crypto tests、Desktop build、libsodium failure paths 與 encrypted WebRTC
- [x] **已完成**：最新 PR #47 head run `29422871161` 四組 CI 全綠；Windows full integration、跨 process write／verify、native crypto 與 Desktop build 全部通過
- [x] **已完成**：PR #47 已 squash merge 為 `main` commit `3700ba6`；合併後 run `29423517867` 的 Java、Flutter、PostgreSQL 與 Windows Desktop 四組 jobs 全綠，跨 process Gate 再次通過

Runtime：本輪沒有啟動 Docker、ADB、AVD、App 或 backend；本機 Flutter analyze 程序已正常
結束。Windows native App 仍只由 GitHub-hosted runner 啟動。

下一步：Windows App process restart persistence 缺口已關閉。目前無其他可在缺手機、
credentials 與 production host 下關閉的 V1 Gate；Windows OS reboot／企業政策仍保留為
外部補充驗收。

## 上次交接（2026-07-15 21:34 +08:00）

目前目標：在 GitHub-hosted Windows runner 啟動真實 Flutter App integration test，補上
不需手機的 Credential Manager、libsodium failure paths 與 WebRTC DataChannel 驗證。

- [x] **已完成**：codebase graph 確認既有 `android_crypto_runtime_test.dart` 已使用 production `FlutterSecureKeyValueStore`，並以 `RUNTIME_PLATFORM` 支援非 Android host
- [x] **已完成**：PR #45 head run `29418892313` 在 native crypto unit tests 與 Desktop build 後，以 `-d windows` 啟動 integration test，3 組 native tests 於約 29 秒內全通過
- [x] **已完成**：測試會清除專用 Credential Manager key；文件明列 CI 不取代使用者工作站跨重啟、帳號政策或 Credential Guard 驗收
- [x] **已完成**：Windows Credential Manager 寫入／讀回／清除、libsodium 竄改／錯 key／replay failure paths 與 encrypted WebRTC DataChannel 均通過
- [x] **已完成**：PR #45 已 squash merge 為 `main` commit `9448af2`；合併後 run `29419257887` 的 Java、Flutter、PostgreSQL、Windows native integration 與 Desktop build 四個 jobs 全通過
- [x] **已完成**：重新盤點 V1；Windows/host、Docker/localhost production、Android AVD 與自動化可取代的驗證均已完成，目前沒有其他可在缺手機及外部 credentials／production host 下關閉的 Gate
- [ ] **已實作未驗證**：兩台 Android API 24+ 真機的 E2E／斷網／OS kill／資源與耗電、iPhone runtime、真實 FCM/APNs、正式 Android/iOS 簽章、公開 DNS/ACME／registry、加密 off-host backup receipt／排程／外部告警與最終 artifacts

Runtime：本輪沒有啟動 Docker、ADB、AVD、App 或 backend；本機缺 Visual Studio C++，
Windows App integration 將由 GitHub-hosted runner 執行。

下一步：取得任一缺少的外部條件後再續接對應 Gate；若先有 Android API 24+ 真機，優先
執行 V1-01/03/04。使用者工作站跨重啟／政策相容性仍屬補充驗收，不取代雙真機 Gate。

## 上次交接（2026-07-15 21:02 +08:00）

目前目標：利用 GitHub-hosted Windows runner 補上不需手機的 libsodium native runtime
測試，關閉本機因缺 Visual Studio C++ toolchain 無法執行的 Windows crypto 驗證缺口。

- [x] **已完成**：codebase graph 確認 `DeviceKeyService` 由 CryptoModule、Android runtime test 與單元測試使用；Windows 專項覆蓋金鑰產生／重載、不同裝置隔離、損壞資料拒絕與 storage failure paths
- [x] **已完成**：Windows Desktop CI job 在 locked dependency 後執行 `flutter test --no-pub test/modules/device_key_service_test.dart`；PR #43 run `29416283272` 的 5 tests 於 59 秒內全通過
- [x] **已完成**：測試矩陣與 mobile README 已明列此測試使用真實 Windows libsodium native asset、記憶體 secure store，不取代 Credential Manager 持久化驗收
- [x] **已完成**：commit `10f21e8` 已推送並建立 draft PR #43；Java／Flutter／PostgreSQL／Windows Desktop 四個 jobs 全通過，Windows build 在專項後亦成功
- [x] **已完成**：最新 PR head run `29416691705` 四項 CI 全通過；PR #43 已 squash merge 為 `main` commit `0c67c1f`
- [x] **已完成**：合併後 `main` run `29417187712` 的 Windows native crypto 5 tests、Desktop build、Java／Flutter／PostgreSQL jobs 全通過

Runtime：本輪沒有啟動 Docker、ADB、AVD、App 或 backend；本機缺 Visual Studio C++，
Windows native test 將由 GitHub-hosted runner 執行。

下一步：Windows native libsodium 測試缺口已關閉。Windows Credential Manager 與手機
secure storage 實機驗收仍保留；其餘 V1 未完成項目需要合格手機、Firebase/APNs、正式
簽章或 production 外部環境。

## 上次交接（2026-07-15 20:29 +08:00）

目前目標：完成不需手機的 Windows Desktop runner 與可重現 CI build Gate，先驗證
Flutter App 能在 Windows target 編譯，再保留 Desktop Link／多裝置同步於 V3 backlog。

- [x] **已完成**：以專案鎖定的 Flutter 3.44.6 產生標準 `windows/` runner，保留既有 iOS migration metadata，視窗與 executable metadata 使用 P2P Messenger 品牌名稱
- [x] **已完成**：Windows plugin registrant 已包含 `flutter_secure_storage_windows`、`flutter_webrtc` 與 `jni` FFI；文件列出 Visual Studio 2022 C++、CMake 與 Windows SDK 前置需求
- [x] **已完成**：V1 CI 新增 GitHub-hosted `windows-2022` debug build job，使用 locked dependencies 與既有完整 40 字元 action SHA；PR #41 run `29413886573` 已成功編譯 Windows bundle
- [x] **已完成**：本機 `flutter pub get --enforce-lockfile`、129 檔 format、`flutter analyze` 與排除 Windows native libsodium 單檔後的 90 項 host tests 全通過
- [ ] **已實作未驗證**：本機完整 `flutter test` 與 Windows build 缺 Visual Studio Desktop development with C++／`vswhere`，無法載入 sodium native asset；改由 GitHub Windows runner 驗證
- [x] **已完成**：commit `64263cf` 已推送並建立 draft PR #41；head run `29413886573` 的 Java／Flutter／PostgreSQL／Windows Desktop 四個 CI jobs 全通過
- [x] **已完成**：最新 PR head run `29414355119` 四項 CI 全通過；PR #41 已 squash merge 為 `main` commit `220b2fc`
- [x] **已完成**：合併後 `main` run `29414746310` 的 Java／Flutter／PostgreSQL／Windows Desktop 四個 jobs 全通過

Runtime：本輪沒有啟動 Docker、ADB、AVD、App 或 backend；Flutter 驗證程序均已結束，
沒有殘留常駐程序。

下一步：Windows Desktop runner 與 CI Gate 已關閉。重新盤點仍可在無手機、無 Firebase／
APNs credentials、無正式簽章與無公開 production host 條件下完成的 V1 項目。

## 上次交接（2026-07-15 19:49 +08:00）

目前目標：完成不需手機的 V1 CI 維護，移除 GitHub-hosted runner 對 Node.js 20 action
runtime 的 deprecation annotation，同時維持 supply-chain SHA pin 與既有 Gate。

- [x] **已完成**：以 GitHub API 查證 `actions/checkout` 最新正式版為 `v7.0.0`、verified commit `9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0`，action metadata 使用 `node24`
- [x] **已完成**：以 GitHub API 查證 `actions/setup-java` 最新正式版為 `v5.5.0`、verified commit `0f481fcb613427c0f801b606911222b5b6f3083a`，action metadata 使用 `node24`
- [x] **已完成**：V1 CI 三個 checkout steps 與一個 setup-java step 已更新至上述完整 commit SHA；`contents: read`、Ubuntu 24.04、timeouts、Java/Maven cache 與 Flutter pin 均未改動
- [x] **已完成**：本機確認所有 5 個外部 actions 都使用完整 40 字元 SHA、舊 SHA 已移除，`git diff --check` 通過；本機沒有 `actionlint`，YAML/runtime 由 PR CI 驗證
- [x] **已完成**：PR #39 最終 head run `29412613173` 全通過並合併為 `main` commit `62956ce`；Java 46 秒、PostgreSQL 1 分 35 秒、Flutter 2 分 18 秒，三個 check-runs annotations 都是 `0`
- [x] **已完成**：合併後 `main` run `29412813706` 全通過；Java 55 秒、PostgreSQL 1 分 53 秒、Flutter 1 分 57 秒，三個 check-runs annotations 仍全部為 `0`

Runtime：本輪沒有啟動 Docker、ADB、AVD、App 或 backend；只讀取 GitHub 官方 release、
tag、action metadata 與 verified commit 資訊。

下一步：Node.js 24 CI 維護已關閉。重新盤點 V1 未完成項目，只接續不依賴 Android／
iPhone 真機、Firebase/APNs credentials、正式簽章資料或公開 production host 的工作。

## 上次交接（2026-07-15 19:27 +08:00）

目前目標：使用目前唯一連接的 Android 真機執行 V1 native 與資源驗收，並確認裝置
是否符合最低執行版本。

- [x] **已完成**：Windows ADB 已辨識並授權 OPPO X9079（serial `4ef95b58`）；裝置為 Android 5.1.1、API 22、`arm64-v8a`，開機狀態正常
- [x] **已完成**：確認手機未安裝 `com.p2pchat.p2p_chat_app`，本輪未覆蓋或清除既有 Messenger App 資料
- [ ] **已實作未驗證**：`android_crypto_runtime_test.dart` 在啟動 App 前被 Flutter 拒絕，明確錯誤為目標 API 22 過舊、需要 API 24 以上；secure storage、libsodium failure paths 與同機 WebRTC 均未在此真機執行
- [ ] **已實作未驗證**：profile APK 冷啟動、PSS、背景 TCP／網路與手動耗電量測同樣受最低 API 24 限制，未安裝或清除 App 資料
- [ ] **未完成**：此 API 22 真機不能作為真機＋模擬器 runner 的其中一端，也不能關閉 V1-01/03/04；需 Android 7.0（API 24）以上真機

Runtime：本輪只啟動 ADB server 進行授權與裝置查詢；沒有啟動 Docker、AVD、App 或
backend。ADB server 已在交接更新後正常停止。

下一步：連接 Android 7.0（API 24）以上真機，先跑
`integration_test/android_crypto_runtime_test.dart`，再執行 profile 資源量測；若只有一台
合格真機，可搭配一台 AVD 跑 encrypted P2P 與 mailbox recovery，但不能取代雙真機 Gate。

## 上次交接（2026-07-15 19:07 +08:00）

目前目標：完成 V1-06 多語言介面與語言切換、V1 發布 Gate、GitHub PR 與合併後
`main` 驗證。最終功能已合併至 `main` commit `252972c`。

- [x] **已完成**：加入 `flutter_localizations`、gen-l10n、`l10n.yaml` 與繁中／英文 ARB；`MaterialApp` 已設定 delegates、supported locales、localized title 與 locale resolution
- [x] **已完成**：新增 `LocaleController` 與 SQLite v7 `app_settings`；預設跟隨系統，App 內可選繁中／英文並跨重啟保存，unsupported locale fallback 至 `zh_TW`
- [x] **已完成**：聊天列表、聊天頁、邀請／同步錯誤、日期時間、訊息狀態、Presence、tooltips 與新聊天室預設名稱已 localization；`lib/` UI 字串稽核未發現剩餘可見硬編碼文字
- [x] **已完成**：7 項 localization 專項通過；`flutter gen-l10n`、129 檔 format、`flutter analyze` 及排除 Windows native libsodium 單檔後的 90 項 host tests 全通過
- [x] **已完成**：SQLite migration matrix 與既有 schema tests 改用 `kCurrentDbVersion`，v1～v5 升級至 v7、`app_settings` 建立及語言偏好重啟保存均通過
- [x] **已完成**：PR #36 最終 head run `29410208438` 全通過並合併；Java 21 tests 37 秒、Flutter 3.44.6 完整 checks 1 分 55 秒、PostgreSQL container smoke 1 分 45 秒
- [x] **已完成**：合併後 `main` run `29410344607` 全通過；Java 21 tests 54 秒、Flutter 3.44.6 完整 checks 2 分 19 秒、PostgreSQL container smoke 1 分 41 秒
- [ ] **已實作未驗證**：Windows `device_key_service_test.dart` 仍缺 Visual Studio Desktop development with C++，無法載入 sodium native asset；不影響本次純 Dart／SQLite／widget 變更，Android 真實 libsodium 沿用既有雙 AVD 驗收
- [x] **已完成**：GitHub Actions Node.js 20 deprecation 已清除；`checkout v7` 原已使用 Node 24，Test Lab 的 `upload-artifact` 已升級至 pinned `v7.0.1`，run `29641323307` annotations 為空且 artifact 成功 finalized
- [ ] **未完成**：兩台 Android 真機 V1-01/03/04、真實 FCM/APNs、iPhone runtime、正式簽章、公開 production 與最終 release artifacts

Runtime：本輪沒有啟動 Docker、ADB、AVD、App 或常駐 backend；Flutter 測試程序均已正常結束。

下一步：V1-06 已關閉。後續優先處理 GitHub Actions Node.js 24 相容 revision；有兩台
Android 真機時接續 V1-01/03/04，取得 credentials／production host 後完成 Push、iOS、
正式簽章、公開 deployment、off-host backup/receipt/排程、告警與最終 artifacts。

## 上次交接（2026-07-15 07:19 +08:00）

目前目標：修正 backup retention 合併後 `main` CI 揭露的 signaling WebSocket 並行
寫入 race，恢復 Java Gate 的可重現穩定性。

- [x] **已完成**：PR #32 已合併為 `main` commit `dd6b0f2`；PR head run `29375069377` 的 Java、Flutter 與 PostgreSQL container smoke 三 jobs 全通過
- [x] **已完成**：`main` run `29375175296` 的 retention fixture、Flutter 與 PostgreSQL container smoke 通過；Java job 揭露 `TEXT_PARTIAL_WRITING` / `Output closed`
- [x] **已完成**：根因為 authentication、relay 與 error path 可對同一 `WebSocketSession` 並行 `sendMessage`，Tomcat 不允許 concurrent partial write
- [x] **已完成**：三條輸出路徑收斂至同一 session lock，確保 handler 對每個 session 序列化送出 frame
- [x] **已完成**：新增受控並行回歸測試；第一筆 write 阻塞時第二筆不得進入底層 WebSocket send
- [x] **已完成**：專項測試與完整 Maven suite 52 tests 全通過，0 failures/errors/skipped；`git diff --check` 通過
- [x] **已完成**：PR #33 run `29375556941` 三 jobs 全通過，已合併為 `main` commit `8f20e81`
- [x] **已完成**：`main` run `29375675896` 的 Java 52 tests、Flutter 3.44.6 checks、retention fixture 與 PostgreSQL container smoke 全通過，原 race 未再出現
- [ ] **未完成**：兩台 Android 真機 V1-01/03/04、真實 FCM/APNs、iPhone runtime、正式簽章、公開 production 與最終 release artifacts

Runtime：本輪只執行本機 Maven tests，測試用 Spring/Tomcat process 已隨 suite 正常結束；
沒有啟動 Docker、ADB、AVD、App 或常駐 backend runtime。

下一步：目前沒有可取代外部 Gate 的本機模擬項目；有兩台 Android 真機時接續
V1-01/03/04，取得 credentials/production host 後完成 Push、iOS、簽章、公開 deployment、
off-host backup/receipt/排程、告警與最終 artifacts。

## 上次交接（2026-07-15 07:01 +08:00）

目前目標：完成 production backup 的本機 staging retention 安全邊界，避免未上傳、
未驗證或仍在最低保留數內的 backup 被自動刪除。

- [x] **已完成**：新增 `prune-production-backups.ps1`；預設只 dry-run，Apply 必須同時提供 `-Apply` 與精確確認字串 `DELETE-VERIFIED-LOCAL-BACKUPS`
- [x] **已完成**：候選檔必須通過 dump/manifest schema、filename、size、SHA-256、custom-format 與有效 off-host receipt 驗證，receipt hash 必須與 dump 相符
- [x] **已完成**：超過 `MaxAgeDays` 且不在最新 `MinimumBackups` 內才可刪除；缺 receipt、corrupt/orphan、reparse point 與格式錯誤一律 protected
- [x] **已完成**：Apply 前重新檢查檔案、reparse point、manifest/receipt/hash，避免掃描後置換；重跑維持冪等
- [x] **已完成**：新增 Windows/Ubuntu 共用 fixture；dry-run candidates 2、deleted 2、protected remaining 4、錯誤確認拒絕與 idempotent 均通過
- [x] **已完成**：PR #32 head GitHub run `29374714176` 的 Java 21、Flutter 3.44.6 與 PostgreSQL container smoke 三 jobs 全通過
- [x] **已完成**：同步 backend README、testing、安全稽核、RC、V1 task、成本與交接文件
- [x] **已完成**：本機 PowerShell parser、retention fixture、`git diff --check`、五份變更 Markdown 本機連結與新增行 secret scan 通過；codebase change detection 為 10 個預期檔案、0 impacted symbols
- [ ] **已實作未驗證**：正式加密 off-host object storage、由 upload/verify 系統簽發 receipt、production 排程、外部告警、實際 retention policy 與災難復原演練
- [ ] **未完成**：兩台 Android 真機 V1-01/03/04、真實 FCM/APNs、iPhone runtime、正式簽章、公開 DNS/ACME、registry digest 與最終 release artifacts

Runtime：本輪功能與 retention fixture 已在 GitHub-hosted Ubuntu runner 完成；Windows
本機沒有啟動 Docker、ADB、AVD、App 或 backend runtime。

下一步：有兩台 Android 真機時接續 V1-01/03/04；取得 credentials/production host 後
完成真實 Push、iOS、正式簽章、公開 deployment、off-host backup/receipt/排程與告警 Gate。

## 上次交接（2026-07-15 06:22 +08:00）

目前目標：將 Dockerfile、PostgreSQL、Flyway 與 container health 納入每個 PR/main push
的 V1 CI，並修正原 smoke runner 的環境依賴、隔離及 test volume 清理問題。

- [x] **已完成**：`smoke.ps1` 改用 process-only 隨機 credentials、獨立 Compose project 與自動可用 host ports，不讀取或覆寫 production secrets
- [x] **已完成**：`up` 失敗、timeout 與驗證失敗都走 finally cleanup；移除 containers/networks/test volume 並恢復原 process environment
- [x] **已完成**：smoke Gate 擴充為 readiness `UP`、backend user `app`、Flyway 1～9 與 10 public tables
- [x] **已完成**：失敗時只輸出最後 200 行 bounded logs，再執行 cleanup 並保留非零結果
- [x] **已完成**：V1 CI 新增 `PostgreSQL container smoke` Ubuntu job，外部 Action仍使用完整 commit SHA 與 `contents: read`
- [x] **已完成**：GitHub run `29372616520` 三 jobs 全通過；container log 為 `PASS`/`app`/Flyway 1～9/10 tables
- [x] **已完成**：GitHub log 確認 backend/postgres containers、test volume 與 network 均 Removed
- [x] **已完成**：同步 backend README、testing、RC、V1 task 與交接文件
- [ ] **未完成**：公開 production topology、Android/iOS native integration、兩台 Android 真機、真實 Push 與正式簽章 Gate 不由此 smoke 取代

Runtime：本輪只使用 GitHub-hosted Ubuntu runner；runner job 已完成且 log 證明 Compose
resources 清理。Windows 本機沒有啟動 Docker、ADB、AVD、App 或 backend runtime。

下一步：有兩台 Android 真機時接續 V1-01/03/04；取得 credentials/production host 後
完成真實 Push、iOS、正式簽章與公開 deployment Gate。

## 上次交接（2026-07-15 02:30 +08:00）

目前目標：補上 repository 缺少的 V1 continuous integration Gate，讓每個 PR 與 main
push 自動驗證 Java backend 與 Flutter host tests；native/真機測試仍維持獨立 Gate。

- [x] **已完成**：確認 Android SDK 存在但沒有連接裝置，V1-01/03/04 本輪不可冒充真機驗收
- [x] **已完成**：新增 `.github/workflows/v1-ci.yml`，PR、main push 與手動觸發均執行
- [x] **已完成**：Java 21 與 Flutter 3.44.6 分離 jobs，設定 timeout、concurrency cancellation 與 `contents: read` 最小權限
- [x] **已完成**：checkout/setup-java/flutter-action 全部 pin 40-char commit SHA；Flutter dependency 使用 lockfile fail-closed
- [x] **已完成**：GitHub runs `29357810257`、`29358109443` 均通過；最新 head Java tests 41 秒、Flutter locked dependency/format/analyze/unit/widget tests 117 秒
- [x] **已完成**：同步 testing、V1 task、RC 與交接文件；CI 明確不取代 Docker/native/真機 Gate
- [ ] **未完成**：V1-01/03/04 仍需兩台 Android 真機；真實 Push、iOS、正式簽章與公開 production Gate 亦未完成

Runtime：沒有 App/backend/Docker/AVD 執行；本輪檢查 Android 裝置時曾啟動 ADB
server，但 `adb devices -l` 為空。ADB server 已停止，port 5037 無 listener。

下一步：有兩台 Android 真機時接續 V1-01/03/04；取得 credentials/production host 後
完成真實 Push、iOS、正式簽章與公開 deployment Gate。

## 上次交接（2026-07-15 01:22 +08:00）

目前目標：建立 production 有界 log retention 與可供排程/告警使用的外部 one-shot
HTTPS/WSS monitor；公開 DNS 與告警服務尚未提供，因此只做 localhost topology 驗證。

- [x] **已完成**：三個 production services 共用 Docker `json-file` rotation，預設 `10m` × 5，避免 host log 無上限成長
- [x] **已完成**：preflight 驗證所有服務的 rendered logging policy，並限制 `LOG_MAX_SIZE` 格式與 `LOG_MAX_FILES` 2～20
- [x] **已完成**：新增 `monitor-production.ps1`，驗證 HTTP redirect、HTTPS readiness、HSTS/`nosniff`/移除 `Server` 與 WSS 101
- [x] **已完成**：monitor 成功輸出 `PASS`/exit 0；失敗輸出不含 secret 的 JSON `FAIL`/非零 exit code，可接排程與外部告警
- [x] **已完成**：localhost TLS topology 正向四項 checks 通過；未啟動 endpoint 與 production mode 使用 localhost 的負向案例通過
- [x] **已完成**：三個實際 containers 經 `docker inspect` 均為 `json-file|10m|5`；非法 `0m`/1 file preflight 正確拒絕
- [x] **已完成**：同步 backend README、testing、RC、安全稽核、成本、任務與交接文件
- [ ] **已實作未驗證**：公開 endpoint、正常 ACME certificate、外部 probe host、排程頻率、告警接收/升級與長期 log rotation 仍待 production 驗收

Runtime：localhost production topology 已以 `down --volumes --remove-orphans` 清除全部
containers、networks、PostgreSQL/Caddy test volumes；兩份 ignored test env 亦已刪除。
Docker Desktop 已正常停止，未保留本輪 runtime 資料。

下一步：同步 GitHub。取得公開 DNS/registry 後，從 deployment host 外部定期執行
monitor 並接告警；Android 真機仍接續 V1-01/03/04。

## 上次交接（2026-07-15 01:08 +08:00）

目前目標：建立 production PostgreSQL 可驗證備份／還原流程；所有測試只在隔離 DB
執行，不覆寫 configured production source database。

- [x] **已完成**：新增 `backup-production.ps1`，在 healthy PostgreSQL container 內使用 `pg_dump -Fc`、compression 9、排除 owner/privileges
- [x] **已完成**：dump 建立後先以 `pg_restore --list` 驗證，再複製到 host 並產生 SHA-256/來源 commit/PostgreSQL version manifest
- [x] **已完成**：backup manifest 敏感 marker 檢查通過；manifest 不含 DB password/JWT/push key，dump 明確標為需加密限制存取的敏感資料
- [x] **已完成**：新增 `restore-production.ps1`；restore 前驗證 manifest/hash/custom format，預設只允許 `-CreateTargetDatabase` 建立新 DB
- [x] **已完成**：既有 target 必須 `-ReplaceExistingTarget` 加區分大小寫 `REPLACE:<database>`；configured source DB 另需 `-AllowSourceDatabaseReplacement`
- [x] **已完成**：修正不存在 target 的空 `psql` 輸出造成 `$null.Trim()`；回歸後正確回明確 create gate
- [x] **已完成**：隔離 backup `8e69728c3698f5e8d48caba796b701b22211e80d095647b90334290af1c095a4` 建立並還原至 `p2p_chat_restore_verify`
- [x] **已完成**：restore 通過 Flyway 1～9、10 public tables、`backup_restore_probe=verified` 與 source/target `app_metadata` 2 rows 一致
- [x] **已完成**：新 DB restore、既有 test DB 精確確認 replacement、source DB 防護、缺少 create switch 與竄改 hash 負向案例均通過
- [x] **已完成**：同步 backend README、testing、RC、安全稽核、成本、任務與交接文件
- [ ] **已實作未驗證**：production 排程、加密 off-host storage、retention、最小權限、真實災難復原與定期 restore drill 尚未驗證

Runtime：Compose test containers、networks、PostgreSQL/Caddy volumes 已以
`down --volumes --remove-orphans` 清除；忽略目錄中的 test env 與本輪 dump/manifest 亦已
刪除。Docker Desktop 已正常停止，且未殘留 `Docker Desktop` 或
`com.docker.backend` process。

下一步：同步 GitHub。正式部署後將 dump 移到加密 off-host storage，設定
retention/排程，並在獨立 restore host 定期重跑相同 schema/data 驗收；Android 真機
仍接續 V1-01/03/04。

## 上次交接（2026-07-14 23:28 +08:00）

目前目標：建立 fail-closed 的 production HTTPS/WSS deployment topology，在沒有公開
DNS/registry/secrets 時先以 localhost 驗證 proxy、backend 與 PostgreSQL 邊界。

- [x] **已完成**：新增 `compose.production.yml`，只公開 Caddy 80/443 TCP 與 443 UDP；backend 僅 expose 8080，PostgreSQL 無 host port 且 data network internal
- [x] **已完成**：新增 Caddy TLS/WSS reverse proxy，啟用 HSTS、`nosniff`、no-referrer、移除 `Server` header，並關閉 admin API
- [x] **已完成**：backend production container 使用 `prod` profile、read-only rootfs、tmpfs、drop all capabilities、no-new-privileges 與 image 內 non-root `app`
- [x] **已完成**：新增 `production.env.example` 與 `preflight-production.ps1`；拒絕 placeholder、短密碼、無效 key、HTTP/wildcard origins、未 pin image digest 與公開 DB/backend port
- [x] **已完成**：preflight 解析 rendered Compose JSON；確認 backend/PostgreSQL 不 publish host port、data network internal、proxy ports 與 `prod` profile
- [x] **已完成**：正式模式未 pin digest 的三個 images fail-closed；`-AllowLocalVerification` 只接受 localhost 並可覆寫測試 ports
- [x] **已完成**：production-mode 正常 preflight 以公開 hostname、80/443 與三個 sha256 registry references 通過 rendered Compose JSON 驗證；不需啟動 runtime
- [x] **已完成**：本機 production topology 通過 TLS readiness `UP`、HSTS、Server header removed、HTTP 308、prod API docs 404 與 WebSocket `101 Switching Protocols`
- [x] **已完成**：exact backend candidate + PostgreSQL 18.4 通過 Flyway 1～9，proxy/backend/postgres 三服務運行正常
- [x] **已完成**：同步 backend README、testing、RC、安全稽核、成本、任務與交接文件
- [ ] **已實作未驗證**：公開 DNS/ACME certificate、registry-pinned images、firewall、volume backup/restore、log retention、monitoring/alerting 與真實 HTTPS/WSS endpoint

本機 port 80 由 Windows HTTP.sys 使用，因此 localhost 驗證明確以
`HTTP_PORT=18080`/`HTTPS_PORT=18443` 執行；production preflight 未使用 local switch 時
仍強制公開 80/443。WebSocket probe 成功回 101 後會保持長連線，首次未設 timeout 的
probe 已終止並以三秒 timeout 重跑通過，服務本身未中斷。

Runtime：proxy、backend、postgres 均曾 running，backend/postgres healthy；交接先行記錄
後，Compose test containers、networks、PostgreSQL/Caddy volumes 已移除，本輪啟動的
Docker Desktop 已正常停止。兩個一次性 local/negative env 亦已從忽略目錄刪除。

下一步：同步 GitHub。取得正式網域與 registry 後，填寫 `production.env`、執行
preflight、驗證公開 ACME/HTTPS/WSS、備份還原與監控告警；
Android 真機仍接續 V1-01/03/04。

## 上次交接（2026-07-14 21:00 +08:00）

目前目標：建立 backend V1 candidate JAR/Docker image 追溯資訊，並以 exact image 在
PostgreSQL 18.4 + production profile 驗證 readiness、migration 與安全 surface。

- [x] **已完成**：新增 `java_backend/scripts/build-candidate.ps1`，預設要求乾淨 working tree、執行 Maven tests、建立 executable JAR 與 Docker image
- [x] **已完成**：以 XML parser 讀取 Maven version，輸出來源 commit/dirty、JAR SHA-256、local image ID/size/RepoDigests 與 OCI version/revision labels
- [x] **已完成**：registry digest 維持 `null` 且 `registryDigestRequiredForRelease=true`；不把 Docker Desktop 的 local RepoDigests 誤報為已發布 registry digest
- [x] **已完成**：未使用 `-AllowDirtyWorkingTree` 時，dirty source 在 Maven/Docker build 前 fail-closed
- [x] **已完成**：manifest 敏感 marker 與 JAR checksum 驗證通過，不讀取或輸出 DB/JWT/push/Firebase secret
- [x] **已完成**：完整 Maven suite 51 tests、0 failures/errors/skipped；候選 JAR 73,639,243 bytes，SHA-256 `6712d8c22f34d90b2d786b604ab96c8af5061d6e17a12b9ee62d579cf735289e`
- [x] **已完成**：exact image `sha256:e3a5b062eb815bdddd172bd97f4f28494ac3bcd62427462766814d05a9c1a74b`（140,961,725 bytes）以 production profile 啟動，readiness `UP`
- [x] **已完成**：PostgreSQL 18.4 Flyway 1～9 success、production `/v3/api-docs` 404、container user `app`
- [x] **已完成**：同步 backend README、`testing.md` 與 `release_candidate_v1.md`；明列 local image ID/RepoDigests 不取代 registry digest
- [ ] **已實作未驗證**：正式 registry push/digest、production HTTPS/WSS endpoint、監控/備份與真實 FCM credentials 尚未驗證

BuildKit attestation 使相同 app layers 的重建 local image ID 改變；因此本輪在 manifest 修正
後，另以 exact `e3a5…a74b` image 重啟第二個 backend 並重新完成所有 runtime checks，
沒有沿用先前 `c9a4…cae58` 容器結果。

Runtime：隔離 network `p2p_candidate_verify` 上的 PostgreSQL、舊 image backend 與 exact
manifest image backend 均曾為 healthy；交接先行記錄後，三個容器與 network 已移除，
本輪啟動的 Docker Desktop 已正常停止。不刪除 candidate image 或被 Git 忽略的
JAR/manifest。

下一步：同步 GitHub。取得 production registry 後推送 exact candidate image 並記錄
registry-verified digest；取得 HTTPS/WSS deployment 與 Firebase credentials 後，
再執行最後 production smoke。Android 真機仍接續 V1-01/03/04。

## 上次交接（2026-07-14 20:13 +08:00）

目前目標：建立可重現且不洩漏簽章憑證的 Android V1 候選版 artifact 流程；正式
application ID/keystore 尚未提供時，只能輸出明確標示的內部 profile 產物。

- [x] **已完成**：新增 `build_android_candidate.ps1`，支援 ARM64/x64 profile APK 與正式 release AAB，讀取 Gradle structured metadata 而非手動解析版本文字
- [x] **已完成**：輸出 artifact 與 JSON manifest，記錄 application ID、version、Git commit/dirty 狀態、Flutter/Dart 版本、大小與 SHA-256
- [x] **已完成**：release 模式拒絕 dirty working tree、預設 application ID 與缺少 `android/key.properties`；manifest 不讀取或輸出 keystore 欄位
- [x] **已完成**：Windows build 期間自動加入既有 Git Bash/GNU make 路徑並於結束後恢復，不修改系統 PATH
- [x] **已完成**：ARM64 profile 首次 native build 122.7 秒通過，APK 67,077,814 bytes，SHA-256 `3245fce5d1143d293be9f9157426b99c96ab3a32c372162597a17ac4fdc664f2`
- [x] **已完成**：manifest schema/hash、`INTERNAL_PROFILE`、dirty source 與敏感 marker 驗證通過；release dirty-tree 負向驗證通過
- [x] **已完成**：乾淨工作樹的 release 負向驗證通過；缺少正式 `-ApplicationId` 或缺少 `android/key.properties` 均在建置前明確拒絕
- [ ] **已實作未驗證**：正式 release AAB、distribution signature 與 `RELEASE_CANDIDATE` manifest 需正式 application ID/keystore；雙真機、Push/iOS 與 V1-01/03/04 Gate 仍待完成
- [x] **已完成**：同步 `release_candidate_v1.md`、`testing.md` 與 mobile README 的 artifact 操作方式

首次 ARM64 執行因 process PATH 找不到 Git Bash 而失敗；腳本沿用既有 Android runner
方式暫時加入 `C:\Program Files\Git\bin` 與 GNU make 路徑後，完整重跑成功。此失敗不
是 App/crypto 編譯錯誤，且沒有使用 `NIX_SKIP_SODIUM_BUILD_HOOKS` 跳過 native build。

Runtime：本輪未啟動 backend、Docker 或 AVD。Flutter/Gradle build 已結束；候選版 APK
與 manifest 位於被 Git 忽略的 `mobile_desktop_app/build/v1-release-candidate/`。

下一步：同步 GitHub。取得兩台 Android 真機後，以本次 ARM64 profile APK 接續
V1-01/03/04；取得正式 ID/keystore 後才執行 release AAB 與 distribution signature
驗證。

## 上次交接（2026-07-14 19:58 +08:00）

目前目標：建立 V1-05 release candidate 文件與可執行發布 Gate；在 V1-01/03/04、
正式簽章、真實 Push 與 iOS 實機完成前，維持內部測試版狀態。

- [x] **已完成**：核對 V1-05、現有 README/架構/安全/成本文件、App version、Android application ID 與 signing 設定
- [x] **已完成**：新增 `release_candidate_v1.md`，彙整已通過範圍、Android/iOS 建置、基本操作、三個 Android runner、發布 Gate、已知限制與 artifact 紀錄格式
- [x] **已完成**：同步 root/mobile README、架構入口與 V1 實際 backend/FCM/APNs/TURN 成本現況
- [x] **已完成**：Android release signing 改讀取被 Git 忽略的 `key.properties`，並支援 Gradle property/環境變數 `P2P_APPLICATION_ID`；缺少設定或仍用預設 ID 時 fail-closed，不再 fallback 至 debug key
- [x] **已完成**：新增 `android/key.properties.example`；Gradle task 載入、缺少 keystore 的 release 負向驗證及 profile x86_64 APK 64.0MB 建置通過
- [ ] **已實作未驗證**：V1-05 文件與 Android 簽章骨架已完成；V1-01/03/04 雙真機與故障/資源 Gate、正式 ID/keystore、iOS distribution signing、真實 FCM/APNs、production smoke test 與最終 artifact hash 尚未完成
- [x] **已完成**：文件中的本機相對連結、runner 檔案、PowerShell command 字面值與 `git diff --check` 驗證通過

重要阻塞：`pubspec.yaml` 目前為 `0.1.0+1`，尚未決定正式 Android application ID，
也未提供 upload keystore。Gradle 現在會阻擋缺少這些設定的 release build；未完成正式
命名、版本與簽章憑證前，不可將任何 APK 標示為可上架 RC。

Runtime：本輪只修改文件，未啟動或停止 backend、Docker、AVD 或其他長時間程序；
`adb devices` 沿用前次狀態，無連接裝置。

下一步：接上兩台 USB Android 真機，依 `release_candidate_v1.md` 先後執行
`verify_android_v1.ps1`、`verify_android_mailbox_recovery.ps1` 與
`measure_android_resources.ps1`，再人工驗證 Wi-Fi/行動網路切換、OS kill 與長時間
耗電。完成 V1-01/03/04 後，再設定正式 application/Bundle ID 與 distribution signing。

## 上次交接（2026-07-14 19:54 +08:00）

目前目標：建立 V1-03 Android 資源量測入口，先以 Android 15 AVD/profile APK 建立可重現基線，不以 Emulator 取代真機 release 與電量驗收。

- [x] **已完成**：確認規格 §21 門檻為冷啟動 3 秒、閒置記憶體 150MB、背景 P2P 0、前景 heartbeat 60 秒
- [x] **已完成**：新增 `measure_android_resources.ps1`，量測五次 process-cold launch、前景/背景 PSS、App UID established TCP 與背景 netstats，輸出 JSON/Markdown
- [x] **已完成**：profile x86_64 APK 建置通過；App lifecycle、Presence 與 P2P sleep 相關 13 tests 通過；PowerShell parser 通過
- [x] **已完成**：Android 15 AVD 兩次自動基線通過；冷啟動中位數 2646/2690ms、閒置 PSS 110.22/111.54MB、背景 TCP 0，第二次背景網路增量 0 bytes
- [x] **已完成**：新增 `resource_measurement_v1.md`，記錄方法、完整樣本、最大啟動 3275/3067ms 與 release 驗收限制
- [ ] **已實作未驗證**：兩台 Android 真機的 profile/release 冷啟動、低記憶體裝置、Wi-Fi/行動網路、長時間耗電與背景行為
- [x] **已完成**：資源量測 commit `af74009` 經 PR #22 合併至 `main`，merge commit `5ad67d7`

驗證：兩次 `measure_android_resources.ps1 -Device emulator-5554 -ClearAppData` 均 exit 0；第二次報告為 cold median 2690ms、maximum 3067ms、foreground PSS 111.54MB、background PSS 117.21MB、background TCP 0、network delta 0 bytes。自動 gate 使用五次中位數；最大值超過 3 秒已明確保留，不能宣稱所有冷啟動均達標。Emulator battery 結果不具意義，未量測。

Runtime：`emulator-5554` 已在本段先行記錄後乾淨關閉，`adb devices` 無殘留裝置。續接命令與完整限制見 `docs/resource_measurement_v1.md`。

下一步：接上兩台 USB Android 真機重跑 encrypted P2P、mailbox recovery 與 resource runner，再執行實際斷網、OS kill 與長時間電量量測；完成後更新 V1-01/V1-03/V1-04，最後整理 V1-05 release candidate。

## 上次交接（2026-07-14 19:18 +08:00）

目前目標：以兩台 Android AVD 驗證真實 offline mailbox、DELIVERED/READ 狀態與 App process force-stop 後的 SQLite/ACK 復原；模擬器結果不取代兩台真機的斷網、OS kill 與資源驗收。

- [x] **已完成**：確認 production `MailboxSyncService`、`HttpMailboxUploader`、`SqliteReplayProtection`、receipt 與 sender status 資料流及既有測試缺口
- [x] **已完成**：新增五階段 `android_mailbox_restart_e2e_test.dart`，涵蓋 registration、密文 upload、ACK 遺失、跨 process restart、DELIVERED/READ 與 sender 本機狀態
- [x] **已完成**：新增 `verify_android_mailbox_recovery.ps1`，協調 H2 backend、雙裝置、contact ACL、`am force-stop`、ADB server recovery、重啟驗證與 runtime 清理
- [x] **已完成**：`flutter analyze` 零問題；既有 mailbox restart/sync 3 tests 全通過；PowerShell parser 通過
- [x] **已完成**：雙 AVD runner 192.7 秒通過；真實 sodium mailbox、SQLite message/replay/receipt、ACK 遺失、force-stop、重投冪等、DELIVERED/READ 與 sender READ 狀態形成閉環
- [x] **已完成**：修正 test-profile H2 無法執行 PostgreSQL `ON CONFLICT` 的 rate-limit store；PostgreSQL 原子路徑不變，H2 fallback 通過 rate-limit concurrency 與 mailbox API tests
- [ ] **未完成**：兩台 Android 真機的實際斷網、OS kill、USB `adb reverse` 與耗電/記憶體驗收
- [x] **已完成**：功能 commit `e6550b0` 經 PR #20 合併至 `main`，merge commit `efaee49`；UML 與交接文件以獨立 docs commit 同步，不混入功能 commit

驗證：`flutter analyze` 零問題；mailbox restart/sync 3 tests 通過；完整 Java suite 51 tests、0 failures/errors/skipped；PowerShell parser 與 `git diff --check` 通過。雙 AVD runner 最終 192.7 秒通過；前兩次失敗分別揭露 H2 `ON CONFLICT` 與 abrupt kill 後 ADB child cleanup，第三個測試缺口是正常結束的 Flutter phase 會清 App data，均已修正並由最終並行 sender 流程驗證。

Runtime：runner backend 已停止，port 8081 已釋放；`emulator-5554`、`emulator-5556` 已在本段先行記錄後乾淨關閉，`adb devices` 無殘留裝置。續接命令：`powershell -ExecutionPolicy Bypass -File mobile_desktop_app/tool/verify_android_mailbox_recovery.ps1 -SenderDevice emulator-5554 -ReceiverDevice emulator-5556`。

下一步：接上兩台 USB Android 真機執行 encrypted P2P 與 mailbox recovery 兩個 runner，再補實際斷網、OS kill、耗電與記憶體量測；完成後才可勾選 V1-01/V1-03/V1-04，最後整理 V1-05 release candidate 文件。

## 上次交接（2026-07-14 01:34 +08:00）

目前目標：將《P2P Modular Messenger Codex 開發總規格 v1.2》整理為可維護的 UML 文件。

- [x] **已完成**：解析裝置角色、Core/Modules、P2P 與 Offline Mailbox 資料流、模組生命週期及訊息狀態
- [x] **已完成**：新增 `docs/uml.md`，包含部署圖、元件圖、訊息循序圖、模組生命週期與訊息狀態圖
- [x] **已完成**：在 `docs/architecture.md` 加入 UML 文件入口
- [x] **已完成**：Mermaid CLI 實際渲染 5 張圖，全部成功；`git diff --check` 通過

本輪只變更文件，未修改 App、backend、資料庫或 runtime。未啟動或停止 Docker、AVD、backend 或其他長時間程序。下一步可直接依 `docs/uml.md` 維護架構，或在文件發布流程中將 Mermaid 匯出為 SVG / PNG。

## 上次交接（2026-07-14 01:27 +08:00）

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

- [x] 安裝並記錄 Flutter `>=3.29.0`、Dart `>=3.7.0` 的實際版本；CI 使用 Flutter 3.44.6／Dart 3.12.2
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
- [ ] **已實作未驗證**：更新 README、架構、安全、成本、操作說明與已知限制；V1-05 RC 文件、Android/backend artifact manifest 流程已同步，真機 Gate、正式憑證與 registry、真實 Push/iOS 與最終 artifact 待完成
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
