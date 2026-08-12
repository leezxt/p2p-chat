# 安全設計與 Threat Model

本文件定義 V1 端對端加密的安全邊界、協定 profile、金鑰生命週期與失敗處理。
選型資料於 2026-07-12 查證；實作前後都必須以本文件作為驗收基準。

## 安全目標

1. Backend、signaling、mailbox、TURN 與網路觀察者無法讀取或修改聊天內容而不被偵測。
2. 每台裝置使用獨立金鑰；任一裝置撤銷後不能解密之後產生的訊息。
3. 私鑰不寫入 SQLite、log、crash report、analytics、clipboard 或網路。
4. 重複、竄改、錯 key、未知版本與過期密文必須拒絕，不可產生重複訊息。
5. 公鑰變更不可靜默信任；必須產生安全事件並暫停傳送。
6. App 進入背景後關閉 P2P；安全性不得依賴永久連線或可信 server。

## 非目標與限制

- V1 不隱藏必要 metadata，例如收件裝置、密文大小、建立時間與 IP 連線資訊。
- 已解鎖且被完整控制的端點可讀取該端點上的明文，端點全面失陷不在密碼協定可防護範圍內。
- V1 `P2P_BOX_V1` 使用長期裝置金鑰，**不提供 Signal Double Ratchet 等級的 forward secrecy 或 post-compromise security**。
- V1 不宣稱與 Signal Protocol、MLS 或其他產品互通。
- 群組加密、多裝置歷史同步與安全備份不在本 profile 範圍內。

上述限制必須出現在 V1 已知限制；在採用經審查的 ratchet protocol 前，不得宣稱「Signal-grade security」。

## 資產與信任邊界

| 資產 | 保存位置 | 信任要求 |
|---|---|---|
| 裝置私鑰 | Android Keystore / iOS Keychain 保護的 secure storage | 不得明文落盤或由公開 API 匯出 |
| 裝置公鑰 | 本機資料庫與 backend device record | 可公開，但變更必須驗證 |
| 明文訊息 | App 記憶體與本機聊天 DB | 不可送到 server 或寫入 log |
| 密文 envelope | P2P、mailbox、本機 pending queue | Server 可保存但不可解密 |
| Access token | 平台 secure storage / 短期記憶體 | 不進 log；失效後重新認證 |
| App Lock verifier | 平台 secure storage | 只保存 libsodium Argon2id encoded verifier 與防暴力嘗試狀態，不保存 PIN |
| Replay state | 本機 SQLite | 必須跨 crash/restart 保存 |

不信任的元件：backend 管理員、被入侵的 signaling/mailbox、TURN、中間網路、惡意聯絡人、重放舊封包者。

## 威脅與控制

| 威脅 | 控制 | 殘餘風險 |
|---|---|---|
| Server 讀取訊息 | 離開裝置前加密；server 僅見 ciphertext | Metadata 仍可見 |
| Server/網路竄改密文 | `crypto_box_easy` authenticated encryption；驗證失敗即拒絕 | 可丟棄或延遲封包造成 DoS |
| Server 替換公鑰 | TOFU + fingerprint；key change 阻斷傳送；QR out-of-band 驗證 | 首次未驗證接觸仍可能遭 MITM |
| 重放舊密文 | `(senderDeviceId, messageId)` 唯一約束、nonce replay cache、冪等寫入 | 本機 replay DB 被清除後保護降低 |
| Nonce 重用 | 每個收件裝置 envelope 使用 libsodium CSPRNG 產生 24-byte nonce | RNG/平台全面失效不在範圍內 |
| 私鑰落盤或進 log | secure storage、敏感型別禁止 `toString`、日誌稽核、temporary bytes zeroize | App process 被控制時仍可能擷取記憶體 |
| 裝置遺失 | Backend revoke device；聯絡人收到 key/device change 事件 | 舊裝置離線期間已取得的密文無法遠端抹除 |
| Key rotation 降級 | `cryptoVersion`、`suite`、key id 嚴格比對；未知/舊版依政策拒絕 | 舊客戶端可能無法互通 |
| 大型/惡意 payload | 解密前檢查 envelope/schema/ciphertext 大小，解密後再驗證 inner schema | 合法但大量請求仍可能 DoS |

## App Lock 安全邊界

