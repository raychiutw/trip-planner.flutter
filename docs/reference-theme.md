# Theme 與自適應 UI 設計系統參考

品牌色與三色 tone 來源是 web repo 的 `DESIGN.md` + `css/tokens.css`；Flutter 互動、字體、導覽、內容寬度與回饋以本文件及程式碼為準。`tokens.dart` 定義常數，`app_theme.dart` 組成 `ThemeData`/`TpTones`，`lib/app/` 提供跨畫面共用的自適應 UI primitive。來源調查保留在 [`discovery/design.md`](discovery/design.md)。

## 取色守則

- **語意色**(主色、文字、底色、錯誤)走 `Theme.of(context).colorScheme`
- **三色 tone**(accent/sage/pink 4 階)走 `Theme.of(context).extension<TpTones>()!` — `subtle` 階在 `ColorScheme` 沒有對應欄位,所以 tone 色一律從 TpTones 取
- **不要**在 widget 裡直接引用 `TpColorsLight`/`TpColorsDark` — 那會破壞 light/dark 切換

## tokens.dart

### 色彩 — `TpColorsLight` / `TpColorsDark`

Dark 是獨立的暖褐黑 palette,**不是 light 反色**。

| Token | Light | Dark | 用途 |
|---|---|---|---|
| `accent` | `#A97A4A` | `#CBA06E` | 主色柔褐(玩/看/買) |
| `accentDeep` | `#8A6038` | `#E0BC90` | tone 深階(glyph、圓點) |
| `accentSubtle` | `#F4EDE3` | `#33271A` | tone 淺底(卡底) |
| `accentBg` | `#E9DBC8` | `#44341F` | tone 中底(icon 底) |
| `sage` 4 階 | `#A8BAAA` 起 | `#8FBE9C` 起 | 住/移動 |
| `pink` 4 階 | `#E78C99` 起 | `#E8A0AB` 起 | 吃 |
| `background` | `#FFFBF5` | `#1A140F` | 奶油底 / 暖褐黑底 |
| `secondary` / `tertiary` / `hover` | 米色階 | 褐黑階 | 次級表面 |
| `foreground` / `muted` | `#2A1F18` / `#6F5A47` | `#F5EBDD` / `#B89E84` | 文字 |
| `border` / `lineStrong` | `#EADFCF` / `#C8B89F` | `#3D2D22` / `#5A4634` | hairline / 強線 |
| `destructive` / `destructiveBg` | `#C13515` / `#FDECEC` | `#E8A0A0` / 15% alpha | 破壞性操作 |
| `success` / `warning` / `info` | `#06A77D` / `#F48C06` / 同 accent | `#7EC89A` / `#FAA94B` / 同 accent | 語意狀態 |
| `disabled` / `overlay` | `#B8AC9B` / 35% 褐黑 | `#5A4634` / 65% 黑 | 停用 / 遮罩 |

### 圓角 — `TpRadius`

`xs=4`、`sm=6`、`md=8`(卡片/按鈕主力)、`lg=12`、`xl=16`(bottom sheet / dialog)。

### 間距 — `TpSpacing`(4px grid)

`s1=4` 到 `s10=40`(每階 +4)。另有:

- `tapMin = 44.0` — 最小 tap target(HIG)
- `navHeight = 88.0` — bottom nav 高度(含 safe area)

### Motion — `TpMotion`

| Token | 值 |
|---|---|
| `fast` / `normal` / `slow` | 150ms / 250ms / 350ms |
| `appleEase` | `Cubic(0.2, 0.8, 0.2, 1)` — 預設曲線 |
| `springEase` | `Cubic(0.32, 1.28, 0.6, 1)` — 彈跳進場 |
| `sheetClose` | `Cubic(0.4, 0, 1, 1)` — sheet 收合 |

`TpMotion.resolve(context, preferred)` 在系統開啟「減少動態效果」時回傳 `Duration.zero`。新增動畫必須透過它解析 duration。

## app_theme.dart

### TpTones(ThemeExtension)

accent/sage/pink 各 4 階(`base`/`deep`/`subtle`/`bg`)+ `success`/`warning`,共 14 色。`TpTones.light` / `TpTones.dark` 兩組常數,`lerp` 支援主題切換動畫。

```dart
final tones = Theme.of(context).extension<TpTones>()!;
Container(color: tones.sageSubtle, child: Icon(color: tones.sageDeep, ...));
```

### AppTheme

```dart
abstract final class AppTheme {
  static ThemeData light();
  static ThemeData dark();
}
```

`main.dart` 同時掛 light/dark theme，實際模式由 `themeModeProvider` 決定。主要客製：卡片 elevation 0 + 1px hairline border、radius 8、44pt 按鈕、NavigationBar 與 HIG 字階。

不指定 `fontFamily`：iOS/macOS 使用系統字（SF Pro，中文由 PingFang fallback），Android 使用 Roboto（中文由 Noto fallback）。這能直接取得 Dynamic Type、Bold Text 與平台字型修正，不打包 Inter。

### TextTheme 字階

| role | size / line-height / weight | 用途 |
|---|---|---|
| `displaySmall` | 34 / auto / 700 | large title |
| `headlineMedium` | 28 / 36 / 700 | 頁面標題 |
| `titleLarge` | 20 / auto / 700 | app bar / section |
| `titleMedium` | 17 / 24 / 700 | 卡片標題 |
| `bodyLarge` | 17 / 26 / 400 | 主要內文 |
| `bodyMedium` | 15 / 23 / 400 | 次要內文 |
| `bodySmall` | 13 / 18 / 400 | caption，tabular figures |
| `labelLarge` | 16 / auto / 600 | 按鈕 |
| `labelMedium` | 13 / 18 / 600 | chip / label |
| `labelSmall` | 12 / 16 / 700 | 小型標籤 |

