# 想唸 · Thoughts Aloud

「想唸」的 Android 與 iOS Flutter 應用程式。啟動畫面顯示「想唸」。

## 本機開發

建立時使用 Flutter 3.50.0 stable 與 Dart 3.14.0。從專案根目錄執行以下指令，使用 Flutter 可辨識的手機或模擬器。iOS 建置需要 macOS 與 Xcode。

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

## 套件清單

[Pub 套件 SBOM](sbom/pub.cdx.json) 與 [Android Gradle 元件 SBOM](sbom/android.cdx.json) 採用 CycloneDX 格式，分別來自首次建置的 Pub 鎖檔與 Android 應用、測試組態的解析結果。
