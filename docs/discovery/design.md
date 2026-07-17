# Tripline 設計系統解析 → Flutter ThemeData 對應

> 權威來源優先序：`css/tokens.css` `@theme`（實作 canonical）↔ `DESIGN.md`（規範）。`docs/design-sessions/2026-06-06-three-color-system.md` 是探索 spec（標註「尚未實作」），**現已落地進 tokens.css（v2.53+），少數 dark 色值以 tokens.css 為準**（如 dark sage-deep：doc `#A4CBAF` → 實際 `#A8D0B4`；dark 粉 subtle/bg 改加強版 `#4A2A3A`/`#6B3F52`）。

> 本檔保留 Web → Flutter 的來源調查與早期建議，不是 Flutter 現行 UI 的 source of truth。現行規格已改為系統字、`768px` 起使用 `NavigationRail`、平台自適應控制項與持續錯誤 banner；請以 [`reference-theme.md`](../reference-theme.md) 與 [`explanation-adaptive-ui.md`](../explanation-adaptive-ui.md) 為準。

---

## 1. DESIGN.md 摘要

### 品牌定位
- Warm editorial（明信片/旅遊雜誌暖排版）：奶油底 `#FFFBF5` + 柔褐焦糖 `#A97A4A`。**2026-06 起主色從 terracotta `#D97848` 換為柔褐 `#A97A4A`**（mamahoikuen.jp 參考）。
- Restrained 裝飾：靠排版、留白、hairline、三色支撐；**禁 gradient 裝飾、emoji、decorative SVG、rainbow 類型色**。

### 三色系統（2026-06，tone v2.53）— 記憶法「玩/看/買=柔褐、住/移動=sage、吃=粉」
| Tone | 角色 | POI 類型 | 用途 |
|---|---|---|---|
| `accent` 柔褐 | 唯一 UI chrome 主色 | 景點/購物/活動 | CTA、active、link、rating |
| `accent-2` sage 綠 | 第二色 | 住宿/交通/停車/移動 | travel pill（描邊式：透明底+sage 邊框字）、connector |
| `accent-3` 玫瑰粉 | 第三色 | 用餐/咖啡 | 備選、收藏/愛心（永遠粉） |
| `neutral` | 中性 | 休息/未分類→accent | `line-strong` 描邊 |

每 tone 4 階：`base / deep / subtle / bg`。卡片套色階梯：卡底 `-subtle` → icon 底 `-bg` → glyph/描邊 `-deep`（同色相由淺到深 ghost icon）。三色各司其職不交叉。非-POI 頁可作 categorical 用色（行程一覽=目的地、聊天=角色、帳號=分區）。**例外**：地圖 polyline / Map page day tab 可用 10 色 Tailwind -500 palette（data visualization 例外）；semantic 色（error/success/warning/info）不用三色。

### 字體
- `Inter`（400/500/600/700）→ `Noto Sans TC` → `PingFang TC / Microsoft JhengHei / system-ui`。
- 中文內文 ≥16px、行高 26px 不壓縮；中文 letter-spacing 0；eyebrow uppercase `0.12em`；時間日期一律 tabular-nums。

### 圓角 / 間距 / 無框線 / Dark mode
- Radius：xs 4 / sm 6 / **md 8（主力，卡片+按鈕）** / lg 12 / xl 16 / full pill。
- Spacing：4px grid（2/4/8/12/16/20/24/32/40/48/64）；chip/pill 內距可例外用 6/10/14/18。tap 最小 44×44。
- **Hairline over shadow**：卡片區分用 1px border（light `#EADFCF`），shadow 只給浮層（toast/sheet/dialog）。
- Dark mode：`body.dark` 全 token 覆寫 — 暖褐黑底 `#1A140F`、accent 調亮 `#CBA06E`、`accent-foreground` 反轉為深色 `#1A140F`、shadow 用純黑加重。Sidebar 兩 mode 都固定深棕（light `#2A1F18` / dark `#0F0B08`）。

---

## 2. tokens.css 完整 token

