# Tripline Theme 與共用 UI 參考

> 更新：2026-07-21。視覺驗收以 [`discovery/design.md`](discovery/design.md) 與 [`2026-07-21-trip-entry-card-menu-keyboard-glass.md`](superpowers/plans/2026-07-21-trip-entry-card-menu-keyboard-glass.md) 為準。

## 取色

- Widget 只從 `Theme.of(context).colorScheme` 或 `TpTones` 取色，不直接引用 Light／Dark 常數。
- 柔褐 accent 是唯一品牌強調色；sage／pink 只保留舊 API 相容別名，現在映射到中性色。
- POI、收藏、行程卡與設定列皆使用中性 surface。只有 error／success／warning 與地圖逐日資料視覺化可使用語意色。
- Dark 是獨立中性深色 palette，不是 Light 反色。

| Token | Light | Dark | 用途 |
|---|---|---|---|
| background | `#FFFBF5` | `#1C1C1E` | 頁面底色 |
| secondary | `#FAF4EA` | `#2C2C2E` | grouped surface |
| tertiary | `#F2EAD9` | `#3A3A3C` | 次級／選取 surface |
| accent | `#A97A4A` | `#CBA06E` | 選取、主要動作 |
| foreground | `#2A1F18` | `#F5F5F7` | 主要文字 |
| muted | `#6F5A47` | `#A1A1A6` | 次要文字 |
| border | `#EADFCF` | `#38383A` | inset separator |

## 字體

不指定 `fontFamily`，使用平台系統字與 Dynamic Type；中文 `letterSpacing` 固定為 `0`。畫面不得以縮小字級處理溢位。

| HIG role | TextTheme | size |
|---|---|---:|
| Large title | `displaySmall` | 34 |
| Title 1 | `headlineMedium` | 28 |
| Title 2 | `headlineSmall` | 22 |
| Title 3 | `titleLarge` | 20 |
| Headline / body | `titleMedium` / `bodyLarge` | 17 |
| Subheadline | `titleSmall` / `bodyMedium` | 15 |
| Footnote | `bodySmall` / `labelMedium` | 13 |
| Caption 1 | `labelSmall` | 12 |

## 導覽

- Root tab 固定五項：聊天、行程、地圖、收藏、帳號。
- Account 是第 5 branch；其他 root Header 不再重複 avatar，`/account` deep link 保留。
- 浮動 tab 使用 `AppleRootTabBar`，左右 margin `16`、可見高度 `64`、安全區上方留白由 `TpRootTabGeometry` 統一計算。
- `AppShell` 開啟 `extendBody`。根頁底部淨空一律使用 `TpRootScrollScaffold` 或 `TpRootTabGeometry.clearance(context)`，不得另寫 magic number。
- 最小 tap target `44×44`；selection 使用 haptic；reduced motion 由 `TpMotion.resolve` 處理。

## 行程與地圖

- 行程頁 selector：`DAY 1 | DAY 2...`；地圖頁 selector：`總覽 | DAY 1 | DAY 2...`。
- 行程／地圖在 Root Header 互切並保留 day；切換到另一行程預設回 DAY 1。
- 目前行程標題可點擊，開啟含搜尋、目前 checkmark、最近行程的 bottom sheet。
- 預設進入、切換行程、切換 Day 與明確 POI focus 的 zoom 都固定 `13`，避免互動後跳成其他層級。
- POI 卡以 `PageView(viewportFraction: .74)` 左右滑動；滑動只更新預覽，點卡片或 marker 才以 zoom `13` 移動地圖。卡片使用相同中性 surface，底部淨空不得被 root tab 遮住。
- Timeline 景點卡使用四列資訊；卡片 tap 展開備選，`…` 提供六項三組命令。排序只用短按 handle，支援同日與跨 Day drop。
- 起訖時間使用 compact chips 與平台 picker；卡片上的 Google/Apple links 由 `EntryMapLinks` 提供。

## 內容與設定元件

- 內容層使用實色 grouped surface；玻璃只用於 tab、浮動 toolbar 與 sheet。
- 設定頁使用 `TpSettingsGroup`：無外框、無陰影、圓角 grouped surface、內縮 separator。
- 帳號列、通知 switch、外觀 checkmark 均使用原生熟悉的 HIG 動線。
- 卡片不靠彩色分類表達資訊；階層以字重、留白與 separator 建立。
- Navigation regular glass 使用 Light/Dark alpha `.40/.48`，PlatformView 使用 `.56/.62`，High Contrast 使用 `.96` opaque fallback；內容卡不套 glass。

## 共用 primitive

- `TpHorizontalSelector`：行程／地圖與 day 的單層 selector。
- `TripTitleButton`：目前行程標題與切換 sheet。
- `TpSettingsGroup` / `TpSettingsRow`：帳號設定分組。
- `TpContentSurface`：實色內容卡。
- `TpGlassSurface`：僅限浮動功能層。
- `EntryMapLinks`：景點 Google／Apple 導航。
- `SwipeToDelete`：左滑只揭露紅色刪除，點擊後才進確認。
- `AppKeyboardDismissRegion`：全 App 點外部／拖曳收鍵盤並保留草稿。
- `AppSearchField` / `showAppActionSheet` / `showAppConfirm` / `showAppTimePicker`：平台自適應互動。

## 例外

地圖不同日的 pin／route 可使用 `kDayPinPalette`，因為它是資料視覺化，不是 UI 分類色。App Icon 的座標圖釘識別不因 UI 改版而變更。
