# Desktop Link／Device Sync／Revoke（V3 主機安全核心）

## 狀態與範圍

目前已完成的是手機主端上的**本機安全決策層**，不是可對外宣稱已完成的桌面版或
多裝置同步功能。它不建立連線、不掃 QR、不保存訊息內容／私鑰，也不會在背景常駐。

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

## 本機資料模型

SQLite migration v13 建立 `desktop_link_authorizations`：

| 欄位 | 用途 | 不保存的資料 |
|---|---|---|
| `device_id` | 已被主裝置授權的副端識別 | 副端私鑰 |
| `display_name` | 僅供未來 UI 顯示 | 聊天內容或 payload |
| `public_key_fingerprint` | 對應副端身份的公開指紋 | 原始私鑰、shared secret |
| `authorized_after` | 只同步嚴格晚於此秒的新訊息 | 歷史同步游標以外的訊息資料 |
| `revoked_at` | 撤銷後的 fail-closed 狀態 | 已傳資料的刪除或金鑰銷毀證明 |

## API 邊界

`DesktopLinkService` 提供以下本機 API：

1. `authorize(...)`：以主裝置明確操作建立或重新建立 link。活動中且 fingerprint
   相同的 link 為 idempotent，不會因重掃而靜默重設同步切點。
2. `canSyncMessage(...)`：fail-closed 快速判定，未授權、已撤銷、配對前與同秒訊息均為
   `false`。
3. `selectNewMessages(...)`：產生可交給未來 transport 的候選訊息；未授權或已撤銷時丟出
   明確例外，不回傳部分資料。
4. `revoke(deviceId)`：持久化撤銷並發布事件；重試仍是 idempotent。

任何未來 transport 必須先經 `selectNewMessages`，再針對目標副端的**新裝置金鑰**加密。
不得把目前手機端的本機聊天資料庫、既有加密 envelope 或私鑰直接複製到桌面端。

## 尚未實作／不可宣稱的能力

- QR pairing request、一次性配對碼、手機端使用者確認與桌面端身份驗證。
- 實際 Windows／macOS／Linux Desktop transport、連線生命週期、離線重試與同步 UI。
- 對每個副端使用獨立 key material 的加密封裝、key rotation、key wipe 與加入／撤銷協定。
- 已撤銷副端不能收到或解密**新**訊息的端對端 runtime 證明。
- 歷史訊息同步、檔案／附件同步、衝突處理、網路中斷恢復與真機／桌面資源量測。

因此，V3-01 的完成標示只代表「可由主機驗證的安全核心」；它不替代 V1 真機、Push、
iOS 或正式環境 Gate，也不代表桌面副端已可使用。

## 主機驗證

在 `mobile_desktop_app` 執行：

```powershell
$env:NIX_SKIP_SODIUM_BUILD_HOOKS='1'
..\.tools\flutter\bin\flutter.bat test test\modules\desktop_link_service_test.dart `
  test\modules\desktop_link_module_test.dart `
  test\modules\database_migration_matrix_test.dart `
  test\modules\identity_schema_test.dart
..\.tools\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
```

`NIX_SKIP_SODIUM_BUILD_HOOKS=1` 只避開此 Windows 主機缺少 C++ native toolchain 的 sodium
hook；它不代表原生 libsodium、桌面 runtime 或實機加密驗收通過。
