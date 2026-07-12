# Tripline iOS 全面設計收斂

## 目標

將 2026-07-12 完整 iOS 設計審查的 30 項發現全部落地，讓核心旅程工作流更接近 Apple Music 的內容優先層級，以及 Nintendo Switch 家長監護的摘要先行與低認知負擔。

## 範圍

涵蓋登入、聊天、行程清單、建立／編輯、時間軸、地圖、筆記、列印、收藏／探索、帳號與設定、登入裝置、OAuth 應用及深色模式。完整發現與畫面證據位於 `~/.gstack/projects/trip-planner-flutter/designs/design-audit-20260712/design-audit-tripline-ios.md`。

## 設計原則

1. 一個畫面只保留一個主要動作；低頻工具收進選單或次級流程。
2. 卡片只用於可整體點擊的內容物件；設定、表單與分類使用原生 grouped/list 結構。
3. 摘要先回答使用者當下最需要知道的狀態，再提供統計或細節。
4. 不向一般使用者暴露 epoch、ISO UTC、IP 指紋、SEO、OAuth 類型等內部表示。
5. 所有互動目標至少 44 pt，所有地圖標記與選單具有可讀語意。
6. 深色模式使用多層 surface 與中性文字，不以純黑加深棕完成反相。

## 實作方式

- 沿用 Material 3、Riverpod、GoRouter 與現有 adaptive 元件。
- 共用日期格式使用現有 `intl`，不新增 dependency。
- 先以 widget test 固化資料格式、文字、語意與主要結構，再做最小 UI 修改。
- 地圖總覽預設單日，總覽以聚合／減量方式避免標記重疊；marker 補完整 semantics。
- AI 回覆保留原資料，但以摘要、可展開細節與動作 chips 呈現。
- 表單文案改成使用者語言，現有 API payload 與資料模型不變。

## 驗收

- 30 項 finding 全部能對應到程式變更或明確刪除的不必要 UI。
- `flutter analyze` 無問題，完整 `flutter test` 通過。
- iOS 模擬器重新走查五個主分頁、時間軸、地圖、帳號安全頁及深色模式。
- 工作流中的建立、儲存、撤銷與登出仍保持原行為；設計修正不改 API contract。

## 非目標

- 不更換品牌色、路由架構、狀態管理或後端 API。
- 不新增圖片素材、第三方 UI 套件或自製 design-system framework。
