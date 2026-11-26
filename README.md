# 想唸 · Thoughts Aloud

「想唸」是 Android 與 iOS 的語音卡片 App。卡片匣提供搜尋與收藏，錄音室用示範逐字稿串起暫停、編輯與儲存流程。點開卡片可查看逐字稿、播放進度示範與相同主題的卡片。錄音與播放均為模擬，新增的卡片與收藏只保留在本次執行期間。

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

## 套件清單

[Pub 套件 SBOM](sbom/pub.cdx.json) 與 [Android Gradle 元件 SBOM](sbom/android.cdx.json) 採用 CycloneDX 格式，Pub 元件依鎖檔產生，直接、開發與間接相依關係依 `dart pub deps --json` 核對。Android 清單涵蓋應用與測試組態的 Gradle 解析結果。
