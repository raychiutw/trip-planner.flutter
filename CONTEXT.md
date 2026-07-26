# Tripline

trip-planner React SPA 的 iOS/Android 移植版。這份文件只定義本專案討論 UI 時的共同語彙 —— 同一個東西有多種叫法時,挑一個,其餘列在 _避免_。實作細節不寫在這裡。

## 導覽外框(chrome)

**浮動 header**:
浮在內容之上、左右內縮、圓角玻璃的頂部列,由 `TpRootScaffold` 提供,只用於 root 分支畫面(聊天、行程列表、時間軸、行程地圖、總覽地圖、收藏)。
_避免_: app bar、標題列、導覽列

**固定 bar**:
貼齊頂端、佔滿寬度的傳統頂部列,由 `TpAppBar` 提供,用於 detail 與 modal 畫面。
_避免_: app bar、toolbar

**bar button**:
浮動 header 或固定 bar 上的單一動作,呈現為圓形玻璃按鈕。
_避免_: toolbar icon、header icon、action button

**動作群組**:
共用同一片玻璃容器的多個相關 bar button,彼此**僅以間距分隔,不畫分隔線**。不相關的動作(例如帳號)另起一顆容器。一列最多約三組。
_避免_: action row、button group

註:選單**內部**的分組分隔線是另一回事,那屬選單語彙,HIG 明文允許。

**root tab bar**:
底部四個一級分頁(聊天 / 行程 / 地圖 / 收藏)的玻璃列。
_避免_: bottom nav、navigation bar

## 內容控制項

**日期選擇器**:
時間軸與地圖上方那條水平捲動的天數切換列(Day 1、Day 2…),由 `TpHorizontalSelector` 提供。
_避免_: day tab、日期 tab、segmented control

**選單**:
由 bar button 或卡片上的「⋯」觸發、由觸發點展開的下拉動作清單(對應 iOS pull-down menu)。
_避免_: popup menu、dropdown、context menu(後者專指長按觸發的那一種)

**行程切換鈕**:
浮動 header 標題位置的按鈕,點擊後開出切換行程的 sheet。
_避免_: title button、trip picker

## 視覺語彙

**tint**:
品牌柔褐,唯一的品牌強調色。用於前景 —— 文字、字符、選取指示。不畫成框線。

**沒有例外 —— tint 一律在前景。** 包含 root tab bar 的選取膠囊:膠囊本身走中性語意層,
tint 上在字符與標籤。這與 iOS 26 一致 —— 「電話」app 通話記錄分頁的選取膠囊實測是
`#363636`(中性灰,比容器亮約 20 階),字符與標籤才是系統藍。
見 `docs/adr/0004-neutral-selection-surface-with-tinted-foreground.md`。
_避免_: 主色、primary、強調色

**中性語意層**:
跟隨 iOS 系統語意層級的表面色(`surface` / `surfaceContainerLow` / `surfaceContainerHigh`)。所有內容表面與玻璃底色都走這一層。
_避免_: 背景色、surface color

**媒體背景**:
玻璃底下是照片或地圖圖磚的情境。此時 bar button 字符走白 / label 色,而非 tint。
_避免_: platform view 背景、透明背景
