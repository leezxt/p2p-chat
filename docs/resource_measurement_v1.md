# V1 資源量測

本文件記錄 V1 手機端可重現的資源檢查。門檻來自規格 §21：

- App process 冷啟動 3 秒內。
- 前景閒置記憶體低於 150MB。
- App 進入背景後不保持 P2P 長連線。
- 前景 Presence heartbeat 最快每 60 秒一次。

## Runner

建立 profile APK、啟動 Android 裝置後執行：

```powershell
cd mobile_desktop_app
flutter build apk --profile --target-platform android-x64
.\tool\measure_android_resources.ps1 `
  -Device emulator-5554 `
  -ApkPath build\app\outputs\flutter-apk\app-profile.apk `
  -ClearAppData
```

Runner 會以 `am start -W -S` 執行五次 process-cold launch，等待前景閒置取樣，
再將 App 切到背景至少 65 秒，量測 PSS、App UID 的 established TCP 連線數及
網路 byte 增量。機器可讀 JSON 與 Markdown 摘要輸出至
`mobile_desktop_app/build/v1-android-resources/`。

自動冷啟動 gate 使用五次中位數，同時保留最大值。原規格沒有定義百分位語意，
因此真機 release 驗收仍需同時檢查完整樣本與最大值。

## Android 15 AVD 基線

環境：`sdk_gphone64_x86_64`、API 35、profile APK 0.1.0（64.0MB）、backend
不可用，每次量測前清除 App data。

| 量測項目 | 第一次 | 第二次 | 自動門檻 |
|---|---:|---:|---:|
| 冷啟動完整樣本（ms） | 3275, 2614, 2774, 2572, 2646 | 3067, 2690, 2644, 2860, 2588 | 完整記錄 |
| 冷啟動中位數 | 2646ms | 2690ms | <= 3000ms |
| 冷啟動最大值 | 3275ms | 3067ms | 真機再確認 |
| 前景閒置 PSS | 110.22MB | 111.54MB | <= 150MB |
| 背景 65 秒 PSS | 115.93MB | 117.21MB | 資訊性數據 |
| 背景 established TCP | 0 | 0 | 0 |
| 背景網路增量 | 無 UID 紀錄，無法判定 | 0 bytes | 資訊性數據 |

兩次 AVD 都通過中位數冷啟動、閒置記憶體及背景連線自動檢查。但兩次最大冷啟動
樣本都超過 3 秒，因此 AVD 結果只作為開發基線，不是 V1 release gate。

## 剩餘發布量測

- 至少在兩台 Android 真機重跑相同 profile 或 release candidate APK，其中一台應為
  較低記憶體裝置。
- 分別在重開機後及一般 cache warm-up 後重複冷啟動量測。
- 在充飽電且拔除電源的真機執行長時間前景／背景情境並量測耗電；Emulator 電量
  數據沒有實際意義。
- 使用真實 Wi-Fi／行動網路切換重跑，記錄背景 bytes 並確認沒有 WebRTC 長連線。
- 可用相容的 Xcode/iOS 實機環境後，補上 iPhone 啟動、記憶體、背景網路與 energy
  結果。

完成真機與耗電結果前，V1-03 維持未完成。
