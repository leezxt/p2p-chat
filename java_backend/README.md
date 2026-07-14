# java_backend

Java Spring Boot 原型後端，用於開發展示、API 原型，以及後續可替換的 signaling / mailbox 服務。

## 需求

- Java 21
- Maven 3.6.3+

## 執行

```powershell
docker compose up -d postgres
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

執行前將 `.env.example` 複製為 `.env` 並替換本機密碼；請勿提交 `.env`。資料庫使用 PostgreSQL 18.4，Spring 啟動時由 Flyway 自動執行 migration。

未指定 profile 時預設使用 fail-closed 的 `prod`，並要求 `DB_URL`、`DB_USERNAME`、`DB_PASSWORD`、`JWT_SECRET` 與 `PUSH_TOKEN_ENCRYPTION_KEYS`。`WEBSOCKET_ALLOWED_ORIGINS` 可用逗號分隔設定 browser signaling 的精確 origin 清單；未設定時使用空 allowlist／same-origin policy，production 禁止 `*`。Android/iOS native client 不送 `Origin`，仍可使用 JWT/device authentication 連線。本機開發必須明確使用上方的 `local` profile；服務位於 `http://localhost:8080`。健康檢查：

```powershell
Invoke-RestMethod http://localhost:8080/actuator/health
```

健康端點只公開整體狀態，不公開元件細節。測試使用獨立的 `test` profile：

`local` profile 的 OpenAPI JSON 位於 `http://localhost:8080/v3/api-docs`，Swagger UI 位於 `http://localhost:8080/swagger-ui.html`；`prod` profile 會停用兩者。

```powershell
mvn test
```

具 Docker 的環境可執行完整容器 smoke test：

```powershell
.\scripts\smoke.ps1
```

Smoke 每次使用 process-only 隨機 credentials、獨立 Compose project 與可用 host ports，
驗證 readiness、non-root `app`、Flyway 1～9 與 10 個 public tables。成功或失敗都移除
本輪 containers/networks/test volume 並恢復呼叫端環境；失敗時會先輸出最後 200 行 logs。

建立可追溯的 backend candidate JAR、Docker image 與 JSON manifest：

```powershell
.\scripts\build-candidate.ps1
```

Manifest 記錄來源 commit、backend version、JAR SHA-256、local image ID/RepoDigests、
size 與 OCI labels，但不包含 `.env` 或任何 secret。本機 digest 不證明已發布，正式推送
image 後仍需由 registry 另外確認並記錄 digest。

## Production HTTPS/WSS 部署

將 `production.env.example` 複製為被 Git 忽略的 `production.env`，填入公開網域、
ACME email、三個 registry-pinned image digests 與隨機 secrets。先執行 fail-closed
preflight，再啟動 production topology：

```powershell
.\scripts\preflight-production.ps1 -EnvFile .\production.env
docker compose --env-file .\production.env -f .\compose.production.yml up -d
```

`compose.production.yml` 只公開 Caddy 的 80/443 TCP 與 443 UDP；backend 僅 expose
container port 8080，PostgreSQL 無 host port且位於 internal network。Caddy 自動取得 TLS
certificate、代理 HTTPS/WSS、加入 HSTS/安全 headers 並移除 `Server` header。Backend
使用 `prod` profile、read-only root filesystem、drop all capabilities 與 non-root `app`
user。正式環境不可使用 `-AllowLocalVerification`。

三個 production containers 預設使用 Docker `json-file` rotation（每檔 `10m`、保留 5
檔），可用 `LOG_MAX_SIZE` 與 `LOG_MAX_FILES` 調整；preflight 限制 size 格式與 2～20
檔，避免誤設為無界限。正式啟動前仍需另外完成 DNS、firewall、registry access、
volume backup/restore、外部告警接收器與憑證續期演練。停止服務時不要任意加
`--volumes`，否則會刪除 PostgreSQL 與 Caddy certificate 資料。

啟動後可由另一台主機執行 one-shot probe；成功回 `PASS`/exit 0，任何 HTTP redirect、
readiness、security header 或 WSS upgrade 問題都回 `FAIL`/非零 exit code：

```powershell
.\scripts\monitor-production.ps1 -EnvFile .\production.env
```