### 色彩（Light / Dark）
| Token | Light | Dark |
|---|---|---|
| accent | `#A97A4A` | `#CBA06E` |
| accent-deep | `#8A6038` | `#E0BC90` |
| accent-subtle | `#F4EDE3` | `#33271A` |
| accent-bg | `#E9DBC8` | `#44341F` |
| accent-2 (sage) | `#A8BAAA` | `#8FBE9C` |
| accent-2-deep | `#7E9580` | `#A8D0B4` |
| accent-2-subtle | `#ECF0ED` | `#243A2C` |
| accent-2-bg | `#D4DDD5` | `#2E3D30` |
| accent-3 (pink) | `#E78C99` | `#E8A0AB` |
| accent-3-deep | `#C66B78` | `#F0B8C0` |
| accent-3-subtle | `#FAF1F3` | `#4A2A3A` |
| accent-3-bg | `#F2DBE0` | `#6B3F52` |
| background | `#FFFBF5` | `#1A140F` |
| secondary (card bg) | `#FAF4EA` | `#241B14` |
| tertiary (input/recessed) | `#F2EAD9` | `#2E2418` |
| hover | `#F9EDE0` | `#2D2218` |
| foreground | `#2A1F18` | `#F5EBDD` |
| muted | `#6F5A47` | `#B89E84` |
| accent-foreground | `#FFFFFF` | `#1A140F` |
| border (hairline) | `#EADFCF` | `#3D2D22` |
| line-strong | `#C8B89F` | `#5A4634` |
| destructive | `#C13515` | `#E8A0A0` |
| destructive-bg | `#FDECEC` | `rgba(232,160,160,.15)` |
| success | `#06A77D` | `#7EC89A` |
| warning | `#F48C06` | `#FAA94B` |
| info | `#A97A4A` | `#CBA06E` |
| disabled | `#B8AC9B` | `#5A4634` |
| overlay | `rgba(42,31,24,.35)` | `rgba(0,0,0,.65)` |
| sidebar-bg | `#2A1F18` | `#0F0B08`（固定深棕，字 `#FFFBF5`） |
| priority high/med/low dot | `#C13515` / `#F48C06` / `#06A77D` | `#E8A0A0` / `#F0D060` / `#7EC89A` |

### Radius / Shadow / Spacing / 字級
- **Radius**：xs 4px、sm 6px、md 8px、lg 12px、xl 16px、full 9999px。
- **Shadow（暖棕 Airbnb 三層；dark 用純黑）**：
  - sm `0 1px 2px rgba(42,31,24,.05)`（dark `rgba(0,0,0,.30)`）
  - md `0 6px 16px rgba(42,31,24,.09)`（dark `.42`）
  - lg `0 10px 28px rgba(42,31,24,.12)`（dark `.55`）
  - focus ring `0 0 0 2px accent`
- **Spacing**：1=4 / 2=8 / 3=12 / 4=16 / 5=20 / 6=24 / 8=32 / 10=40；padding-h 16、tap-min 44、nav-h 48、mobile bottom nav 88、sidebar 240、titlebar 64（compact 56）。
- **字級（HIG scale）**：large-title 34px / title 28 / title2 22 / title3 20 / headline 17 / body 16 / callout 16 / subheadline 15 / footnote 14 / caption 12 / caption2 11 / eyebrow 10。Weight：500/600/700。Line-height：tight 1.2 / normal 1.5 / relaxed 1.7。
- **Motion**：fast 150ms / normal 250ms / slow 350ms；Apple curve `cubic-bezier(.2,.8,.2,1)`、spring `cubic-bezier(.32,1.28,.6,1)`、sheet close `cubic-bezier(.4,0,1,1)`；sheet open 420ms / close 280ms。
- **Glass**：blur 14px（titlebar/bottom-nav/sheet）；小浮動按鈕（≤32px）blur 6px。

---

## 3. Flutter 對應表

### ColorScheme ↔ token
| ColorScheme 欄位 | Token | Light | Dark |
|---|---|---|---|
| `primary` | accent | `#A97A4A` | `#CBA06E` |
| `onPrimary` | accent-foreground | `#FFFFFF` | `#1A140F` |
| `primaryContainer` | accent-bg | `#E9DBC8` | `#44341F` |
| `onPrimaryContainer` | accent-deep | `#8A6038` | `#E0BC90` |
| `secondary` | accent-2 (sage) | `#A8BAAA` | `#8FBE9C` |
| `secondaryContainer` | accent-2-bg | `#D4DDD5` | `#2E3D30` |
| `onSecondaryContainer` | accent-2-deep | `#7E9580` | `#A8D0B4` |
| `tertiary` | accent-3 (pink) | `#E78C99` | `#E8A0AB` |
| `tertiaryContainer` | accent-3-bg | `#F2DBE0` | `#6B3F52` |
| `onTertiaryContainer` | accent-3-deep | `#C66B78` | `#F0B8C0` |
| `surface` | background | `#FFFBF5` | `#1A140F` |
| `surfaceContainerLow` | secondary | `#FAF4EA` | `#241B14` |
| `surfaceContainerHigh` | tertiary | `#F2EAD9` | `#2E2418` |
| `onSurface` | foreground | `#2A1F18` | `#F5EBDD` |
| `onSurfaceVariant` | muted | `#6F5A47` | `#B89E84` |
| `outline` | line-strong | `#C8B89F` | `#5A4634` |
| `outlineVariant` | border (hairline) | `#EADFCF` | `#3D2D22` |
| `error` | destructive | `#C13515` | `#E8A0A0` |
| `errorContainer` | destructive-bg | `#FDECEC` | `#E8A0A0` 15% |
| `scrim` | overlay | `#2A1F18` 35% | 黑 65% |
| ThemeData `disabledColor` | disabled | `#B8AC9B` | `#5A4634` |
| ThemeData `hoverColor` | hover | `#F9EDE0` | `#2D2218` |

