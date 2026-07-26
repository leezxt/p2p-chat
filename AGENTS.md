# AGENTS.md — Codex / AI Agent 開發指令

本檔為 Codex / AI Agent 開發本專案時的權威規則，衍生自《開發總規格 v1.2》§0、§26。修改程式碼前務必先讀本檔與 [`docs/architecture.md`](docs/architecture.md)。

## 總原則

先核心、後模組；先手機、後電腦；先文字、後影音；先低資源、後高功能。目標是可逐步擴充的 Simple Communication，不是一開始就複製 LINE / WhatsApp / Discord。

## 硬性規則

1. 不要把所有功能寫在單一檔案；每個功能放入對應 module。
2. 不要讓 Chat Module 直接依賴 Sticker / P2P 內部實作；跨模組溝通一律用 Event Bus。
3. 新訊息類型必須以 `type + payload` 擴充，不可破壞既有 message schema。
4. 不在背景永久維持 WebRTC；不高頻 heartbeat。
5. 不把明文聊天內容上傳伺服器；不把私鑰存成明文。
6. 不自動下載大型附件；第一版不支援 SVG 貼圖。
7. 新增功能優先新增 module，不改壞 Core。
8. 每個 module 需有 `init / activate / sleep / dispose` 生命週期。
9. 資料庫 migration 必須可追蹤、可回退。
10. 所有網路傳輸失敗都要有 retry / failed 狀態；離線訊息未收到 ACK 前不可刪除。
11. App 背景時依賴推播，不依賴常駐連線。
12. 貼圖包匯入前必須驗證格式與大小（防 zip slip）。
13. 所有功能預設考慮手機省電與低記憶體。
14. 翻譯預設不可將明文送雲端，除非使用者明確啟用；翻譯結果存本機 metadata，不改寫原始訊息。
15. 視訊 / 語音 / 檔案 / AI 模組預設 disabled 或 sleeping；按需啟動、用完釋放資源。
16. 會增加伺服器成本的功能，必須在 `docs/cost_notes.md` 註明。
17. 會上傳任何使用者內容的功能，必須在 UI 顯示明確提示。
18. 刪除 / 撤銷 / 清理功能必須有可預期行為，不可誤刪私鑰。
19. 每個 Sprint 完成後更新 README 與 docs。

## 程式碼慣例

- 語言：Dart（app）、Java（backend）。程式識別字用英文；註解與文件用繁體中文。
- 註解解釋「為什麼 / 限制 / 取捨」，不重述程式碼。
- 例外處理放信任邊界（使用者輸入、檔案、網路、DB）。
- 妥善管理連線、檔案控制代碼、背景程序等資源生命週期。

## 模組結構慣例

每個模組資料夾內部分層：

```text
modules/<name>/
  ├─ data/          Repository、DAO、DTO
  ├─ domain/        Model、UseCase、業務邏輯
  ├─ events/        該模組發出 / 訂閱的事件
  └─ presentation/  Page、Widget、Controller
```
