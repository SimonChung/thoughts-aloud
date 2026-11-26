# 想唸 · Thoughts Aloud

「想唸」是 Android 與 iOS 的語音卡片 App。點「開始錄音」後即可使用麥克風記下想法，過程中可暫停、繼續，或在完成後編輯標題與逐字稿。儲存後可播放原音、收藏，以及透過標題、逐字稿或主題搜尋。內建四張範例卡片提供播放進度示範。

## 首次使用語音辨識

錄音需要麥克風權限。即時逐字稿還需要系統的**裝置端語音辨識服務**，以及該服務用來聽懂指定語言的**離線語言模型**。手機即使已有辨識服務，仍可能需要下載台灣華語模型。模型由作業系統的辨識服務管理，就緒後可在裝置上離線轉錄。

### Android 手機與平板

本版的即時轉錄需要 Android 13 以上，以及能接收錄音串流的本機辨識服務。

1. 先連上網路。要錄台灣華語，請確認「想唸」顯示繁體中文。英文介面會使用美式英語辨識。
2. 點「開始錄音」，允許麥克風權限。App 會查詢系統提供的語言模型，優先使用已安裝的版本。若系統提供對應模型但尚未安裝，App 會請系統下載，通常不需要手動安裝語音套件。
3. 等畫面顯示「錄音中」再說話，文字會出現在「即時逐字稿」。若想立刻開始，可以在準備期間點「先只錄音」，完成後手動補稿或只儲存原音。下次開始新錄音時，App 會再檢查模型。

例如，已通過繁中逐字稿實測的 Redmi Pad SE 8.7 4G，系統將台灣華語模型列為 `cmn-Hant-TW`。App 會將繁中介面的 `zh-TW` 配對到這個模型，使用者不必輸入代碼。

若能錄音卻沒有逐字稿，請先確認 App 的語言，連網後再開始一段新錄音。若裝置使用 Android 12 或更舊版本，或系統沒有提供相容的辨識服務或語言模型，仍可錄音並手動填寫逐字稿。

### iPhone 與 iPad

第一次點「開始錄音」時，請允許麥克風權限。若 iOS 顯示語音辨識授權提示，也請允許。App 使用 iOS 提供的裝置端辨識，語言模型由系統管理。若曾拒絕權限，可以到系統「設定」中調整。裝置或語言缺少本機辨識支援時，仍可保留原音並手動填稿。

## 錄音與資料保存

- 錄音進入背景時會暫停。返回 App 後可手動繼續。已儲存的音檔、文字與收藏可在離線或重新啟動後使用。
- 每段錄音由建立它的裝置產生 UUID。儲存時將音檔與文字一起從草稿移入 App 私有卡片匣。捨棄會清除該草稿。各安裝獨立寫入本機檔案，目前沒有中央服務、跨裝置同步或匯入合併功能。

## 語言

App 跟隨系統語言，支援繁體中文與英文。當系統的偏好語言都無法匹配時，使用英文。在支援個別 App 語言的 Android 與 iOS 版本，也可以從系統設定單獨選擇「想唸」的語言。範例卡片會隨語言切換，自己儲存的標題與逐字稿保留原文。

Flutter 翻譯檔位於 `lib/l10n/app_en.arb` 與 `lib/l10n/app_zh.arb`。更新文案後可執行 `flutter gen-l10n` 重新產生 Dart 資源。

## 本機開發

建立時使用 Flutter 3.50.0 stable 與 Dart 3.14.0。從專案根目錄執行以下指令，使用 Flutter 可辨識的手機或模擬器。iOS 建置需要 macOS 與 Xcode。

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

### iPhone 模擬器專用：台灣華語即時逐字稿

以下是 iPhone 17 模擬器（iOS 27.2，24B8117）的開發測試做法。實體 iPhone、iPad 請依上方的首次使用說明授權，由 iOS 管理語音模型。

這次模擬器已下載台灣華語模型，但辨識器讀取的 `AssetData` 目錄只有 `Restore`，找不到 `mini.json`，錄音時回報 `kLSRErrorDomain 300`。展開原始映像後，辨識器雖然讀得到設定，卻只能找到為 iPhone 晶片編譯的 `H18.bundle`，語音服務隨即中止。測試時改用 Apple 較早發布的完整 `zh-TW` 離線模型（EmbeddedSpeech，build `9M5258`）。