- 6 位 PIN 由 libsodium `crypto_pwhash_str` 使用 Argon2id interactive profile 產生 encoded verifier；salt、演算法與成本參數由 libsodium 管理，不自行實作 KDF。
- PIN 明文不寫入 SQLite、secure storage、log 或 analytics。驗證使用 `crypto_pwhash_str_verify`，App code 不自行比較 hash。
- 連續五次錯誤會冷卻 30 秒；錯誤次數與冷卻期限保存於 secure storage，重新啟動不能清除冷卻。
- App 進入 background 後立即鎖定，根層 gate 遮蔽 Navigator 內容；設定損壞時 fail-closed。
- 生物辨識只委派 Android/iOS 系統 `biometricOnly` 驗證，App 不讀取或保存生物特徵；啟用前先完成一次驗證，失敗、取消、未註冊或系統鎖定均不解鎖，PIN 永遠保留為備援。
- 通知內容預設隱藏；App Lock 狀態未知或已鎖定時一律只使用通用文字。偏好關閉也只能在 App 已解鎖時顯示本機解密後的 sender／preview，遠端 push payload 仍不得包含內容。
- App Lock 是遺失裝置時的本機 UI 防護，不加密聊天 SQLite、不提高 E2EE 強度，也不取代作業系統鎖定、Android Keystore、iOS Keychain 或裝置私鑰保護。
- 生物辨識與通知呈現策略已實作；真機 enrollment change、background/resume、Android Keystore／iOS Keychain runtime 與 FCM/APNs 系統通知仍須實機驗收。

## 協定與函式庫選型

### V1 決策

