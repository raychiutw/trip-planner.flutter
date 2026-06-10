# Theme 與設計系統參考(`lib/theme/`)

視覺規範的 source of truth 是 web repo 的 `DESIGN.md` + `css/tokens.css`,本層把它翻成 Flutter:`tokens.dart` 是純常數,`app_theme.dart` 把常數組成 `ThemeData` 與 `TpTones` ThemeExtension。原始設計調查在 [`discovery/design.md`](discovery/design.md)。

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

`main.dart` 以 `themeMode: ThemeMode.system` 同時掛 light/dark。主要客製:卡片 elevation 0 + 1px hairline border(`border` 色)、radius 8、NavigationBar 風格、Inter → Noto Sans TC 字體 fallback。

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
- [架構說明](explanation-architecture.md) — theme 在分層中的位置
- [`discovery/design.md`](discovery/design.md) — 完整 token 對照與設計規範調查
