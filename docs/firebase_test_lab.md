# Firebase Test Lab Android 真機驗收

本專案使用 Firebase Test Lab 的 Android instrumentation test，在不持有本機手機的情況下
執行遠端實體裝置驗收。Workflow 只允許從 `main` 手動啟動，且送測前會查詢 Test Lab
catalog，拒絕 virtual model 或不支援的 model/version 組合。

Workflow 預設只執行免費 preflight，不建立 Test Lab matrix。Preflight 會建置 APK、以
GitHub OIDC 驗證 WIF、查詢實體裝置 catalog，並對 results bucket 寫入後刪除一個探測
物件。只有手動將 `submit_test` 設為 `true` 才會提交可能產生費用的實體裝置測試。

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
4. 建立 Workload Identity Pool／Provider，attribute condition 至少限制
   `assertion.repository == 'leezxt/p2p-chat'` 與 `assertion.ref == 'refs/heads/main'`，並只
   允許該 principal 以 `roles/iam.workloadIdentityUser` impersonate 上述 service account。
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
```

記錄 physical model 的 `MODEL_ID` 與其 `supportedVersionIds`。Test Lab catalog 會變動，
因此 repository 不硬編碼特定手機；每次手動執行 workflow 時輸入 model、version 與
locale。若 catalog 回傳的 `form` 不是 `PHYSICAL`，workflow 會在付費送測前失敗。

## 執行

在 GitHub Actions 選擇 **Firebase Test Lab Android**，使用 `main` 執行並填入：

- `device_model`：physical `MODEL_ID`
- `android_version`：該 model 支援的 `OS_VERSION_ID`，且不得低於 API 24
- `locale`：預設 `zh_TW`
- `submit_test`：預設 `false`；確認裝置、10 分鐘 timeout 與可能費用後才設為 `true`

也可使用 GitHub CLI：

```bash
gh workflow run firebase-test-lab.yml \
  --ref main \
  -f device_model=<MODEL_ID> \
  -f android_version=<OS_VERSION_ID> \
  -f locale=zh_TW \
  -f submit_test=false
```

Dry-run 會建立 debug app/test APK、SHA-256、catalog JSON、bucket preflight log，並保存為
7 天 GitHub artifact，但不會建立 Test Lab matrix。`submit_test=true` 時才會額外保存 Test
Lab submission log；詳細裝置 logs、影片與 screenshots 位於設定的 results bucket，且
`gcloud` 只有 exit code `0` 才算通過。

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
- [Firebase Test Lab IAM](https://firebase.google.com/docs/test-lab/android/iam-permissions-reference)
- [Google GitHub Actions authentication](https://github.com/google-github-actions/auth)