- Crypto library：[`sodium` 4.0.3](https://pub.dev/packages/sodium)，Dart/Flutter 的 libsodium bindings，支援 Android、iOS、Windows、macOS、Linux 與 secure native memory。
- At-rest storage：[`flutter_secure_storage` 10.3.1](https://pub.dev/packages/flutter_secure_storage)，Android 預設 RSA-OAEP + AES-GCM、Apple 平台使用 Keychain。
- Message primitive：libsodium [`crypto_box_easy`](https://doc.libsodium.org/public-key_cryptography/authenticated_encryption)，即 Curve25519-XSalsa20-Poly1305 authenticated encryption。
- Randomness：libsodium `randombytes_buf`，不得使用時間、UUID 或 Dart `Random` 產生 key/nonce。
- Memory：使用 `SecureKey`；完成操作後清除臨時 byte buffer，參考 libsodium [secure memory](https://doc.libsodium.org/memory_management)。

採用 libsodium 高階 API，不自行組合 cipher、MAC、padding 或 KDF。

### 暫不採用

- [`libsignal`](https://github.com/signalapp/libsignal)：具 X3DH/Double Ratchet 與成熟安全性，但官方聲明外部使用不受支援、bridge API 可無預警變更，授權為 AGPL-3.0，且沒有官方 Dart binding。未完成授權與 native bridge 維護評估前不導入。
- [Signal X3DH](https://signal.org/docs/specifications/x3dh/) / [Double Ratchet](https://signal.org/docs/specifications/doubleratchet/)：作為未來 forward secrecy / post-compromise security 升級候選，不自行重寫規格。
- [MLS RFC 9420](https://www.rfc-editor.org/rfc/rfc9420)：適合未來群組非同步金鑰管理，V1 只有 1:1 且缺少合適 Dart implementation。
- [HPKE RFC 9180](https://www.rfc-editor.org/rfc/rfc9180)：是標準 hybrid encryption building block，但本身不提供完整 messaging ratchet；目前沒有選定跨平台 Dart implementation，不自行實作 RFC。

## `P2P_BOX_V1` Profile

### 裝置金鑰

- 每台裝置產生獨立 Curve25519 key pair。
- `keyId = base64url(SHA-256(publicKey))[0..21]`，只作索引，不作信任證明。
- Fingerprint 使用完整 `SHA-256("p2p-chat-device-key-v1" || deviceId || publicKey)`，以分組十六進位顯示並可轉 QR。
- Backend device record 只保存 public key、key id、fingerprint、createdAt、revokedAt。
- Secret key 由平台 secure storage 加密保護；SQLite 只保存 key id 與 public metadata。libsodium Curve25519 key 必須由 App 載入記憶體使用，並非 Android Keystore / Secure Enclave 內永不可匯出的硬體 key；V1 的保證是私鑰不明文落盤、不寫入 log，且不對模組外提供明文匯出 API。
- Backend registration 與 legacy key initialization 只接收 public key/fingerprint；初始化端點要求 JWT、device ownership、未撤銷狀態，且只允許 `pending:` 升級或相同 fingerprint 的冪等重送。其他 key rotation 必須走 S6-05 驗證流程。

### 加密 Envelope

```json
{
  "cryptoVersion": 1,
  "suite": "P2P_BOX_V1",
  "senderDeviceId": "device_a",
  "recipientDeviceId": "device_b",
  "senderKeyId": "key_a",
  "recipientKeyId": "key_b",
  "messageId": "msg_123",
  "nonce": "base64url-24-bytes",
  "ciphertext": "base64url"
}
```

`crypto_box_easy` 使用 combined mode，16-byte Poly1305 認證標記包含在 `ciphertext` 前段，不另設可分離或遺漏的 `tag` 欄位。V1 ciphertext 上限為 1 MiB，解密前先拒絕過短或超限資料。

真正的 `MessageEnvelope` 全部放在 ciphertext 內。解密後必須比對 inner/outer 的 `messageId`、sender/recipient device 與 key id；不一致即拒絕。Outer metadata 只供 routing 與選 key，不能單獨作為可信資料。

加密流程：

1. 取得已信任且未撤銷的 recipient device public key。
2. 產生全新 24-byte nonce；同一 sender/recipient key pair 永不重用 nonce。
3. 將完整 inner `MessageEnvelope` canonical JSON 編碼為 UTF-8。
4. 呼叫 `crypto_box_easy(inner, nonce, recipientPublicKey, senderSecretKey)`。
5. 立即清除 plaintext temporary buffer；P2P/mailbox 只接收 encrypted envelope。

解密流程：

1. 驗證版本、suite、欄位型別、base64、最大密文大小與 recipient key id。
2. 在 replay DB 檢查 sender device + message id；已處理則冪等忽略。
3. 使用 sender public key、recipient secret key 與 nonce 呼叫 `crypto_box_open_easy`。
4. 認證失敗、錯 key、未知 sender、key changed 或 outer/inner 不一致時拒絕。
5. 驗證 inner message schema 後，以 transaction 寫入訊息與 replay record。
6. 清除 plaintext temporary buffer，再發出 `MessageReceived`。

加密端以 `JsonUtf8Encoder` 直接產生可清除的 UTF-8 buffer，避免先建立完整 plaintext JSON String。解密端受 Dart 標準 JSON parser 限制，解析時仍會短暫建立不可主動 zeroize 的 String；buffer 會立即清除，但 process memory 全面擷取仍屬既有端點失陷風險。

## Replay、順序與時鐘

- `messageId` 必須由 CSPRNG/UUID v4 產生，DB 對 `(senderDeviceId, messageId)` 建唯一索引。
- 對 `(senderKeyId, nonce)` 建 replay record；同 nonce 再出現直接拒絕。
- 不依賴 `createdAt` 判斷唯一性，裝置時鐘不可信。
- 訊息允許亂序；ACK 與 mailbox 重送必須冪等。
- Replay record 至少保留 mailbox 最大 TTL 加安全緩衝；清理不得早於密文 TTL。
- 本機 schema v4 使用 `crypto_replay_records`，同時唯一限制 `(senderDeviceId, messageId)` 與 `(senderDeviceId, nonce)`；解密前先查詢以快速拒絕，認證與 inner/outer 驗證成功後再原子 insert，避免未認證資料污染 replay DB。

## Key Rotation、撤銷與遺失

- 正常 rotation：先產生並註冊新 key，再將舊 key 標為 decrypt-only；待 mailbox TTL 與 pending ACK 全部結束後才刪除舊私鑰。
- 公鑰無預期變更：聯絡人狀態改為 `keyChanged`，暫停自動傳送與解密新 key 的訊息，要求使用者重新驗證。
- App 不信任 backend 宣告的 fingerprint，會以 `deviceId + publicKey` 本機重算並比對；不一致的邀請資料直接拒絕。
- 首次透過邀請碼取得的 remote key 寫入 `remote_key_trust` 作為 TOFU 信任。相同裝置後續出現不同 key/fingerprint 時只寫入 pending 欄位、發出 `RemoteDeviceKeyChanged`，resolver 在 pending 存在期間拒絕加解密。
- 重新信任必須由明確流程呼叫 `trustPendingKey`；新 key 提升為 trusted 並同步聯絡人資料後，傳送才恢復。既有 contact key 由 schema v4 migration 匯入 trust table，避免升級後靜默重設信任。
- 裝置撤銷：backend 拒絕其 signaling/mailbox；其他裝置停止對該 key 加密。
- 裝置遺失或 secure storage 損壞：產生新 device/key；舊密文不可恢復。V1 不提供伺服器端 key recovery。
- 身份重設是破壞性操作，必須明確確認並告知舊訊息/聯絡人信任影響。

## Secure Storage 規則

- Android 使用 `flutter_secure_storage` 10.x 預設 RSA-OAEP + AES-GCM；設定 `android:allowBackup="false"`，避免備份後 key wrapping 失配。

## 敏感日誌規則

- 所有 App 日誌統一經 `LoggingService`；禁止直接記錄聊天 payload、plaintext、ciphertext、私鑰、secret key、access token 或 Authorization header。
- Logger 在輸出前遮蔽 bearer/JWT、token、secret/private key、plaintext、ciphertext 與 payload 格式，錯誤 stack trace 套用相同處理。
- Crypto exception 的 `toString()` 只輸出穩定錯誤碼，不串接底層 cause；`EncryptedEnvelope` 與 key material 的字串表示不輸出密文或私鑰。
- 遮蔽是最後防線，呼叫端仍不得主動把敏感資料放入日誌訊息；未來增加檔案或遠端 log sink 時必須沿用同一 sanitizer。

## Offline Mailbox 安全邊界

- Mailbox 只接受 `P2P_BOX_V1` encrypted envelope；上傳者必須擁有 sender device，只有 recipient device owner 可下載與 ACK。
- 不存在、已撤銷或未建立 contact relationship 的 recipient 統一回一般化錯誤，避免裝置枚舉。
- 下載不等於送達；只有密文認證、replay 檢查與本機 DB 寫入成功後才可送 `DELIVERED`。
- Server 不保存 inner message type、conversation ID、明文 payload、顯示名稱、私鑰或 access token。完整限制見 [`mailbox_api.md`](mailbox_api.md)。
- iOS 使用 Keychain，預設選擇 `first_unlock_this_device` 或更嚴格 accessibility；不得同步到其他裝置。
- Secure storage API 對上層只回傳 `SecureKey`/key handle，不提供 export、copy 或 debug dump。
- 反序列化期間若必須出現 raw bytes，只能存在最短生命週期，完成後覆寫並釋放。
- Key 不可放入 shared preferences、SQLite、環境變數、Dart define 或測試 snapshot。

## 日誌與錯誤

- 禁止記錄 plaintext、ciphertext 全文、nonce、secret/public key 全文、access token 或 QR payload。
- 可記錄：錯誤分類、cryptoVersion、suite、截短 messageId、非敏感狀態碼。
- 對 UI 顯示穩定錯誤碼，例如 `UNKNOWN_CRYPTO_VERSION`、`KEY_CHANGED`、`AUTH_FAILED`、`REPLAY_REJECTED`；不顯示底層 key material 或 stack trace。
- Crypto error 不得 fallback 成明文傳送。

## 上線門檻

- S6-02～S6-06 全部通過前，真實網路不得傳送現有明文 `MessageEnvelope`。
- Production `P2pSessionManager` 預設拒絕明文訊息；僅 deterministic test 可明確啟用 insecure test transport。
- 必須測試 round-trip、竄改、錯 key、nonce 重用、replay、未知版本、outer/inner 不一致、key change 與 secure storage failure。
- 必須檢查 server/App log，證明無 plaintext、private key 或 token。
- 對外安全宣稱需經獨立安全審查；本文件不是密碼學稽核報告。

V1 工程稽核結果、已修復問題、驗證命令與殘餘風險見 [`security_audit_v1.md`](security_audit_v1.md)。

## 參考來源

- [Signal libsignal repository](https://github.com/signalapp/libsignal)
- [Signal X3DH specification](https://signal.org/docs/specifications/x3dh/)
- [Signal Double Ratchet specification](https://signal.org/docs/specifications/doubleratchet/)
- [RFC 9420: Messaging Layer Security](https://www.rfc-editor.org/rfc/rfc9420)
- [RFC 9180: Hybrid Public Key Encryption](https://www.rfc-editor.org/rfc/rfc9180)
- [libsodium authenticated public-key encryption](https://doc.libsodium.org/public-key_cryptography/authenticated_encryption)
- [libsodium secure memory](https://doc.libsodium.org/memory_management)
- [`sodium` Dart package](https://pub.dev/packages/sodium)
- [`flutter_secure_storage` Flutter package](https://pub.dev/packages/flutter_secure_storage)
- [Android Keystore key protection](https://developer.android.com/privacy-and-security/keystore)