補充語意色（建議放 `ThemeExtension`，三色 4 階 + success/warning/info/priority 全進去；subtle 階沒有對應 ColorScheme 欄位，必須自訂）。

### TextTheme ↔ 字級（`fontFamily: 'Inter'`, `fontFamilyFallback: ['Noto Sans TC','PingFang TC','Microsoft JhengHei']`）
| TextTheme 欄位 | 角色 | size/height/weight |
|---|---|---|
| `displaySmall` | large-title | 34 / w700 |
| `headlineMedium` | page-title | 28（compact 24）/ height 36/28≈1.29 / w700 |
| `titleLarge` | titlebar·section-title | 20（compact 18）/ w700 |
| `titleMedium` | card-title | 17（compact 16）/ height 24/17≈1.41 / w700 |
| `bodyLarge` | body 中文內文 | 16 / height 26/16=1.625 / w400, `letterSpacing: 0` |
| `bodyMedium` | support/footnote | 14 / height 22/14≈1.57 / w400 |
| `bodySmall` | caption2（rail sub） | 11 / w400, tabular-nums |
| `labelLarge` | 按鈕 | 16 / w600 |
| `labelMedium` | label/chip | 12 / height 16/12≈1.33 / w600 |
| `labelSmall` | bottom-nav label | 11 / w700 |
| 自訂 eyebrow style | `DAY 01` | 10 / w600 / `letterSpacing: 0.12em`（=1.2）/ uppercase |

時間/日期文字加 `fontFeatures: [FontFeature.tabularFigures()]`。

### 卡片 / 按鈕 / Chip
| 元件 | Flutter 規格 |
|---|---|
| **Card（CardTheme）** | `elevation: 0`、radius **8**（卡片 md；hero/side card 12）、無 Material 陰影 — **hairline 原則**：`shape: RoundedRectangleBorder(side: BorderSide(color: outlineVariant, width: 1))`。POI 卡依 tone：bg=`-subtle`、border=`-bg`；「現在進行」卡 → shadow-md `BoxShadow(offset:(0,6), blur:16, rgba(42,31,24,.09))` + accent-subtle 底；過去卡 opacity 0.65/0.55 |
| **主按鈕（FilledButton）** | bg=primary、fg=onPrimary、radius **8**、`minimumSize: Size(0,44)`、padding 10×20、text 16/w600；pressed/hover → accent-deep |
| **次按鈕（OutlinedButton）** | 透明/底色背景 + 1px border `--color-border`、radius 8、minHeight 44 |
| **Ghost（TextButton）** | 透明、無 border、hover/splash = `--color-hover` |
| **Destructive** | outline：紅字紅框透明底；filled：destructive 底白字。確認一律走 AlertDialog（radius 16=xl、shadow-lg、按鈕 **pill radius-full** minHeight 44、barrier `rgba(20,14,9,.42)`） |
| **Pill action（`.tp-action-btn`）** | `StadiumBorder`（radius full）、minHeight 36、padding 8×14、text 14/w600、accent 填滿 |
| **Chip（ChipTheme）** | `StadiumBorder`、label 12/w600、bg=accent-subtle、selected=tone 自身色（CategoryPicker 三色 legend）、無 elevation；filter chip 用 `aria-pressed` 語意 → Flutter `FilterChip.selected` |
| **Input（InputDecorationTheme）** | filled、fillColor=secondary、radius **12（lg）**、border 1.5px `--color-border`、focus：accent 1.5px + `boxShadow 0 0 0 3px accent-subtle`（用 focusedBorder + 外層 ring）、contentPadding 12×14、minHeight 44、字 16（iOS 防 zoom 底線） |
| **Toast/SnackBar** | 白底（dark: secondary）+ 1px 狀態色 34% border + 8px 狀態色圓點、radius 12、shadow-md、text 14/w500 |

