# 設計:dart-define `TRIPLINE_API_ORIGIN` + widget/integration 測試

> 日期:2026-06-10
> 狀態:已批准設計,待寫 plan
> 來源任務:補 widget/integration 測試 + 處理 TODOS 技術債(`--dart-define` 本機後端覆寫)

## 背景

P0 畫面已出貨(144 tests 全綠)。兩個後續工作:

1. **技術債**(PR #1 `TODOS.md`):`--dart-define=TRIPLINE_API_URL` base URL 覆寫為 `PORTING_PLAN.md:21` 的規劃項,**尚未實作**;目前 `apiClientProvider` 直接 `ApiClient(sessionStore: ...)`,`origin` 永遠是 hard-code 的 prod 常數 `kTriplineOrigin`。後果:本機開發只能連 prod(含破壞性操作),是 `/ship` adversarial 標記的安全顧慮根因。
2. **測試補強**:既有測試覆蓋 models / api / 多數 screen,但 `trip_detail/widgets/` 6 個 widget、`trip_card`、`app_shell` tab 切換、跨畫面流程、device smoke 皆無測試。

## 目標 / 非目標

**目標**
- 讓 API base origin 可由 `--dart-define=TRIPLINE_API_ORIGIN` 在 build/run 時覆寫,預設仍為 prod。
- 補齊 widget / pure-logic / 導航 / 跨畫面流程測試。
- 新增一支最小 device smoke test(`integration_test/`)。
- 同步文件(PORTING_PLAN / TODOS / CHANGELOG)+ 一篇本機開發 how-to。

**非目標**
- 不實作任何 P1 功能(CRUD、聊天、收藏等)。
- 不引入真正的本機後端 server(只提供「指向本機後端」的覆寫機制與文件)。
- 不改既有 ApiClient 的認證 / retry / 錯誤行為。

## A. dart-define `TRIPLINE_API_ORIGIN`

### 決策

- **命名 / 語意**:`TRIPLINE_API_ORIGIN`,值為 **origin**(`scheme://host[:port]`,不含 `/api`)。一個 origin 同時驅動 base URL(`origin/api`)與 mutating request 的 CSRF `Origin` header。更正 `PORTING_PLAN.md` 既有的 `TRIPLINE_API_URL`(名稱暗示完整 URL,與 `ApiClient(origin:)` 語意衝突)。
- **實作位置**:常數方案(非 provider 注入)。

### 核心改動(`lib/api/api_client.dart:12`)

```dart
/// 本 build 連線的 origin。預設正式站,可用 --dart-define=TRIPLINE_API_ORIGIN
/// 覆寫(本機開發指向本機後端)。一個 origin 同時決定 base URL(origin/api)
/// 與 mutating request 的 CSRF Origin header。
const String kTriplineOrigin = String.fromEnvironment(
  'TRIPLINE_API_ORIGIN',
  defaultValue: 'https://trip-planner-dby.pages.dev',
);
```

### 為何零破壞

既有測試斷言綁的是 `kTriplineOrigin` **變數**(`api_client_test.dart:100` Origin header、`:254` `'$kTriplineOrigin/api'`),非 hard-code 字串:
- 沒設 env → 常數 == prod → 斷言照過。
- 設了 env → 常數與 baseUrl 一起變 → 斷言仍成立。

`ApiClient(origin:)` 的顯式覆寫能力(測試用)完全保留;`apiClientProvider` 無需改動。

### 為何不選 provider 注入

provider 注入讓 ApiClient「更純粹」(env 留在 composition root),但需改 provider 並讓常數兩用,改動較大且無實際收益——`String.fromEnvironment` 本就是編譯期常數,放常數最自然。

## B. 測試設計(全程 TDD:先 red 後 green)

> mock 策略沿用既有模式:repository/provider override + 假 `GoRouter`(見 `trips_list_screen_test.dart`)。flutter_riverpod 3.x 注意事項:error-state 測試需 `ProviderScope(retry: (_, __) => null)`;family override 用 `.overrideWith((ref, arg) async => ...)`。
> 測試 fixture 依各 model constructor 構造,確切簽章於 plan/實作階段對照 `lib/models/`。

### ① pure logic 單元測試(最高 CP,無需 pump)

| 檔案 | 測試對象 | 案例 |
|---|---|---|
| `test/features/trip_detail/widgets/entry_tone_test.dart` | `resolveEntryTone(tones, poiType)` | hotel/transport/parking→sage、restaurant→pink、其他/null→accent;逐欄位(base/deep/subtle/bg)比對(`EntryToneColors` 無 `==`) |
| `test/features/trips/trip_card_test.dart`(logic 段) | `TripSummary.displayTitle` | title 有值→trim;title 空字串/null→退回 name |
| `test/features/trip_detail/widgets/day_pills_test.dart`(logic 段) | `DayPills.shortDate` | `"2026-06-10"→"6/10"`;非日期字串→原樣;`null→""`;不足 3 段→原樣 |
| `test/features/trip_detail/widgets/travel_pill_test.dart`(logic 段) | `TravelPill.iconForType` | walk/car/drive/taxi/bus/train/monorail/tram/flight/plane/ferry/boat/bike/cycle 各對應 icon;未知→`Icons.route` |

### ② presentational widget 渲染測試

> 每支以 `MaterialApp(theme: AppTheme.light(), home: ...)` 包裝(需 `TpTones` ThemeExtension)。

- `day_header_test.dart`:`DAY 03`(dayNum padLeft 2);date+dayOfWeek 以全形括號組成 `2026-06-10（週二）`;date/dayOfWeek 皆 null → 不顯示日期列;`displayTitle` 渲染。
- `day_pills_test.dart`(widget 段):渲染 N 個 pill;active pill(`dayNum == activeDayNum`)套 accentSubtle 樣式;點某 pill → `onDaySelected(該 dayNum)` 被呼叫。
- `hotel_card_test.dart`:`hotel.name`;checkout 有 → 顯「退房 X」,無 → 不顯;note 有/空 的條件顯示;`ValueKey('hotel-card-<id>')` 存在。
- `travel_pill_test.dart`(widget 段):min 有 → 「N 分鐘」;min null + desc 有 → desc;皆無 → 「移動」;icon 依 type。
- `timeline_entry_tile_test.dart`:圓點(`ValueKey('entry-dot-<id>')`)顏色 == tone.deep;`isFirst` → 上連線透明、`isLast` → 下連線透明;`_EntryCard` 的 masterName(≠title 才顯)/category/rating(顯星+一位小數)/description 條件顯示。
- `trip_card_test.dart`(widget 段):cover 首字 == `displayTitle.characters.first`;tone(accent/sage/pink)對應 cover 配色;totalDays 有 → 「N 天」eyebrow,無 → 不顯;tap → `onTap`、long-press → `onLongPress`。
- `test/features/shell/`(placeholder):`PlaceholderScreen` 顯示傳入 title(AppBar)+「即將推出」。

### ③ 導航測試 `test/features/shell/app_shell_test.dart`

補既有缺口(`app_smoke_test` 只驗 5-tab 渲染、`router_test` 只驗 redirect):
- 用真 `StatefulShellRoute`(對照 `lib/app/router.dart`)+ override providers(未登入繞過 / 已登入 mock repo)。
- 點「地圖」「帳號」等 tab → `goBranch` → 顯示對應 branch 畫面;點佔位 tab(聊天/收藏)→ `PlaceholderScreen`「即將推出」。
- 點當前 tab → 回該 branch 初始路徑(`initialLocation` 行為)。

### ④ 跨畫面流程測試 `test/flows/trip_browsing_flow_test.dart`

- repository/provider override(**不連真後端**)。
- 流程:(未登入)LoginScreen → 模擬登入成功 → 行程清單 → 點卡片進時間軸 → 切到筆記 tab/頁。
- 登入步驟具體機制:override `authRepositoryProvider` mock 使 `login()` 成功回 user;於 LoginScreen 填表送出後 `authState` 轉已登入、router redirect `/trips`。
- 斷言每步正確畫面 + provider 資料正確流轉。
- 範圍:read-path 為主,不觸發刪除等破壞性互動。

### ⑤ device smoke test `integration_test/app_smoke_test.dart`

- 新增 dev_dependency:
  ```yaml
  dev_dependencies:
    integration_test:
      sdk: flutter
  ```
- `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`。
- override 成**未登入 + mock TripRepository**,**完全不打 prod API**。
- pump `TriplineApp` → `pumpAndSettle` → 期望 `LoginScreen`。
- 執行 `flutter test integration_test/` 需模擬器/實機(見風險 D1)。

## C. 檔案佈局

**新增測試檔(10)**
```
test/features/trip_detail/widgets/entry_tone_test.dart
test/features/trip_detail/widgets/day_header_test.dart
test/features/trip_detail/widgets/day_pills_test.dart
test/features/trip_detail/widgets/hotel_card_test.dart
test/features/trip_detail/widgets/travel_pill_test.dart
test/features/trip_detail/widgets/timeline_entry_tile_test.dart
test/features/trips/trip_card_test.dart
test/features/shell/app_shell_test.dart
test/flows/trip_browsing_flow_test.dart
integration_test/app_smoke_test.dart
```

**修改 / 新增非測試檔**
```
lib/api/api_client.dart          # kTriplineOrigin → String.fromEnvironment
pubspec.yaml                     # + integration_test dev_dependency
docs/PORTING_PLAN.md             # TRIPLINE_API_URL → TRIPLINE_API_ORIGIN(語意更正)
docs/howto-local-backend.md      # 新增:--dart-define 用法(對照既有扁平命名 howto-add-endpoint / howto-test-with-providers)
TODOS.md                         # 勾選技術債第一項
CHANGELOG.md                     # 記錄本次變更
```

## D. 交付計畫

1. 你在 GitHub「Squash and merge」PR #1 → master 取得 TODOS/CHANGELOG/VERSION。
2. 我 `git checkout master && git pull` → 開 `feat/dart-define-and-tests`。
3. commit 切兩塊:① dart-define + 文件 ② tests(含 device smoke)。spec 檔一併納入第一個 commit。
4. 全程 TDD;最後 `flutter analyze` + `flutter test` 全綠。
5. 開一個 PR(`/ship` 或手動)。

## E. 風險與驗證限制(誠實說明)

1. **device smoke test 可能無法在開發代理環境跑綠** — 需模擬器/實機。會嘗試 `flutter test integration_test/`,跑不動則明確回報,交本機驗證,不假裝通過。
2. **dart-define 端到端生效無法用常規 `flutter test` 證明** — env 是編譯期常數,常規測試只能驗「不變量」(`kTriplineOrigin` 不以 `/api` 結尾、baseUrl == `origin/api`)。實際覆寫由**一次性指令驗證**:`flutter test --dart-define=TRIPLINE_API_ORIGIN=https://example.test`,斷言 literal 並貼出證明,寫進 how-to。

## 驗收條件

- [ ] `flutter analyze` 0 issues。
- [ ] `flutter test` 全綠(既有 144 + 新增)。
- [ ] dart-define 端到端手動驗證指令通過(PR 描述貼證明)。
- [ ] device smoke test:環境允許則綠,否則文件化交付並說明。
- [ ] PORTING_PLAN / TODOS / CHANGELOG / how-to 更新完成。
