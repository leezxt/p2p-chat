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

預設 profile 為 `local`，服務位於 `http://localhost:8080`。健康檢查：

```powershell
Invoke-RestMethod http://localhost:8080/actuator/health
```

健康端點只公開整體狀態，不公開元件細節。測試使用獨立的 `test` profile：

OpenAPI JSON 位於 `http://localhost:8080/v3/api-docs`，Swagger UI 位於 `http://localhost:8080/swagger-ui.html`。

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

## 規劃模組

```text
src/main/java/com/p2pchat/
  ├─ P2pChatApplication.java
  ├─ core/        security / config / exception / common / event
  └─ modules/     users / contacts / devices / signaling / mailbox /
                  presence / safety / translation / video_call / admin
```

Sprint 3 的 `S3-01`～`S3-06` 已完成。2026-07-12 已以 Docker Compose 5.1.4、PostgreSQL 18.4 與實際 backend image 驗證 container health、readiness、Flyway v1～v3、預期資料表及 OpenAPI。

Sprint 7 mailbox backend 已加入 Flyway V4 與 `/api/v1/mailbox`：支援 encrypted envelope 冪等上傳、recipient pull/cursor、`DELIVERED`/`READ` ACK、sender status、device/contact ACL、quota、rate limit 與 TTL cleanup。PostgreSQL 已驗證 Flyway v1～v4；目前 rate limiter 為單 instance prototype，多實例部署需改用共享 limiter。