### 5-tab BottomNavigationBar
- **Tabs（順序固定）**：聊天 / 行程 / 地圖 / 收藏 / 帳號。子頁 active 歸所屬主功能（探索→收藏），不當 breadcrumb。
- 建議 `NavigationBar`（M3）或自訂：
  - `height`: 72–88（含 `SafeArea` bottom inset；CSS `--nav-height-mobile: 88px`）
  - 背景：`surface` 92–97% opacity + `BackdropFilter(blur: 14)`（玻璃感）；頂部 1px hairline（`outlineVariant`），**無陰影**
  - Active：icon+label = `primary`（柔褐）、label w700、柔褐淡底 pill（`accent-subtle` 的 `indicatorColor`）+ 頂部 2px accent indicator（自訂 stack 線條）
  - Inactive：`onSurfaceVariant`（muted）、label w500
  - icon 18–20px、label 11px、item min 44px tap target
  - 行為：向下捲動隱藏、向上捲動顯示（`ScrollController` direction → `AnimatedSlide` 200ms `Curves(.2,.8,.2,1)`）
- Desktop ≥1024 不適用（web 是 sidebar）；Flutter 行動版恆用 bottom nav 即可。

### Motion 對應
```dart
const appleEase = Cubic(0.2, 0.8, 0.2, 1);   // 標準過渡 250ms
const springEase = Cubic(0.32, 1.28, 0.60, 1); // sheet open 420ms
const sheetClose = Cubic(0.4, 0, 1, 1);        // 280ms
// fast 150ms（toggle/hover）、nav-fade 200ms、slow 350ms（入場/skeleton）
// MediaQuery.disableAnimations → 全部歸零（prefers-reduced-motion）
```

### 其他要點
- `ThemeData(useMaterial3: true)` + light/dark 兩套 ColorScheme；dark 不是反色而是獨立暖褐黑 palette。
- Checkbox/Radio `activeColor` = accent；selection 色 = accent 30%。
- Modal 限 destructive 確認/單行輸入；多欄位表單一律全頁（AppBar + sticky bottom bar：glass blur + 取消/確認）。
- AppBar（=TitleBar）：高 56（desktop 64）、單行 title 18–20/w700 ellipsis、glass blur 14 + 底部 hairline、action 一律 ghost icon 44×44 radius 8。

**來源檔案**：`C:/Users/RayChiu/Desktop/Source/GithubRepos/trip-planner/DESIGN.md`、`C:/Users/RayChiu/Desktop/Source/GithubRepos/trip-planner/css/tokens.css`、`C:/Users/RayChiu/Desktop/Source/GithubRepos/trip-planner/docs/design-sessions/2026-06-06-three-color-system.md`

---

## 4. Apple Music / Apple HIG 嚴格 UI/UX 稽核（2026-07-15）

### 結論與選定方向

本輪選定 mockup **C：Map First Drawer**。Tripline 不採「地圖內容分頁 + DAY 分頁」兩層常駐 Tab，也不讓固定 POI 卡列與底部根 Tab 互相擠壓；最終資訊架構固定為：

1. 行程根頁：inline title，恆為 56pt（2026-07-16 修訂，原訂的 large title 已移除，理由見 4.1）。
2. 行程詳情：返回、標題、編輯、更多；行程／地圖／筆記改由單一內容範圍選單切換。
3. 地圖頂部：單一 `地圖 · DAY 02 ▾` scope capsule，選單內提供總覽與各日。
4. 地圖底部：固定高度的 POI accessory，只用左右滑動切換景點，永遠位於根 Tab 上方。
5. 根 Tab：只負責聊天／行程／地圖／收藏／帳號五個頂層目的地，不承載新增或 POI 操作。

本輪是**全 App 的視覺與互動系統調整**，不是只修行程與地圖兩頁。既有元件、頁面結構與 navigation shell 若無法達到本節規格，可以直接改寫；是否重用以結果與維護性決定，不把舊實作視為限制。唯一硬性架構條件是：相同職責必須由共用元件或共用 primitive 提供，禁止每頁各自複製一套 toolbar、menu、glass、scroll edge 或 bottom clearance 邏輯。

Mockup C 的青綠色只代表原 `.flutter` 參考稿，不進入 production theme。正式配色採 **V3 中性深色 + 柔褐 accent**：dark canvas `#121214`、surface `#1C1C1E`、elevated surface `#2C2C2E`、foreground `#F5F5F7`、muted `#A1A1A6`；選取、主要動作與品牌 accent 使用 `#CBA06E`。青綠不得成為 toolbar、scope、root tab、drawer 或主要 CTA 的 chrome 色；sage／pink 僅保留既有分類與語意用途。

比較 mockup（`docs/design-sessions/`，已進版控）：

