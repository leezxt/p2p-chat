# Firebase Test Lab Android 真機驗收

本專案使用 Firebase Test Lab 的 Android instrumentation test，在不持有本機手機的情況下
執行遠端實體裝置驗收。付費送測只允許從 `main` 手動啟動；免費 preflight 可從 WIF
attribute condition 明確授權的分支執行。送測前會查詢 Test Lab catalog，拒絕 virtual
model 或不支援的 model/version 組合。

Workflow 預設只執行免費 preflight，不建立 Test Lab matrix。Preflight 會建置 APK、以
GitHub OIDC 驗證 WIF、查詢實體裝置 catalog，並對 results bucket 寫入後刪除一個探測
物件。只有手動將 `submit_test` 設為 `true` 才會提交可能產生費用的實體裝置測試。
Preflight 另會保存 model/version 的容量資訊；付費送測預設拒絕 `Low`、`None` 或沒有
公開容量的組合。`Low` 只有在同一次 dispatch 明確設定 `allow_low_capacity=true` 才能送出。

目前送測目標是 `integration_test/android_crypto_runtime_test.dart`，覆蓋 production
Android secure storage、真實 libsodium failure paths、SQLite replay protection 與
encrypted WebRTC DataChannel。單一遠端裝置不能取代雙裝置 E2E、實際斷網、OS kill、
行動網路切換或長時間耗電 Gate。

## Google Cloud 前置設定

1. 建立專用 Firebase／Google Cloud 專案並啟用 billing、Firebase Test Lab 與
   `testing.googleapis.com`。
2. 建立專用 results bucket。Workflow 要求 `gs://` URI，不使用需要廣泛
   `roles/editor` 的 Firebase 預設 bucket。
3. 建立 GitHub Actions 專用 service account，授予：
   - Firebase Test Lab Admin：`roles/cloudtestservice.testAdmin`
   - Firebase Analytics Viewer：`roles/firebase.analyticsViewer`
   - 對專用 results bucket 的最小必要 object 權限
4. 建立 Workload Identity Pool／Provider，attribute condition 至少限制不可變 repository／
   owner ID 與 `assertion.ref == 'refs/heads/main'`。若要在 PR 分支驗證免費 preflight，僅
   額外加入該分支的完整 ref，不使用任意分支通配；並只允許該 principal 以
   `roles/iam.workloadIdentityUser` impersonate 上述 service account。PR 完成並刪除分支後，
   立即從 condition 移除該分支 ref。
5. 在 GitHub repository 的 Actions variables 設定：

| Variable | 值 |
|---|---|
| `GCP_PROJECT_ID` | Firebase／Google Cloud project ID |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/<number>/locations/global/workloadIdentityPools/<pool>/providers/<provider>` |
| `GCP_SERVICE_ACCOUNT` | Test Lab service account email |
| `FTL_RESULTS_BUCKET` | 專用 bucket URI，例如 `gs://example-ftl-results` |

不要建立或提交 service-account JSON key。Workflow 使用 GitHub OIDC Workload Identity
Federation，且 `.gitignore` 會排除 Google auth action 產生的暫時 credential file。

## 選擇實體裝置

先在已登入目標專案的 Cloud Shell 執行：

```bash
gcloud firebase test android models list
gcloud firebase test android models describe <MODEL_ID> --format=json
gcloud firebase test android list-device-capacities --filter=<MODEL_ID> --format=json
```

記錄 physical model 的 `MODEL_ID` 與其 `supportedVersionIds`。Test Lab catalog 會變動，
因此 repository 不硬編碼特定手機；每次手動執行 workflow 時輸入 model、version 與
locale。若 catalog 回傳的 `form` 不是 `PHYSICAL`，workflow 會在付費送測前失敗。

## 執行

在 GitHub Actions 選擇 **Firebase Test Lab Android**。付費 submission 必須使用 `main`；
免費 dry-run 可使用 WIF 已精確授權的分支。填入：

- `device_model`：physical `MODEL_ID`
- `android_version`：該 model 支援的 `OS_VERSION_ID`，且不得低於 API 24
- `locale`：預設 `zh_TW`
- `submit_test`：預設 `false`；確認裝置、10 分鐘 timeout 與可能費用後才設為 `true`
- `allow_low_capacity`：預設 `false`；只在已知可能長時間排隊並願意等待時明確開啟
- `queue_timeout_minutes`：預設 90，可設 15～120；逾時會取消尚未完成的 matrix

也可使用 GitHub CLI：

```bash
gh workflow run firebase-test-lab.yml \
  --ref main \
  -f device_model=<MODEL_ID> \
  -f android_version=<OS_VERSION_ID> \
  -f locale=zh_TW \
  -f submit_test=false \
  -f allow_low_capacity=false \
  -f queue_timeout_minutes=90
```

Dry-run 會建立 debug app/test APK、SHA-256、catalog JSON、bucket preflight log，並保存為
7 天 GitHub artifact，但不會建立 Test Lab matrix。`submit_test=true` 時，workflow 使用
`gcloud ... run --async --format=json` 建立 matrix，立即保存 `matrix-submit.json` 與
`matrix-id.txt`，再透過 Testing API 輪詢狀態。排隊預設最多 90 分鐘；開始執行後最多監控
30 分鐘，裝置上的 instrumentation timeout 仍是 10 分鐘。排隊／監控逾時、SIGINT、
SIGTERM 或 runner 取消時，監控腳本會呼叫 Testing API `:cancel`，避免留下孤立 matrix。

`matrix-latest.json`、`matrix-summary.txt` 與可能的 `matrix-cancel.json` 會納入 evidence
artifact；詳細裝置 logs、影片與 screenshots 位於設定的 results bucket。只有 matrix
`FINISHED / SUCCESS` 才回傳成功；`FAILURE`、`INCONCLUSIVE` 與 API terminal error 均失敗。

## 本機只建置 APK

Linux、macOS 或 Windows Git Bash 可先驗證 instrumentation 封裝，不需要 Google Cloud：

```bash
cd mobile_desktop_app
bash tool/build_firebase_test_lab.sh
```

產物位於 `build/firebase-test-lab/`。腳本使用鎖定的 Flutter dependencies，並拒絕
`integration_test/` 以外或不符合 `*_test.dart` 的 target。

官方參考：

- [Flutter integration test / Firebase Test Lab](https://docs.flutter.dev/testing/integration-tests#test-in-firebase-test-lab-android)
- [Firebase Test Lab gcloud CLI](https://firebase.google.com/docs/test-lab/android/command-line)
- [gcloud Android run `--async`](https://cloud.google.com/sdk/gcloud/reference/firebase/test/android/run)
- [Test Lab device capacity](https://cloud.google.com/sdk/gcloud/reference/firebase/test/android/list-device-capacities)
- [Testing API matrix cancellation](https://firebase.google.com/docs/test-lab/reference/testing/rest/v1/projects.testMatrices/cancel)
- [Firebase Test Lab IAM](https://firebase.google.com/docs/test-lab/android/iam-permissions-reference)
- [Google GitHub Actions authentication](https://github.com/google-github-actions/auth)