1. 建立專用測試模擬器，將 App 語言設為繁體中文。若是全新模擬器，可在該模擬器內的 Swift 測試工具呼叫 `try await prepareTaiwanMandarin()`，等系統下載台灣華語資產。

   ```swift
   import Speech

   func prepareTaiwanMandarin() async throws {
       let transcriber = DictationTranscriber(
           locale: Locale(identifier: "zh_TW"), preset: .progressiveLongDictation)
       if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
           try await request.downloadAndInstall()
       }
   }
   ```

2. 用 `xcrun simctl list devices` 確認該模擬器的 UDID。於 `~/Library/Developer/CoreSimulator/Devices/<UDID>/data/private/var/MobileAsset/AssetsV2/com_apple_MobileAsset_UAF_Siri_Understanding/purpose_auto/` 下，找出 `Info.plist` 的 `CFBundleName` 為 `com.apple.siri.asr.assistant.zh_TW` 的 `.asset` 目錄。
3. 下載 Apple 目錄中 `Language=zh-TW`、`Build=9M5258` 的 ZIP。以 `shasum -a 256` 核對下載檔，這次實測的 SHA-256 為 `c429fe0959953cccc85f082207e8cc83fce22b97200b4c2b39984ced651dd4c0`。[Apple 模型目錄](https://mesu.apple.com/assets/com_apple_MobileAsset_EmbeddedSpeech/com_apple_MobileAsset_EmbeddedSpeech.xml) · [Apple 模型下載](https://updates.cdn-apple.com/2021/mobileassets/001-83640/F6750AFC-60FA-4929-92ED-90BE91BD3EE1/com_apple_MobileAsset_EmbeddedSpeech/c76ec47d61a36d7ac2e383a4d321d425f8396132.zip)
4. 用 `xcrun simctl shutdown <UDID>` 關閉該模擬器。在步驟 2 找到的 `.asset/AssetData/` 內保留原始 `Restore/`，將其餘既有模型檔移到模擬器外備份。解壓 ZIP，將 `AssetData/cmn-TWN-OfflineIOS-7.0.0.0-20201207-9d9965f45/` **裡面的全部內容**複製進目標 `AssetData/`。完成後，`mini.json`、`AM-RFDNN/` 和 `Restore/` 應位於同一層。
5. 用 `xcrun simctl boot <UDID>` 重新啟動，開啟「想唸」並允許麥克風與語音辨識。開始錄音，在按「完成錄音」前確認「即時逐字稿」隨語音更新，再儲存卡片核對文字。重置模擬器或系統更新模型後，可能需要重新套用。

**重測結果**（2026-11-27，App 提交 `88876b8`）

測試將兩段台灣華語合成音訊輸入模擬器的錄音回呼，由 App 的 `SFSpeechRecognizer` 即時辨識。「首次顯示文字」取自錄音尚在進行時的畫面，時間為當時的累積錄音長度。音訊循環播放，因此卡片末尾含有重複片段。

| 測試語音 | 首次顯示文字 | 儲存後核對 |
| --- | --- | --- |
| 今天是星期五，我想喝一杯咖啡。請幫我記錄這段語音。 | 1.5 秒，顯示「今天是」 | 卡片保留逐字稿，「記錄」誤辨為「進入」。 |
| 明天下午三點，我要搭火車去台北，記得帶藍色的雨傘。 | 2.0 秒，顯示「明天」 | 卡片保留完整句子。 |

2026-11-27 在已套用上述模型的 iPhone 17 模擬器（iOS 27.2）手動實測「想唸」，確認錄音正常，繁中即時逐字稿也會在說話時持續更新。

## 套件清單

[Pub 套件 SBOM](sbom/pub.cdx.json) 與 [Android Gradle 元件 SBOM](sbom/android.cdx.json) 採用 CycloneDX 格式，Pub 元件依鎖檔產生，直接、開發與間接相依關係依 `dart pub deps --json` 核對。Android 清單涵蓋應用與測試組態的 Gradle 解析結果。
