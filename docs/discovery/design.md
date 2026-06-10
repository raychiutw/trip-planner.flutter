# Tripline 設計系統解析 → Flutter ThemeData 對應

> 權威來源優先序：`css/tokens.css` `@theme`（實作 canonical）↔ `DESIGN.md`（規範）。`docs/design-sessions/2026-06-06-three-color-system.md` 是探索 spec（標註「尚未實作」），**現已落地進 tokens.css（v2.53+），少數 dark 色值以 tokens.css 為準**（如 dark sage-deep：doc `#A4CBAF` → 實際 `#A8D0B4`；dark 粉 subtle/bg 改加強版 `#4A2A3A`/`#6B3F52`）。

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