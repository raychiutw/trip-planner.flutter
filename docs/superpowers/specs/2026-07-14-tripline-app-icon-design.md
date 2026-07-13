# Tripline App Icon 設計規格

## 目標

以 Web 現行品牌木棕色重新設計 Flutter App Icon，取代預設 Flutter 圖示，並綁定 iOS 與 Android 原生資產。

## 視覺

- 圖形：圓角定位圖釘外框，中央為實心指南針箭頭。
- Default：木棕 `#A97A4A` 背景，奶油白 `#FFFBF5` 圖形。
- Dark：棕黑 `#1A140F` 背景，木棕 `#A97A4A` 圖形。
- Tinted：等亮度灰 `#818181` 背景，白色圖形，供系統著色。
- 三種外觀維持完全相同的輪廓與比例；不預先裁圓角，由系統套用遮罩。
- 主圖保留足夠安全邊距，確保 20 px 小尺寸仍可辨識。

## 綁定

- iOS：沿用 `Assets.xcassets/AppIcon.appiconset`，提供 Default、Dark、Tinted 三個 1024×1024 主檔，並更新既有 iPhone/iPad 尺寸。
- Android：沿用既有 `mipmap-* / ic_launcher.png`，使用 Default 版本縮放覆蓋，不新增套件或啟動圖示框架。
- 不變更 Bundle ID、簽章、啟動畫面或 App 內 UI。

## 驗證

- 確認所有 PNG 為正方形、正確像素尺寸且不含 alpha。
- 驗證 Asset Catalog JSON 格式與 iOS 模擬器建置。
- 驗證 Android Flutter build 能讀取各 density 的 launcher icon。