將此命令接至既有監控排程與告警通道。輸出的 endpoint 與 check 狀態不含 DB/JWT/push
secret；WebSocket probe 只驗證 `101` transport upgrade，不送 `AUTH` frame。

### PostgreSQL 備份與還原

服務 healthy 時建立 PostgreSQL custom-format 壓縮 dump、SHA-256 manifest，並先執行
`pg_restore --list` 完整性檢查：

```powershell
.\scripts\backup-production.ps1 -EnvFile .\production.env
```

備份預設位於被 Git 忽略的 `target/production-backups/`。Dump 含應用資料，即使訊息
內容主要是密文，仍必須移至限制存取的加密儲存並設定 retention。

還原演練預設只建立明確指定的新資料庫：

```powershell
.\scripts\restore-production.ps1 `
  -BackupPath .\target\production-backups\<backup>.dump `
  -TargetDatabase p2p_chat_restore_verify `
  -EnvFile .\production.env `
  -CreateTargetDatabase
```

既有 target 必須同時提供 `-ReplaceExistingTarget` 與區分大小寫的
`-Confirmation 'REPLACE:<database>'`。設定中的 production source database 另需
`-AllowSourceDatabaseReplacement`；一般演練不得使用此 switch。

不依賴 Docker、以 H2 test profile 驗證 Flutter HTTP client 與真實 Spring backend：

```powershell
.\scripts\app-integration.ps1
```

此腳本會驗證 user/device 註冊、重註冊 token、JWT 授權、邀請碼、QR payload、重複兌換與錯誤開發金鑰，完成後自動關閉測試 backend。

Push token 使用 AES-256-GCM 加密保存。`PUSH_TOKEN_ENCRYPTION_KEYS` 格式為
`current-id=<base64-32-byte-key>,old-id=<base64-32-byte-key>`；第一把 key 用於新寫入，後續 key 只供輪替期間解密舊 token。撤銷時立即清除 ciphertext，預設 30 天後刪除 hash/tombstone。Flyway V7 會失效 V6 既有明文 token，client 必須重新註冊。

FCM delivery 預設關閉。啟用時同時設定 `PUSH_DELIVERY_ENABLED=true`、`FCM_ENABLED=true`、`FCM_PROJECT_ID`，並透過 Google Application Default Credentials 提供 Firebase service account 或 workload identity。直接在 host 執行可設定 `GOOGLE_APPLICATION_CREDENTIALS`；Docker 部署需將 credential file 以 read-only secret mount 放入容器並讓該變數指向容器內路徑，不可把 JSON credential 提交到 repository 或寫入 image。

Worker 使用 FCM HTTP v1 data-only request，只送 `schemaVersion=1` 與 `type=MAILBOX_AVAILABLE`。Flyway V9 加入短交易 claim、兩分鐘 lease、lease token 與有上限的 retry；多 instance 不會同時持有同一工作，過期 worker 也無法覆寫新 worker 結果。`UNREGISTERED` / `NOT_FOUND` 只會在 token hash 仍相符時撤銷 token，避免舊 response 撤銷剛更新的新 token。

完整測試矩陣、環境需求與結果判讀見 [`../docs/testing.md`](../docs/testing.md)。

## 規劃模組

```text
src/main/java/com/p2pchat/
  ├─ P2pChatApplication.java
  ├─ core/        security / config / exception / common / event
  └─ modules/     users / contacts / devices / signaling / mailbox /
                  presence / safety / translation / video_call / admin
```

Sprint 3 的 `S3-01`～`S3-06` 已完成。2026-07-12 已以 Docker Compose 5.1.4、PostgreSQL 18.4 與實際 backend image 驗證 container health、readiness、Flyway v1～v3、預期資料表及 OpenAPI。

Sprint 7 mailbox backend 已加入 Flyway V4/V8 與 `/api/v1/mailbox`：支援 encrypted envelope 冪等上傳、recipient pull/cursor、`DELIVERED`/`READ` ACK、sender status、device/contact ACL、quota、TTL cleanup，以及以 PostgreSQL 原子 counter 實作的多 instance 共用 fixed-window rate limit。超限回 `429 MAILBOX_RATE_LIMITED` 與 `Retry-After`。Sprint 8 FCM HTTP v1 worker 使用 Flyway V9。PostgreSQL 已驗證 Flyway v1～v9。