| 檔案 | 內容 | 決議 |
|------|------|------|
| [`2026-07-16-map-poi-card-overflow.svg`](../design-sessions/2026-07-16-map-poi-card-overflow.svg) | 行程地圖 POI 卡片破版 | 改 Stack 浮層 + 88pt accessory，卡片不再被 tab bar 蓋住 |
| [`2026-07-16-headers-and-type-scale.svg`](../design-sessions/2026-07-16-headers-and-type-scale.svg) | 三個根頁 header 收斂 + 字階 | 移除 large title，恆 inline 56pt（理由見 4.1） |
| [`2026-07-16-root-tabs-consistency.svg`](../design-sessions/2026-07-16-root-tabs-consistency.svg) | 浮動 root tab 一致性 | 固定 64pt，不隨捲動縮合、標籤不淡出 |

原本此處指向 `~/.gstack/projects/.../designs/trip-itinerary-map-20260715/design-board.png` —— 那是 gstack 的 session 暫存區，檔案早已隨 session 消失。定稿依據不該放在會被清掉的地方，故一律簽入 `docs/design-sessions/`。

### 證據範圍

- 可直接執行的 iOS 26.5 模擬器目前停在登入頁；未使用帳密或建立外部帳號，因此登入後畫面的稽核以目前程式碼、既有元件與使用者直接觀察為準。
- 行程根頁、詳情與地圖均已由 codebase knowledge graph 定位，再讀取實作確認；以下不是只看舊 spec 的推測。
- 本節是設計決策與完成標準，不代表目前程式已符合；每一項仍需以 runtime 截圖、widget test 或互動驗證關閉。

### 現況對照

| 區域 | 目前實作證據 | 嚴格評估 | 目標狀態 |
|---|---|---|---|
| 行程根頁頂部 | `trips_list_screen.dart:264` 使用 `SliverAppBar.large`；其下再常駐搜尋與「全部／我的／共編」，另有 FAB | title extension、搜尋、scope 與 FAB 同時搶首屏，視覺上比 Apple Music 的內容優先層級更厚 | **（2026-07-16 修訂）** 不用 large title；搜尋緊接 inline toolbar；scope 只有在確實改變資料集合時顯示；新增移至 toolbar `+` |
| 根頁捲動標題 | Material `SliverAppBar.large` 與全域 `AppBarTheme` 共用，但沒有明訂 expanded / collapsed 幾何與 action 對稱 | action 寬度變動時，inline title 的視覺中心容易偏移；不同頁的 title baseline 不一致 | **（2026-07-16 修訂）** title 恆為 inline 56pt、不隨捲動變化；以全 toolbar 幾何置中，不依剩餘寬度臨時計算中心 |
| 行程詳情 toolbar | `trip_timeline_screen.dart:59-139` 同時顯示編輯、地圖、筆記、列印、異動紀錄、更多，共六個 trailing control | 嚴重超出 iPhone toolbar 的必要 action 密度；Cupertino 與 Material icon、直向更多按鈕混用 | visible trailing action 僅「編輯」與水平「更多」；其他命令分組放入具名 menu |
| 行程內容導覽 | 地圖、筆記是 toolbar icon；DAY pills 在 `_TimelineBodyState.build` 固定佔一列 | 內容目的地與命令混在 toolbar，使用者要記 icon；DAY 列也壓縮內容高度 | 使用單一 `行程 ▾` scope control 切換行程／地圖／筆記；DAY 是內容內薄型 sticky strip |
| 地圖頂部 | `trip_map_screen.dart:381-400` 為 `DAY tabs → map → 104pt cards` 固定 Column；tabs 實作在 `404-473` | DAY 控制永久佔高；長行程會變成橫向 pill 迷宮 | 只保留一個 44pt `地圖 · DAY NN ▾` capsule；總覽與各日放入 menu / sheet |
| 地圖控制 | `trip_map_screen.dart:477-546` 圖層與定位按鈕分別浮在右上 | 兩個控制外觀與 toolbar／根 Tab 不同，形成第三套 chrome | 若改 Google Maps，移除圖層選單；只留定位與全覽，使用同一 glass circle、尺寸與邊界 |
| 地圖 POI | `trip_map_screen.dart:548-629` 固定 104pt 水平卡列；根 shell 另有 `NavigationBar` | 卡列沒有 active page，也未與 marker / camera 同步；不同 safe area 下可能壓住根 Tab | POI 改為固定高度 accessory；只左右滑動 PageView，動態保留根 Tab 間距 |
| 根 Tab | `app_shell.dart:27` 使用 Material `NavigationBar` | 功能正確，但外觀仍是 Material surface／indicator，未形成 iOS 26 浮動功能層 | 浮動 Liquid Glass root tab；只導覽、保持可見、內容可延伸到後方但可操作內容必須避讓 |

