# Tripline Theme 與共用 UI 參考

> 更新：2026-07-24。視覺與互動驗收以 repository root 的 `/design.md` 為唯一 Source of Truth；本文件只說明目前共用元件。

## 取色

- Widget 只從 `Theme.of(context).colorScheme` 取色，不直接引用 Light／Dark 常數。
- adaptive 暖褐 tint 是唯一品牌強調色；舊 `TpTones`、`TpColorsLight/Dark` 與 sage／pink alias 已移除。
- POI、收藏、行程卡與設定列皆使用中性 surface。只有 error／success／warning 與地圖逐日資料視覺化可使用語意色。
- Light／Dark／High Contrast 皆由 `TpSystemColors*` 對應 iOS system semantic roles。

| 語意角色 | Light | Dark | 用途 |
|---|---|---|---|
| background | system background（white） | system background（black） | 頁面底色 |
| secondary | secondary system background | secondary system background | grouped surface |
| tertiary | tertiary system background | tertiary system background | 次級 surface |
| tint | `#8A6038` | `#D0A576` | 選取、link、主要動作 |
| foreground | system label | system label | 主要文字 |
| muted | secondary system label | secondary system label | 次要文字 |
| outline | system separator | system separator | inset separator |

## 字體

不指定 `fontFamily`，使用平台系統字與 Dynamic Type；中文 `letterSpacing` 固定為 `0`。畫面不得以縮小字級處理溢位。

| HIG role | TextTheme | size |
|---|---|---:|
| Title 1 | `displaySmall` | 28 |
| Title 2 | `headlineMedium` | 22 |
| Title 3 | `headlineSmall` | 20 |
| Headline | `titleLarge` | 17 |
| Subheadline / body | `titleMedium` / `bodyLarge` | 15 |
| Footnote | `titleSmall` / `bodyMedium` | 13 |
| Caption 1 | `bodySmall` / `labelMedium` | 12 |
| Caption 2 | `labelSmall` | 11 |

全 App 不提供 Large Title；頁面標題使用 system inline navigation title。

## 導覽

- Root tab 固定四項：聊天、行程、地圖、收藏。
- Account 不建立 root branch；每個內容頁 Header 的 `person.crop.circle` 開啟獨立 Navigation Stack sheet，`/account` deep link 保留。
- 浮動 tab 使用 `AppleRootTabBar`，左右 margin `16`、可見高度 `64`、安全區上方留白由 `TpRootTabGeometry` 統一計算。
- `AppShell` 開啟 `extendBody`。根頁底部淨空一律使用 `TpRootScrollScaffold` 或 `TpRootTabGeometry.clearance(context)`，不得另寫 magic number。
- 最小 tap target `44×44`；selection 使用 haptic；reduced motion 由 `TpMotion.resolve` 處理。

## 行程與地圖

- 行程頁 selector：`DAY 1 | DAY 2...`；地圖頁 selector：`全部 | DAY 1 | DAY 2...`。
- 行程／地圖在 Root Header 互切並保留 Day；切換行程時，原 Day 在新行程存在就保留，否則回 DAY 1。
- 目前行程標題可點擊，開啟含搜尋、目前 checkmark、最近行程的 bottom sheet。
- 預設進入、切換行程、切換 Day 與明確 POI focus 的 zoom 都固定 `13`，避免互動後跳成其他層級。
- POI 卡以 `PageView(viewportFraction: .74)` 左右滑動；滑動只更新預覽，點卡片或 marker 才以 zoom `13` 移動地圖。卡片使用相同中性 surface，底部淨空不得被 root tab 遮住。
- Timeline 景點卡使用四列資訊；卡片 tap 展開備選，`…` 提供六項三組命令。排序只用短按 handle，支援同日與跨 Day drop。
- 日期使用共用 HIG sheet 內的 system calendar；單獨時間使用只含時、分的 time wheel，並跟隨系統 12／24 小時偏好。卡片上的 Google/Apple links 由 `EntryMapLinks` 提供。

## 內容與設定元件

- 內容層使用實色 grouped surface；玻璃只用於 tab、浮動 toolbar 與 sheet。
- 設定頁使用 `TpSettingsGroup`：無外框、無陰影、圓角 grouped surface、內縮 separator。
- 帳號列與通知 switch 使用原生熟悉的 HIG 動線。
- Account 使用有 section header 的 grouped list；compact width 使用近滿版 sheet，一般寬度使用置中 form sheet。
- 外觀固定跟隨系統，Account 不提供外觀覆寫，也不重複提供 Dynamic Type、accessibility、鍵盤或捲動等系統已有的偏好。
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
- `AppSearchField` / `showAppActionSheet` / `showAppConfirm` / `showAppAlert` / `showAppDatePicker` / `showAppTimePicker`：全平台共用 Apple HIG 產品語意。
- `showAppDestructiveConfirm`：破壞性動作的確認,依 `TpDestructiveConfirmSource` 分流 —— 從 `TpMoreMenuButton` 選單選中的走 action sheet(HIG `pull-down-buttons`),左滑刪除、列上按鈕這類直接觸發的走 alert。破壞性確認一律經過這裡,不要自己組 `showAppConfirm`。regular size class 目前回退成 alert（真正的 popover 需要選單觸發鈕的 anchor rect，屬已知限制）。
- `appIsRegularSizeClass`：判定 iPad／大螢幕的唯一規則。需要依 size class 分流時呼叫它,不要各自量 `MediaQuery`。
- `showAppActionSheet` 的抬頭會截行(title 3 行、message 4 行)：抬頭常插入使用者可控的 email／標籤／停留點名稱,不截行的話最大 Dynamic Type 下會撐爆一屏並開始捲動,違反 HIG `action-sheets` 的「Avoid letting an action sheet scroll」。

## 系統權限

`NotificationPermissionService` 是通知設定唯一的 app-owned platform boundary，只提供 `getStatus`、`request` 與 `openSettings`。通知頁初次顯示及從系統設定回到 App 時會同步 OS 狀態，但不會因此要求權限；只有使用者啟用通知時，才先說明具體用途並顯示系統 prompt。拒絕後改顯示持續可見的系統設定入口，不重複要求；狀態讀取失敗可明確重試，未知的原生回傳值採 fail-closed。

## 例外

地圖不同日的 pin／route 可使用 `kDayPinPalette`，因為它是資料視覺化，不是 UI 分類色。App Icon 的座標圖釘識別不因 UI 改版而變更。
