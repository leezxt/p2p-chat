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
