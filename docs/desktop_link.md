# Desktop Link／Device Sync／Revoke（V3 主機安全核心、配對與私鑰持有 proof）

## 狀態與範圍

目前已完成的是手機主端上的**本機安全決策、配對請求檢閱與私鑰持有 challenge-response
授權閘門**，不是可對外宣稱已完成的桌面版或多裝置同步功能。它不建立連線、不保存訊息
內容／私鑰，也不會在背景常駐。手機 UI 可透過可替換 adapter 掃描或貼入 QR 內容；目前的
challenge／response 亦只能以加密 payload 手動複製貼上，實際相機權限／掃碼與桌面 runtime
尚未驗收。

已完成並以主機自動化測試驗證：

- 手機主裝置以明確操作授權一個桌面副端。
- 同一個主裝置 ID 不可被授權為副端。
- 同一 device ID 的公開金鑰 fingerprint 改變時 fail-closed，不能靜默延續舊 link。
- 同步候選只接受 `MessageEnvelope.createdAt > authorized_after`；現有訊息為秒級時間，
  同一秒訊息也保守拒絕，避免把配對前歷史資料帶入副端。
- 撤銷後 `selectNewMessages` 一律拒絕，`canSyncMessage` 一律回傳 `false`；重新授權
  必須由主裝置再次明確發起並取得新的同步切點。
- 狀態異動透過 `DesktopLinkChanged` Event Bus 事件發出，後續 transport／UI 不需要直接
  依賴 service 的內部實作。
- 版本化 QR pairing request 僅可有效 30–600 秒，必須指向目前手機主裝置，並嚴格拒絕
  缺欄位、額外欄位、錯版本、過長 payload 與無效 request ID。
- 掃描／貼入只會暫存為可檢閱的 request，**不會授權**；使用者需檢閱裝置名稱與
  fingerprint 後，在確認對話框明確同意才會建立 Desktop Link。
- 同一 request ID 以一次性 `pending → confirming → confirmed/rejected` 狀態處理；拒絕後
  不可再次確認。儲存層不保存 QR 原文。
- 目前 QR schema v2 必須附帶 32-byte X25519 公開金鑰，手機端會重算 device ID＋公開金鑰
  的 fingerprint，拒絕任何不一致的內容。`DesktopLinkPairingRequestIssuer` 可由副端公開金鑰
  建立 canonical request；它不讀取或輸出私鑰。
- V3-04 以既有 X25519 `MessageBox` 的 authenticated `crypto_box` 建立雙向私鑰持有
  challenge-response：手機把隨機、一次性的 token 只放入加密 challenge；副端必須以 QR
  綁定的私鑰解開它，並以同一 token 加密回覆。手機嚴格驗證 request、主／副裝置 ID、公開金鑰
  fingerprint、challenge ID、token 與效期；竄改、錯誤金鑰、重放或過期一律 fail-closed。
- challenge token、pending challenge 與已驗證 proof 都只存在手機 process 的 RAM，且會清除
  暫存位元組；不寫入 SQLite。重新啟動、逾期或失敗後必須重新產生 challenge。
- 沒有有效 proof 時，`confirm` 不會建立授權；proof 成功後，仍須由使用者在確認對話框明確
  同意才會建立 Desktop Link。

## 本機資料模型

SQLite migration v13 建立 `desktop_link_authorizations`：

| 欄位 | 用途 | 不保存的資料 |
|---|---|---|
| `device_id` | 已被主裝置授權的副端識別 | 副端私鑰 |
| `display_name` | 僅供未來 UI 顯示 | 聊天內容或 payload |
| `public_key_fingerprint` | 對應副端身份的公開指紋 | 原始私鑰、shared secret |
| `authorized_after` | 只同步嚴格晚於此秒的新訊息 | 歷史同步游標以外的訊息資料 |
| `revoked_at` | 撤銷後的 fail-closed 狀態 | 已傳資料的刪除或金鑰銷毀證明 |

SQLite migration v14 建立一次性 state，migration v15 將現行的
`desktop_link_pairing_requests` 升級為含公開金鑰 binding 的 schema：

| 欄位 | 用途 | 不表示／不保存的資料 |
|---|---|---|
| `request_id` | 一次性配對請求識別與重放防護 | 桌面端身份已驗證 |
| `target_primary_device_id` | 請求必須指向的手機主裝置 | 任意手機皆可接受 |
| `device_id`、`display_name` | UI 顯示與後續明確授權的識別資料 | 副端私鑰、shared secret、私鑰持有證明 |
| `public_key`、`public_key_fingerprint` | 32-byte X25519 公開金鑰與可重算的 device-bound fingerprint | 私鑰存在、桌面端目前持有私鑰或已完成簽章 |
| `issued_at`、`expires_at` | 30–600 秒的短效請求時間窗 | 桌面端時鐘或網路協定已驗證 |
| `state` | `pending`、`confirming`、`confirmed` 或 `rejected` | 已建立 Desktop transport 或完成同步 |

v15 會刻意作廢 v14 的暫存 request：舊資料只有自行宣告的 fingerprint，無法安全補回公開
金鑰 binding。這些 request 本來就短效且未授權；已建立的 `desktop_link_authorizations`、聊天、
身份與金鑰資料不受影響。

V3-04 刻意**不增加 SQLite schema**：challenge token、待驗證資料與 proof 成功狀態均為短效
RAM state，不能在 app restart 後被重用，也不會成為備份、log 或資料庫內容。

## API 邊界

`DesktopLinkService` 提供以下本機 API：