### Apple Music / HIG 基準

#### 4.1 標題與捲動邊界

Apple 建議 large title 用來維持方位感，開始捲動時自然轉為標準 title；toolbar 項目應只保留最重要的命令。

**Tripline 刻意不採用 large title（2026-07-16 決議，取代本節原訂的 large-title 規格）。**

理由：large title 的方位感前提是「頁名是新資訊」。Tripline 五個根頁都由常駐 tab bar 標示目前位置，large title 只是把 tab 已經講過的頁名再講一次，卻吃掉 96–108pt —— 那是一整張行程卡的高度。省下的高度換成內容，方位感由 inline title 與選中的 tab 共同承擔。

- 根頁與次層頁**一律 inline title**，恆為 56pt，不放大也不收合（無 collapse threshold、無捲動幾何變化）。
- title 以整個 toolbar 寬度置中；左右 action 群組採相同 44pt slot，長標題只截斷，不偏移。
- inline title 使用 17–20pt / w600–700，垂直中心與返回、編輯、更多按鈕相同。
- toolbar 後方有可滾動內容時使用單一 automatic / hard scroll-edge separation；不得同時再畫厚底線與陰影。

實作：`lib/ui/tp_root_scroll_scaffold.dart`（`expandedHeight == collapsedHeight == 56`，兩者相等即是「大標題已移除」的可測條件），驗收見 `test/ui/tripline_ui_test.dart`。