中文 `letterSpacing` 一律為 `0`。

## 自適應導覽與內容寬度

`AppShell` 固定五個頂層目的地：聊天、行程、地圖、收藏、帳號。切換 branch 會觸發 selection haptic；再次點目前 tab 會回到該 branch 初始位置。

| 條件 | 導覽元件 |
|---|---|
| 寬度 `< 768` 且 iOS/macOS | `CupertinoTabBar` |
| 寬度 `< 768` 且其他平台 | Material `NavigationBar` |
| 寬度 `>= 768` | `NavigationRail` |

`AppAdaptiveContent` 保留父層高度約束，手機全寬，寬螢幕依角色置中：

| `AppContentWidth` | 最大寬度 | 適用內容 |
|---|---:|---|
| `form` | 720 | 建立、編輯、設定表單 |
| `conversation` | 860 | 聊天、搜尋、探索 |
| `feed` | 920 | 行程、收藏等列表 |

```dart
const AppAdaptiveContent({
  Key? key,
  required double maxWidth,
  required Widget child,
  Key? contentKey,
});
```

`maxWidth` 必須從內容角色選擇；`contentKey` 只用於需要量測或定位內容容器的測試。

## 平台自適應元件（`lib/app/adaptive.dart`）

| API | Apple 平台 | 其他平台 |
|---|---|---|
| `showAppConfirm` | `CupertinoAlertDialog` | Material `AlertDialog` |
| `showAppActionSheet<T>` | `CupertinoActionSheet` | Material bottom sheet |
| `AppSearchField` | `CupertinoSearchTextField` | Material `TextField` |
| `showAppNotice` | 約 2.5 秒的頂部橫幅 | `SnackBar` |

`showAppConfirm` 關閉時回傳 `false`；破壞性動作在兩個平台都使用 error 語意。`AppSheetAction<T>` 封裝 label、回傳值、破壞性狀態與 Material leading icon。

```dart
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = '取消',
  bool isDestructive = false,
});

const AppSheetAction<T>({
  required String label,
  required T value,
  bool isDestructive = false,
  IconData? icon,
});

Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppSheetAction<T>> actions,
  String cancelLabel = '取消',
});

const AppSearchField({
  Key? key,
  Key? fieldKey,
  required TextEditingController controller,
  required String placeholder,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
  bool autofocus = false,
  bool enabled = true,
});

void showAppNotice(BuildContext context, String message);
```

`fieldKey` 會直接掛到底層原生欄位，讓同一份 widget test 可操作 Apple 與 Material 分支。

## 回饋與載入

- `showAppNotice` 只用於成功、離線/重連等低風險短狀態。
- `showAppError` 使用持續顯示的 `MaterialBanner`，有 live-region semantics、關閉動作，並可用 `onRetry` 加入重試。新錯誤會取代目前 banner。
- `AppListLoadingSkeleton(itemCount: 4)` 與 `AppMapLoadingSkeleton` 保留預期版型並提供載入 semantics。
- skeleton 是靜態的，不使用 shimmer；這避免無意義的持續動畫，也符合 reduced-motion 基線。

```dart
void showAppError(
  BuildContext context,
  String message, {
  VoidCallback? onRetry,
});

const AppListLoadingSkeleton({Key? key, int itemCount = 4});
const AppMapLoadingSkeleton({Key? key});
```

`AppListLoadingSkeleton.itemCount` 必須大於 `0`。只有操作確實可以安全重送時才提供 `onRetry`。

## App Icon

App Icon 的圓角座標定位圖釘與中央指南針箭頭是固定品牌識別，不因 Apple Music 視覺對標而替換。iOS 由系統套用遮罩，Default/Dark/Tinted 維持相同輪廓；Android 沿用各 density launcher icon。完整規格見 [Tripline App Icon 設計規格](superpowers/specs/2026-07-14-tripline-app-icon-design.md)。

## POI type → tone 對照

`lib/features/trip_detail/widgets/entry_tone.dart` 的 `resolveEntryTone(TpTones, String? poiType)` 把 POI 類型映射到三色 tone:

| poi_type | tone | 語意 |
|---|---|---|
| `hotel`、`transport`、`parking` | sage | 住/移動 |
| `restaurant` | pink | 吃 |
| 其他(`attraction`/`activity`/`shopping`/`null`…) | accent | 玩/看/買(預設) |

回傳 `EntryToneColors{base, deep, subtle, bg}`,timeline 元件的套色階梯:卡底 `subtle` → icon 底 `bg` → glyph/圓點 `deep`。

### 例外:地圖逐日 pin 色

`trip_map_screen.dart` 的 `kDayPinPalette` 是 10 色 Tailwind-500 palette(red→pink 輪替)。這是 design.md 明定的 data-viz 例外 — 一般 UI 禁用 rainbow 色,地圖 polyline/pin 例外。

## 設計禁忌(來自 web DESIGN.md)

- 禁止 gradient 裝飾、emoji 當 icon、rainbow 色(地圖例外)
- shadow 只給浮層(sheet/dialog),卡片用 hairline
- 中文內文 16/26,時間數字 tabular-nums

## 相關文件

- [How to 新增畫面](howto-add-screen.md) — 新畫面如何正確取用 token 與 tone
- [自適應 UI 設計理由](explanation-adaptive-ui.md) — Apple Music/HIG 對標、反方意見與取捨
- [架構說明](explanation-architecture.md) — theme 在分層中的位置
- [`discovery/design.md`](discovery/design.md) — 完整 token 對照與設計規範調查