1. `authorize(...)`：以主裝置明確操作建立或重新建立 link。活動中且 fingerprint
   相同的 link 為 idempotent，不會因重掃而靜默重設同步切點。
2. `canSyncMessage(...)`：fail-closed 快速判定，未授權、已撤銷、配對前與同秒訊息均為
   `false`。
3. `selectNewMessages(...)`：產生可交給未來 transport 的候選訊息；未授權或已撤銷時丟出
   明確例外，不回傳部分資料。
4. `revoke(deviceId)`：持久化撤銷並發布事件；重試仍是 idempotent。

`DesktopLinkPairingService` 提供以下僅限手機主端的流程：

1. `prepareQrPayload(rawPayload)`：嚴格剖析不可信內容、檢查目標主裝置與到期時間，並以
   一次性 request state 暫存；絕不建立 link。
2. `createKeyPossessionChallenge(request)`：為仍有效的 pending request 產生短效、加密且只在
   RAM 保存的 challenge payload；request 剩餘不足 30 秒時拒絕發出，避免使用過短時間窗。
3. `verifyKeyPossessionResponse(rawPayload)`：以手機私鑰解開副端回覆，驗證完整雙向 binding；
   失敗或重放會消耗該 pending challenge，必須重新發出。
4. `confirm(request)`：先原子取得 `confirming` 狀態，再要求有效 proof；沒有 proof 時回復
   pending，絕不呼叫 `authorize(...)`。proof 有效時才呼叫既有授權，成功後標記 confirmed。
5. `reject(request)`：標記 rejected、清除相關 RAM proof，阻止相同 request ID 再次進入確認。

`DesktopLinkKeyPossessionService` 是手機端的 proof coordinator；
`DesktopLinkKeyPossessionResponder` 是可被未來桌面端採用的純 domain responder。兩者皆不負責
桌面 UI、網路、掃碼或持久化；目前手機檢閱頁只顯示可手動傳遞的加密 challenge payload，並接受
手動貼入的 response payload。

`DesktopLinkPairingRequestIssuer` 是供未來 desktop presentation 使用的純 domain helper：

1. 以本機副端 device ID 與公開 X25519 key 產生 request ID、短效期限、canonical public key
   payload 與可重算 fingerprint。
2. 它不建立連線、不產生 desktop UI、不接觸 secret key；因此不會把「可產生 QR」誤當成
   「桌面端已完成配對」或「已證明私鑰持有」。

任何未來 transport 必須先經 `selectNewMessages`，再針對目標副端的**新裝置金鑰**加密。
不得把目前手機端的本機聊天資料庫、既有加密 envelope 或私鑰直接複製到桌面端。

## 尚未實作／不可宣稱的能力

- Windows／macOS／Linux 桌面端的 QR presentation、目標主裝置發現／交付與 challenge responder
  UI。現況只有可重用的 domain responder 與手機端手動密文複製貼上，並沒有可使用的桌面配對
  產品或自動傳遞流程。QR 本身的 fingerprint binding 也不能單獨當成私鑰持有證明。
- Android／iOS 真實相機權限允許／拒絕、相機掃碼與錯誤畫面的 runtime 驗收。
- 實際 Windows／macOS／Linux Desktop transport、連線生命週期、離線重試與同步 UI。
- 原生 libsodium／secure-storage 環境中的 challenge-response runtime 驗證；本輪 host test 以
  test-only `MessageBox` fake 驗證協定邊界，不能替代真實私鑰、原生加密或平台金鑰保存驗收。
- 對每個副端使用獨立 key material 的加密封裝、key rotation、key wipe 與加入／撤銷協定。
- 已撤銷副端不能收到或解密**新**訊息的端對端 runtime 證明。
- 歷史訊息同步、檔案／附件同步、衝突處理、網路中斷恢復與真機／桌面資源量測。

因此，V3-01～V3-04 的完成標示只代表「可由主機驗證的安全核心、手機端請求檢閱、公開金鑰
binding 與 protocol-level 私鑰持有 gate」；它不替代 V1 真機、Push、iOS 或正式環境 Gate，
也不代表桌面副端已可使用。

## 主機驗證

在 `mobile_desktop_app` 執行：

```powershell
$env:NIX_SKIP_SODIUM_BUILD_HOOKS='1'
..\.tools\flutter\bin\flutter.bat test --concurrency=1 `
  test\modules\desktop_link_service_test.dart `
  test\modules\desktop_link_pairing_request_test.dart `
  test\modules\desktop_link_pairing_request_issuer_test.dart `
  test\modules\desktop_link_key_possession_test.dart `
  test\modules\desktop_link_pairing_service_test.dart `
  test\modules\desktop_link_pairing_page_test.dart `
  test\modules\desktop_link_module_test.dart `
  test\modules\database_migration_matrix_test.dart `
  test\modules\identity_schema_test.dart
..\.tools\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
```

此命令目前有 35 項測試：v1→v15 migration、v14 未綁定公開金鑰 request 的安全作廢、
原本的授權／撤銷閘門、版本化 request、公開金鑰／fingerprint binding、canonical issuer、
一次性狀態機、雙向 challenge-response（正常、竄改、錯誤金鑰、重放、過期及更換公開金鑰）
與「先 proof、後明確同意」的手機 UI。`NIX_SKIP_SODIUM_BUILD_HOOKS=1` 只避開此 Windows
主機缺少 C++ native toolchain 的 sodium hook；這些 proof test 使用 test-only `MessageBox`
fake，不代表原生 libsodium、相機、桌面 runtime、真實私鑰持有 proof 或實機加密驗收通過。