參考：[Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)、[Scroll views](https://developer.apple.com/design/human-interface-guidelines/scroll-views)。

參考：[Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)、[Scroll views](https://developer.apple.com/design/human-interface-guidelines/scroll-views)。

#### 4.2 Toolbar 與更多選單

所有 iPhone 頂部列共用以下 action hierarchy：

- 行程根頁：`+`、水平 `…`。匯入與排序進 `…`。
- 行程詳情：返回、title、編輯、水平 `…`。
- 地圖詳情：返回、title、水平 `…`；範圍切換屬內容控制，不放 toolbar trailing。
- visible trailing action 最多兩個；全部使用同一套 Cupertino / SF Symbols 視覺重量。
- 禁止 `Icons.more_vert`；iOS 使用水平 `ellipsis` 或 `ellipsis.circle`。
- menu 順序：高頻且安全的項目在前，相關命令分組，destructive 最後並使用紅色。
- menu label 使用可執行動詞或清楚名詞，例如「編輯行程」「分享連結」「列印」「查看異動紀錄」，不只顯示 icon。
- 44×44pt hit target 不因 icon 視覺尺寸縮小。

目前 `trip_timeline_screen.dart` 已有分享／共編／AI 健檢 menu，可直接擴充，而不是再建立第二套 action sheet。參考：[Menus](https://developer.apple.com/design/human-interface-guidelines/menus)。

#### 4.3 Liquid Glass 邊界

- Liquid Glass 只用在 root tab、toolbar 控制、map scope capsule、map floating controls、POI drawer 的操作列。
- 行程卡、時間軸、搜尋結果、POI 卡內容使用標準 surface；禁止每張卡都加 blur。
- 淺／深色分別取樣；Reduce Transparency 或高對比時改為較不透明 surface。
- glass 元件僅一層邊界與極輕陰影，不能同時套 thick border、shadow、gradient。

參考：[Materials](https://developer.apple.com/design/human-interface-guidelines/materials)。

### 行程頁定稿規格

**（2026-07-16 修訂）** 原本分「展開／收合」兩節，是 large title 的產物 —— 大標題移除後 title 與 root tab 都不隨捲動變形，只剩單一狀態。

1. 標題固定為「我的行程」，inline 56pt，不放大也不收合。
2. toolbar 右側為 `+` 與水平 `…`；移除底部 FAB。
3. `+`、`…` 的 slot、背景、圓角與 icon weight 完全一致；loading 時也保留 slot 寬度，禁止 title 跳動。
4. 搜尋欄距 toolbar 8pt、左右 16pt，使用 44pt 高系統密度；可隨內容捲走。
5. 「全部／我的／共編」是篩選同一列表的 related subview，可使用 segmented control；高度 32–36pt，外層 hit area 44pt。scope 可依需要 sticky，但 sticky 時只保留一列且套用單一 scroll-edge effect。
6. 搜尋與 scope 合計最多兩列；若使用者沒有共編行程，可隱藏 scope 而不是保留空控制。
7. root tab 恆為 64pt，不隨捲動縮合、標籤不淡出（理由同 4.1：捲動時位置會動的目標比較難點中，而縮合換來的高度不足一列內容）。
8. 第一張行程卡須在 390×844 裝置上出現在首屏，不得被 title、搜尋、scope 三層 chrome 推到首屏外。

### 行程詳情定稿規格

- 次層頁不使用 large title；title 是目前行程名稱，單行截斷。
- toolbar：返回／title／編輯／更多。
- `行程 ▾` 是內容範圍控制，選項為行程、地圖、筆記；目前項目顯示 checkmark。
- DAY strip 只在行程內容出現，緊貼 scroll edge，高度 44pt；選中 DAY 自動置中並露出下一項的一部分，提示可橫向捲動。
- 地圖與筆記不再各佔 toolbar icon；列印、異動紀錄、分享、共編、AI 健檢全部進更多 menu。
- 閱讀模式不顯示排序／拖曳控制；編輯後才進入明確 edit mode。

### 地圖 C：Map First Drawer 定稿規格

#### 頂部範圍控制

- 地圖內容上方只顯示一個 capsule：`地圖 · 總覽 ▾` 或 `地圖 · DAY 02 ▾`。
- capsule 高 44pt，置於 safe area + toolbar 下方 8–12pt；長文以 DAY 數字保留為優先。
- 點擊後顯示總覽與各 DAY；超過七天可捲動，當前項目有 checkmark。
- 選 DAY 後重新 fit 可見 marker；無座標的 stop 仍保留在 POI drawer，以「尚無位置」表示。
- 不再保留 `_buildDayTabs` 的固定水平 pill 列；這是 C 案的核心，不得實作成 capsule + DAY tabs 兩者並存。

#### POI 水平 accessory

- accessory 固定高度 88pt（76pt 卡片 + 12pt page indicator），不提供垂直拖曳、展開、收合或 detent。
- Dynamic Type ≥120% 時 accessory 固定切到 144pt accessibility geometry，同步增加 map padding；這不是使用者可拖曳的第二 detent。
- 內層只有水平 `PageView`，`viewportFraction` 為 0.84，對齊 V3 HTML 的 84% scroll-snap 卡寬；相鄰卡露出來提示可滑，第一張與最後一張都必須完整可達。
- POI 資料沒有圖片字段，卡片不使用假縮圖；改用與 map marker 一致的編號 badge、停留順序、名稱、時間／類型與 44pt 動作。
- 水平滑卡 → active POI / marker / camera 同步；點 marker → PageView 滑到該卡。
- 橫向卡滑動不得拖動地圖；不建立任何垂直 gesture recognizer。
- accessory 底部基準為 `viewPadding.bottom + 64pt root tab + 8pt tab margin + 12pt clearance`，由共用 root-tab geometry 計算，不可壓住根 Tab。
- map camera padding 依 88pt accessory 與 root-tab clearance 計算，fit route 後 marker 不得落在 accessory 或 scope capsule 下方。
- Reduce Motion 時卡片與 camera 直接切換；正常 PageView 動畫 200–280ms，禁止彈跳放大。

#### Root Tab 關係

Apple 的 tab bar 是頂層導覽，不是 action；在 iPhone 上浮於內容並允許底層內容透出。Music 的 bottom accessory 可以位於 tab bar 上方，縮小時與 tab bar 併列。Tripline 的 POI drawer借用此空間模型，但不假裝是播放器：

- root tab 始終保留五個目的地，不把 DAY、定位或新增放進 tab。
- map tile 可以延伸到 root tab 後方；marker、POI 文字與操作按鈕必須避讓。
- POI accessory 與 root tab 視覺上是兩個層級，不合併成第六個 Tab。
- root tab 在 map drag 時不自動消失；只有垂直內容捲動頁才採 scroll-down minimize。

參考：[Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)、[Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/)。

### 全 App 一致化規則

| 類別 | 統一規則 |
|---|---|
| Root title | 永遠 inline 56pt，17–20pt / w600–700；不放大、不收合，套用單一 scroll-edge effect |
| Detail title | 永遠 inline，不為單頁自訂 hero header |
| Toolbar actions | 最多兩個 visible trailing action；相同 44pt slot；水平 ellipsis |
| Content switcher | 同一頁的緊密 subview 才用 segmented / scope control；頂層區域只用 root tab |
| Menu | 相同 adaptive menu surface、icon weight、label grammar、destructive ordering |
| Map controls | 同一 glass circle；定位／全覽最多兩個；不保留 tile layer selector |
| Bottom accessory | root tab 上方保留單一 accessory/drawer 層；不得再疊 FAB 或固定卡列 |
| Material | glass 在功能層；卡片與內容用 standard surface / hairline |

### 優先順序

1. **P0：消除遮擋** — POI drawer 與 root tab 的 clearance、map padding、safe area。
2. **P0：統一 toolbar** — 行程詳情六個 action 收斂為編輯＋水平更多。
3. **P0：穩定 title** — expanded / collapsed 幾何、loading slot、scroll edge。
4. **P1：行程根頁密度** — 移除 FAB、壓縮 title 後的搜尋與 scope 區。
5. **P1：Map First POI Carousel** — 單一 scope capsule、固定水平 PageView、POI/marker/card 同步。
6. **P1：全 App 套用** — 聊天、收藏、帳號及所有次層頁改用同一套 title、toolbar、menu、glass、root tab 與 bottom accessory primitive；不允許把非行程頁留在舊視覺系統。

### 驗收矩陣

#### 視覺與版面

- 320×568、390×844、402×874、430×932；直向與橫向。
- light / dark、Increase Contrast、Reduce Transparency。
- 100%、135%、200% Dynamic Type；title、scope、toolbar action 不互相覆蓋。
- 行程首屏可見第一張卡；collapsed title 與四個 toolbar control 的中心線一致。
- map 在固定 POI accessory 與 root tab expanded / minimized 各組合都沒有 POI 遮擋。

#### 互動

- 大標題捲動收合、向上回復，title 不水平跳動。
- action loading 時 title 不位移；更多 menu 項目順序與 destructive 樣式正確。
- 選 DAY、滑 POI、點 marker 三條路徑最後得到同一 active day / POI / camera state。
- first / last POI 卡可完整選取；VoiceOver 可以左右切換卡片。
- root tab 切換保留各分頁 navigation 與 scroll state。

#### 無障礙與動態設定

- icon-only control 有中文 semantic label；順序為返回 → title → 編輯 → 更多 → scope → map controls → drawer → root tab。
- 44×44pt target；正文基準 17pt，支援文字不小於 11pt。
- Reduce Motion 停用非必要位移；VoiceOver 不朗讀被 drawer 遮住或不可見的 marker。
- POI 卡的當前頁、總頁數與位置狀態必須可被輔助技術辨識。

### 全面改寫與共用架構要求

可以保留、重構或直接替換既有 Flutter 實作；判斷標準是能否完整符合本節的視覺、互動、無障礙與測試要求，而不是修改行數最少。以下共用能力是必要條件，實際 class 名稱可依 codebase 調整：

| 共用能力 | 單一責任 | 禁止事項 |
|---|---|---|
| App page shell | 統一 root／detail 的 inline title、scroll edge、safe area 與 action slots | 各頁自行拼 `AppBar` / `SliverAppBar` 幾何 |
| Toolbar action / menu | 統一 44pt hit target、SF Symbol 重量、水平更多、menu 分組與 destructive ordering | Cupertino / Material icon 混用，或每頁自製 popup / sheet |
| Scope control | 統一行程／地圖／筆記與 DAY 範圍選擇的視覺、狀態與語意 | 同一頁同時存在 capsule、segmented control、DAY pills 三套切換器 |
| Glass material primitive | 統一 blur、tint、border、shadow、Reduce Transparency fallback | 元件自行疊 blur、border、gradient、shadow |
| Root tab + bottom accessory host | 集中管理 tab 高度、minimize 狀態、safe area、drawer / accessory clearance | POI drawer、FAB、固定卡列各自猜測 bottom padding |
| Map POI accessory | 管理固定高度、水平卡片、active POI、marker 與 camera padding 同步 | 垂直收合／detent，建立第二套 day / POI domain state，或讓 view state 反向成為資料來源 |

- 全部 root 頁與 detail 頁都必須遷移到共用 page shell 與 toolbar primitive；不能只讓新頁使用。
- 共用元件提供 layout 與 interaction contract，頁面只傳 title、actions、menu commands、scroll state 與內容，不直接覆寫幾何常數。
- domain state 可以沿用，也可以在有明確問題時改寫；active day / POI 仍必須只有一個權威來源。
- 不為 mockup 新增圖片服務；POI 沒有影像時使用共用 tone / icon fallback。
- 本輪可以全面改寫 Flutter UI 與其 widget tests；Web UI、後端資料模型及 API contract 不在這次範圍，除非 Flutter 共用架構無法在不變更 contract 下完成。

完成定義：全部 root / detail 頁均已遷移至共用 primitive，以上 P0/P1 項目有 runtime 截圖與互動證據，驗收矩陣通過，且原本的固定 DAY tabs、固定 104pt POI row、六個詳情 toolbar action 與各頁自製 toolbar / menu 幾何已從 production 路徑移除。
