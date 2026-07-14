# V1 安全與隱私稽核

稽核日期：2026-07-13

範圍：Flutter App、Spring Boot signaling/mailbox/presence/push API、平台儲存設定、production profile 與既有安全回歸測試。這是 V1 發布前的工程稽核，不取代獨立第三方密碼學或滲透測試。

## 結論

V1-02 的程式與自動化驗收已完成。私鑰只透過平台 secure storage 保存，access token 只存在記憶體，SQLite 沒有私鑰或 token 欄位；P2P 與 mailbox 僅傳送 `P2P_BOX_V1` 密文。Logger、exception 與 push payload 不輸出聊天明文、密文全文、私鑰或 access token。

本次修正兩個高優先授權問題：

1. Mailbox ACK 在交易提交後才驗證 `messageId`，錯誤 ACK 可能已推進狀態。驗證已移入 transactional service，狀態變更前即拒絕。
2. Signaling 原本允許任意已登入裝置 relay 至任意在線裝置，並可由錯誤碼探測在線狀態。現在要求 sender 與 target 已有 contact relationship，且不存在、未授權與離線統一回 `TARGET_UNAVAILABLE`。

Production 預設改為 fail-closed：未指定 profile 時使用 `prod`、要求環境提供 DB/JWT 設定、停用本機註冊與 local token controller、停用 OpenAPI/Swagger、隱藏錯誤 message/stack trace。Android release manifest 明確停用 cleartext traffic 與 backup；debug manifest 仍只為本機開發允許 HTTP。

## 已驗證控制

| 控制 | 結果 |
|---|---|
| JWT issuer、audience、expiry 與至少 32-byte HMAC key | 通過既有 Java tests |
| Device ownership、revocation、contact ACL | Mailbox、Presence、Push 與 Signaling integration tests 通過 |
| Mailbox sender/recipient ACL、quota、TTL、rate limit、ACK 狀態機 | 通過；rate limit 使用 PostgreSQL 原子 counter，多 instance 共用配額並回 `Retry-After`；錯誤 `messageId` 不再改變狀態 |
| Mailbox cursor 完整性與用途隔離 | HMAC-SHA256 signed opaque cursor；綁定 inbox/ACK 用途與 device，竄改、跨裝置及跨用途重用均拒絕 |
| Replay、tamper、wrong key、inner/outer mismatch、key change | Flutter 回歸 tests 通過 |
| Private key / token 儲存邊界 | 私鑰走 secure storage；SQLite schema 無私鑰/access token |
| 敏感日誌 | Logger sanitizer 與 crypto `toString()` tests 通過；Java main code 無直接 request/body logger |
| Push payload | FCM HTTP v1 data-only request；Outbox 只含 `schemaVersion` 與 `MAILBOX_AVAILABLE`，tampered payload 不送出 |
| Push token at rest | AES-256-GCM、device/provider AAD、版本化 key ID；撤銷立即清 ciphertext，30 天後刪 tombstone |
| Push worker concurrency | PostgreSQL 短交易 claim、兩分鐘 lease 與 lease token；過期 worker 無法覆寫新 worker，最多 8 次 bounded retry |
| Push token invalidation | `UNREGISTERED` / `NOT_FOUND` 只在 token ID/hash 仍相符時撤銷，避免舊 response 撤銷新 token |
| Production surface | local registration 與 API docs 在 `prod` profile 均為 404 |
| WebSocket origin policy | 精確 allowlist；未設定時 empty/same-origin，production 禁止 `*`，未列入來源握手回 403 |
| Transport policy | Android release cleartext=false；iOS 使用預設 ATS 限制 |
| Production deployment boundary | Caddy 僅公開 80/443，backend/PostgreSQL 無 host port；data network internal；backend read-only rootfs、drop capabilities、non-root `app`；preflight 強制 HTTPS origins 與 registry digests |
| Backup/restore boundary | custom dump 排除 owner/privileges、附 SHA-256 manifest 並先做 `pg_restore --list`；restore 預設只准新 DB，既有 DB 與 production source 各有獨立明確確認 gate |
| Backup retention boundary | 預設 dry-run；只有通過 dump/manifest/custom-format/SHA-256 與 off-host receipt 驗證、超過期限且不在最新保留數內的本機 staging backup 才能刪除；Apply 需精確確認，corrupt/orphan/reparse point 均保護 |
| Log/monitoring boundary | 三服務使用有界 `json-file` rotation；one-shot probe 只輸出 endpoint/check 狀態，驗證 HTTPS readiness/security headers/WSS 101，不讀 DB/JWT/push secret |

## 驗證結果

```text
java_backend: mvn -q test
51 tests, 0 failures, 0 errors

mobile_desktop_app: flutter analyze
No issues found

mobile_desktop_app: flutter test（排除 Windows native device_key_service_test.dart）
82 tests, All tests passed

mobile_desktop_app: flutter build apk --debug
Built build/app/outputs/flutter-apk/app-debug.apk
```

`device_key_service_test.dart` 在 Windows 仍需要 Visual Studio Desktop development with C++。Android 真實 libsodium/secure storage/WebRTC runtime 沿用先前雙 AVD 驗收；iOS Keychain、libsodium 與 WebRTC 仍須在支援目標 iOS 的 Xcode/真機重驗。

## 殘餘風險

- V1 `P2P_BOX_V1` 使用長期裝置金鑰，不具 Double Ratchet 等級的 forward secrecy 或 post-compromise security。
- FCM HTTP v1 worker 已完成自動化/PostgreSQL 驗證；真實 FCM credentials、APNs、兩台真機、iOS runtime、斷網/kill process 與資源耗電量測仍屬外部驗收。
- `flutter_webrtc` 仍套用 Kotlin Gradle Plugin；目前 build 通過，但 Flutter 已警告未來版本將要求 plugin 遷移至 Built-in Kotlin。
- Production Compose/Caddy、bounded logs 與 one-shot monitor 已通過 localhost TLS/WSS 隔離驗證，但公開 DNS、ACME certificate、firewall、registry digest、off-host 備份與外部告警仍需部署環境驗收。
- 本機 restore drill 已驗證 dump 可用，retention fixtures 也已驗證本機 staging 清理的 dry-run、精確確認、最少保留數、receipt/hash 防護與冪等；但 dump 仍含帳號、routing metadata、密文與其他應用資料。正式環境仍須提供加密 off-host storage、由外部系統核對遠端 object 後簽發 receipt、最小權限、排程與實際刪除政策。

## 後續門檻

1. 完成真實 FCM/APNs credentials、通知權限與 cold/warm start 驗收。
2. 以 Android/iPhone 真機重跑 secure storage、P2P、mailbox、ACK、斷網與 kill process。
