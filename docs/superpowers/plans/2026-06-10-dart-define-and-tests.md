# dart-define `TRIPLINE_API_ORIGIN` + 測試補強 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 API base origin 可由 `--dart-define=TRIPLINE_API_ORIGIN` 覆寫(本機開發指向本機後端),並補齊 widget / pure-logic / 導航 / 跨畫面流程 / device smoke 測試。

**Architecture:** dart-define 走「常數方案」——把 `kTriplineOrigin` 改成 `String.fromEnvironment`,一處改動驅動 baseUrl 與 CSRF Origin header,既有測試零破壞。測試沿用既有模式:`mocktail` mock repository + `ProviderScope` override + 假 `GoRouter`。

**Tech Stack:** Flutter 3.11.3、flutter_riverpod 3.x、go_router 17.x、dio 5.x、flutter_test + mocktail + http_mock_adapter + integration_test。

---

## 重要:這是「對既有出貨 code 補測試」

P0 畫面已實作且 144 tests 全綠。除 Task 1(dart-define 有真實作)外,其餘 task 的 code 已存在,TDD 流程調整為:

1. 寫測試(刻畫既有行為)
2. run → **預期 PASS**
3. **若預期 PASS 卻 FAIL**:停下調查——可能是我對行為理解錯,或既有 code 有 bug(用 superpowers:systematic-debugging)
4. commit

**避免假綠**:對 pure-logic 測試(Task 2/3/4/8),寫完後可選做一次 mutation check(暫時把一個斷言期望值改錯 → run 確認 FAIL → 改回 → run PASS),確保測試真的在驗東西。

## Commit 慣例

- 前綴:`test:`(純補測試)、`feat:`(dart-define)、`docs:`(文件)。
- 每個 commit message 結尾**必須**加一行(空一行後):
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- 範例:`git commit -m "test: 補 resolveEntryTone 色階對應測試" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"`

## 前置條件

- 已在 branch `feat/dart-define-and-tests`(spec commit `4daaa0c` 已在)。
- `flutter pub get` 已跑過。
- 確認起點全綠:`flutter test`(預期 144 passed)。

## File Structure

| 檔案 | 責任 | 動作 |
|---|---|---|
| `lib/api/api_client.dart` | `kTriplineOrigin` 常數改 env 讀取 | 修改(Task 1) |
| `test/api/api_client_test.dart` | + dart-define 不變量 / 覆寫驗證 | 修改(Task 1) |
| `pubspec.yaml` | + `integration_test` dev_dependency | 修改(Task 11) |
| `docs/PORTING_PLAN.md` | 命名更正 | 修改(Task 1) |
| `docs/howto-local-backend.md` | 本機後端 how-to | 建立(Task 1) |
| `TODOS.md` / `CHANGELOG.md` | 勾選 / 記錄 | 修改(Task 1、12) |
| `test/features/trip_detail/widgets/entry_tone_test.dart` | `resolveEntryTone` | 建立(Task 2) |
| `test/features/trip_detail/widgets/travel_pill_test.dart` | `TravelPill` + `iconForType` | 建立(Task 3) |
| `test/features/trip_detail/widgets/day_pills_test.dart` | `DayPills` + `shortDate` | 建立(Task 4) |
| `test/features/trip_detail/widgets/day_header_test.dart` | `DayHeader` | 建立(Task 5) |
| `test/features/trip_detail/widgets/hotel_card_test.dart` | `HotelCard` | 建立(Task 6) |
| `test/features/trip_detail/widgets/timeline_entry_tile_test.dart` | `TimelineEntryTile` | 建立(Task 7) |
| `test/features/trips/trip_card_test.dart` | `TripCard` + `displayTitle` | 建立(Task 8) |
| `test/features/shell/app_shell_test.dart` | `PlaceholderScreen` + 5-tab `goBranch` | 建立(Task 9) |
| `test/flows/trip_browsing_flow_test.dart` | 登入 + 瀏覽流程 | 建立(Task 10) |
| `integration_test/app_smoke_test.dart` | device smoke | 建立(Task 11) |

---

## Task 1: dart-define `TRIPLINE_API_ORIGIN`

**Files:**
- Modify: `lib/api/api_client.dart:11-12`
- Modify: `test/api/api_client_test.dart`(`base URL` group 之後追加)
- Modify: `docs/PORTING_PLAN.md:21`
- Create: `docs/howto-local-backend.md`
- Modify: `TODOS.md`

- [ ] **Step 1: 追加測試**(`test/api/api_client_test.dart`,在最後一個 `group(...)` 之後、`main` 的 `}` 之前)

```dart
  group('dart-define TRIPLINE_API_ORIGIN', () {
    test('kTriplineOrigin 為純 origin（不含 /api 路徑、無結尾斜線）', () {
      expect(kTriplineOrigin.endsWith('/api'), isFalse);
      expect(kTriplineOrigin.endsWith('/'), isFalse);
      expect(Uri.parse(kTriplineOrigin).path, isEmpty);
    });

    // 常規 flutter test（未帶 dart-define）此測試為 no-op；
    // 帶 --dart-define=TRIPLINE_API_ORIGIN=<x> 時才真正驗證覆寫生效。
    test('帶 --dart-define 時 origin 被覆寫', () {
      if (!const bool.hasEnvironment('TRIPLINE_API_ORIGIN')) return;
      const injected = String.fromEnvironment('TRIPLINE_API_ORIGIN');
      expect(kTriplineOrigin, injected);
      expect(kTriplineOrigin, isNot('https://trip-planner-dby.pages.dev'));
    });
  });
```

- [ ] **Step 2: run 確認既有 + 新測試通過**

Run: `flutter test test/api/api_client_test.dart`
Expected: PASS（含新 group;覆寫測試此時為 no-op)

- [ ] **Step 3: 改常數為 env 讀取**(`lib/api/api_client.dart:11-12`)

把:
```dart
/// CSRF Origin allowlist 要求的正式站 origin。
const String kTriplineOrigin = 'https://trip-planner-dby.pages.dev';
```
改成:
```dart
/// 本 build 連線的 origin。預設正式站,可用 --dart-define=TRIPLINE_API_ORIGIN
/// 覆寫(本機開發指向本機後端)。一個 origin 同時決定 base URL(`origin/api`)
/// 與 mutating request 的 CSRF Origin header。
const String kTriplineOrigin = String.fromEnvironment(
  'TRIPLINE_API_ORIGIN',
  defaultValue: 'https://trip-planner-dby.pages.dev',
);
```

- [ ] **Step 4: run 常規測試（無 dart-define,確認零破壞)**

Run: `flutter test test/api/api_client_test.dart`
Expected: PASS（default 仍為 prod,所有斷言不變)

- [ ] **Step 5: run 帶 dart-define 證明覆寫生效**

Run: `flutter test --dart-define=TRIPLINE_API_ORIGIN=https://example.test test/api/api_client_test.dart`
Expected: PASS — 其中「帶 --dart-define 時 origin 被覆寫」測試此時**真正執行**斷言(`kTriplineOrigin == 'https://example.test'`)。把這次輸出存下,作為 PR 描述的端到端證明。

- [ ] **Step 6: 更新文件**

`docs/PORTING_PLAN.md:21`,把:
```
1. Base URL `https://trip-planner-dby.pages.dev/api`，可用 `--dart-define=TRIPLINE_API_URL` 覆寫
```
改成:
```
1. Base URL `https://trip-planner-dby.pages.dev/api`，origin 可用 `--dart-define=TRIPLINE_API_ORIGIN`（值為 origin，不含 /api）覆寫；同一 origin 也用於 CSRF Origin header
```

`TODOS.md`,把技術債第一項:
```
- [ ] `--dart-define=TRIPLINE_API_URL` base URL 覆寫（PORTING_PLAN 規劃項，尚未實作；目前僅能以 `ApiClient(origin:)` 建構參數覆寫）
```
改成:
```
- [x] `--dart-define=TRIPLINE_API_ORIGIN` base URL 覆寫（**Completed:** 2026-06-10）
```

建立 `docs/howto-local-backend.md`:
```markdown
# How-to:本機開發指向本機後端

預設連正式站 `https://trip-planner-dby.pages.dev`。本機跑後端時,用 `--dart-define`
覆寫 origin(值為 origin,**不含** `/api`;app 會自動補 `/api`,並用同一 origin 當
CSRF `Origin` header):

```bash
flutter run --dart-define=TRIPLINE_API_ORIGIN=http://localhost:8787
```

多個 define 可重複加旗標,或用 `--dart-define-from-file`。

## 驗證覆寫生效

```bash
flutter test --dart-define=TRIPLINE_API_ORIGIN=https://example.test \
  test/api/api_client_test.dart
```

`dart-define TRIPLINE_API_ORIGIN` group 的「帶 --dart-define 時 origin 被覆寫」測試
會在帶旗標時真正斷言 `kTriplineOrigin` 已變為注入值。

## 注意

- 連 prod 時 mutating 操作(刪除等)會真的打到正式資料,請改指本機後端再測破壞性流程。
- 後端 CSRF 採 Origin allowlist;本機後端需允許你傳入的 origin。
```

- [ ] **Step 7: run 全套確認無 regression**

Run: `flutter test`
Expected: PASS（146:既有 144 + 新 2)

- [ ] **Step 8: Commit**

```bash
git add lib/api/api_client.dart test/api/api_client_test.dart docs/PORTING_PLAN.md docs/howto-local-backend.md TODOS.md
git commit -m "feat: --dart-define=TRIPLINE_API_ORIGIN base URL 覆寫" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `resolveEntryTone` 色階對應測試

**Files:**
- Create: `test/features/trip_detail/widgets/entry_tone_test.dart`

- [ ] **Step 1: 寫測試**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/widgets/entry_tone.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  const tones = TpTones.light;

  void expectTone(
    EntryToneColors actual, {
    required Color base,
    required Color deep,
    required Color subtle,
    required Color bg,
  }) {
    expect(actual.base, base);
    expect(actual.deep, deep);
    expect(actual.subtle, subtle);
    expect(actual.bg, bg);
  }

  group('resolveEntryTone', () {
    test('hotel / transport / parking → sage', () {
      for (final poiType in ['hotel', 'transport', 'parking']) {
        expectTone(
          resolveEntryTone(tones, poiType),
          base: tones.sage,
          deep: tones.sageDeep,
          subtle: tones.sageSubtle,
          bg: tones.sageBg,
        );
      }
    });

    test('restaurant → pink', () {
      expectTone(
        resolveEntryTone(tones, 'restaurant'),
        base: tones.pink,
        deep: tones.pinkDeep,
        subtle: tones.pinkSubtle,
        bg: tones.pinkBg,
      );
    });

    test('其他類型與 null → accent', () {
      for (final poiType in [null, 'attraction', 'shopping', 'activity']) {
        expectTone(
          resolveEntryTone(tones, poiType),
          base: tones.accent,
          deep: tones.accentDeep,
          subtle: tones.accentSubtle,
          bg: tones.accentBg,
        );
      }
    });
  });
}
```

- [ ] **Step 2: run（預期 PASS;可選 mutation check)**

Run: `flutter test test/features/trip_detail/widgets/entry_tone_test.dart`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/features/trip_detail/widgets/entry_tone_test.dart
git commit -m "test: resolveEntryTone 三色 tone 對應" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `TravelPill` + `iconForType` 測試

**Files:**
- Create: `test/features/trip_detail/widgets/travel_pill_test.dart`

- [ ] **Step 1: 寫測試**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/features/trip_detail/widgets/travel_pill.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpPill(WidgetTester tester, Travel travel) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: TravelPill(travel: travel))),
  ));
}

void main() {
  group('TravelPill.iconForType', () {
    test('已知類型對應 icon', () {
      expect(TravelPill.iconForType('walk'), Icons.directions_walk);
      expect(TravelPill.iconForType('car'), Icons.directions_car);
      expect(TravelPill.iconForType('drive'), Icons.directions_car);
      expect(TravelPill.iconForType('taxi'), Icons.local_taxi);
      expect(TravelPill.iconForType('bus'), Icons.directions_bus);
      expect(TravelPill.iconForType('train'), Icons.train);
      expect(TravelPill.iconForType('tram'), Icons.tram);
      expect(TravelPill.iconForType('flight'), Icons.flight);
      expect(TravelPill.iconForType('ferry'), Icons.directions_boat);
      expect(TravelPill.iconForType('bike'), Icons.directions_bike);
    });

    test('未知類型 → Icons.route', () {
      expect(TravelPill.iconForType('teleport'), Icons.route);
    });
  });

  group('TravelPill 渲染', () {
    testWidgets('有 min → 「N 分鐘」', (tester) async {
      await pumpPill(tester, const Travel(type: 'walk', min: 12));
      expect(find.text('12 分鐘'), findsOneWidget);
      expect(find.byIcon(Icons.directions_walk), findsOneWidget);
    });

    testWidgets('無 min 有 desc → desc', (tester) async {
      await pumpPill(tester, const Travel(type: 'train', desc: '搭單軌到首里'));
      expect(find.text('搭單軌到首里'), findsOneWidget);
    });

    testWidgets('min 與 desc 皆無 → 「移動」', (tester) async {
      await pumpPill(tester, const Travel(type: 'bus'));
      expect(find.text('移動'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: run** — `flutter test test/features/trip_detail/widgets/travel_pill_test.dart` — Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/features/trip_detail/widgets/travel_pill_test.dart
git commit -m "test: TravelPill 標籤 fallback 與 iconForType" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `DayPills` + `shortDate` 測試

**Files:**
- Create: `test/features/trip_detail/widgets/day_pills_test.dart`

- [ ] **Step 1: 寫測試**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/features/trip_detail/widgets/day_pills.dart';
import 'package:tripline/theme/app_theme.dart';

const _days = [
  TripDay(id: 1, dayNum: 1, date: '2026-06-10', version: 0),
  TripDay(id: 2, dayNum: 2, date: '2026-06-11', version: 0),
  TripDay(id: 3, dayNum: 3, date: '2026-06-12', version: 0),
];

void main() {
  group('DayPills.shortDate', () {
    test('YYYY-MM-DD → M/D', () {
      expect(DayPills.shortDate('2026-06-10'), '6/10');
      expect(DayPills.shortDate('2026-12-01'), '12/1');
    });
    test('null → 空字串', () => expect(DayPills.shortDate(null), ''));
    test('非日期字串原樣回傳', () {
      expect(DayPills.shortDate('not-a-date'), 'not-a-date');
      expect(DayPills.shortDate('2026-06'), '2026-06');
    });
  });

  group('DayPills 渲染與互動', () {
    testWidgets('渲染 N 個 pill,點擊回呼該 dayNum', (tester) async {
      int? selectedDayNum;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DayPills(
            days: _days,
            activeDayNum: 1,
            onDaySelected: (dayNum) => selectedDayNum = dayNum,
          ),
        ),
      ));

      expect(find.text('DAY 01'), findsOneWidget);
      expect(find.text('DAY 02'), findsOneWidget);
      expect(find.text('DAY 03'), findsOneWidget);
      expect(find.text('6/10'), findsOneWidget);

      await tester.tap(find.text('DAY 02'));
      expect(selectedDayNum, 2);
    });
  });
}
```

- [ ] **Step 2: run** — `flutter test test/features/trip_detail/widgets/day_pills_test.dart` — Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/features/trip_detail/widgets/day_pills_test.dart
git commit -m "test: DayPills shortDate 與點擊回呼" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `DayHeader` 測試

**Files:**
- Create: `test/features/trip_detail/widgets/day_header_test.dart`

- [ ] **Step 1: 寫測試**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/features/trip_detail/widgets/day_header.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpHeader(WidgetTester tester, TripDay day) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: DayHeader(day: day)),
  ));
}

void main() {
  group('DayHeader', () {
    testWidgets('DAY NN 補零 + 日期(全形括號) + displayTitle', (tester) async {
      await pumpHeader(
        tester,
        const TripDay(
          id: 1,
          dayNum: 3,
          date: '2026-06-12',
          dayOfWeek: '週五',
          title: '首里城與國際通',
          version: 0,
        ),
      );
      expect(find.text('DAY 03'), findsOneWidget);
      expect(find.text('2026-06-12（週五）'), findsOneWidget);
      expect(find.text('首里城與國際通'), findsOneWidget);
    });

    testWidgets('date / dayOfWeek 皆 null → 不顯示日期列,title 退回 Day N',
        (tester) async {
      await pumpHeader(tester, const TripDay(id: 2, dayNum: 2, version: 0));
      expect(find.text('DAY 02'), findsOneWidget);
      // displayTitle fallback chain: title → label → 'Day N'
      expect(find.text('Day 2'), findsOneWidget);
      expect(find.textContaining('（'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: run** — `flutter test test/features/trip_detail/widgets/day_header_test.dart` — Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/features/trip_detail/widgets/day_header_test.dart
git commit -m "test: DayHeader DAY 補零 / 日期 / displayTitle fallback" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `HotelCard` 測試

**Files:**
- Create: `test/features/trip_detail/widgets/hotel_card_test.dart`

- [ ] **Step 1: 寫測試**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/features/trip_detail/widgets/hotel_card.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpHotel(WidgetTester tester, DayHotel hotel) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: HotelCard(hotel: hotel)),
  ));
}

void main() {
  group('HotelCard', () {
    testWidgets('name + checkout + note 全顯示,並有 ValueKey', (tester) async {
      await pumpHotel(
        tester,
        const DayHotel(
          id: 7,
          name: 'ANA 萬座海濱洲際',
          checkout: '11:00',
          note: '海景房',
        ),
      );
      expect(find.text('ANA 萬座海濱洲際'), findsOneWidget);
      expect(find.text('退房 11:00'), findsOneWidget);
      expect(find.text('海景房'), findsOneWidget);
      expect(find.byKey(const ValueKey('hotel-card-7')), findsOneWidget);
      expect(find.byIcon(Icons.bed_outlined), findsOneWidget);
    });

    testWidgets('checkout / note 為 null → 不顯示對應列', (tester) async {
      await pumpHotel(tester, const DayHotel(id: 8, name: '青年旅館'));
      expect(find.text('青年旅館'), findsOneWidget);
      expect(find.textContaining('退房'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: run** — `flutter test test/features/trip_detail/widgets/hotel_card_test.dart` — Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/features/trip_detail/widgets/hotel_card_test.dart
git commit -m "test: HotelCard checkout/note 條件顯示" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: `TimelineEntryTile` 測試

**Files:**
- Create: `test/features/trip_detail/widgets/timeline_entry_tile_test.dart`

說明:`entry.master` 型別為 `EntryPoiInfo`(欄位 `type`/`name`/`category`/`rating`)。圓點 `Container` 的 key 為 `ValueKey('entry-dot-<id>')`,色 = `tone.deep`。

- [ ] **Step 1: 寫測試**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/features/trip_detail/widgets/timeline_entry_tile.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpTile(
  WidgetTester tester,
  TimelineEntry entry, {
  bool isFirst = false,
  bool isLast = false,
}) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: TimelineEntryTile(entry: entry, isFirst: isFirst, isLast: isLast),
    ),
  ));
}

Color dotColor(WidgetTester tester, int entryId) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey('entry-dot-$entryId')),
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  const tones = TpTones.light;

  group('TimelineEntryTile', () {
    testWidgets('顯示時間、標題、master meta（名稱/分類/評分)', (tester) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 1,
          sortOrder: 0,
          version: 0,
          startTime: '09:30',
          title: '美麗海水族館',
          description: '世界最大級水槽',
          master: EntryPoiInfo(
            poiId: 100,
            name: '沖縄美ら海水族館',
            type: 'attraction',
            category: '景點',
            rating: 4.6,
          ),
        ),
      );
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('沖縄美ら海水族館'), findsOneWidget); // master.name ≠ title 才顯示
      expect(find.text('景點'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('世界最大級水槽'), findsOneWidget);
    });

    testWidgets('圓點色依 tone:restaurant → pinkDeep', (tester) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 2,
          sortOrder: 0,
          version: 0,
          title: '暖暮拉麵',
          master: EntryPoiInfo(poiId: 1, type: 'restaurant'),
        ),
      );
      expect(dotColor(tester, 2), tones.pinkDeep);
    });

    testWidgets('master 為 null → accentDeep;startTime 缺則用 time', (tester) async {
      await pumpTile(
        tester,
        const TimelineEntry(
          id: 3,
          sortOrder: 0,
          version: 0,
          time: '14:00',
          title: '自由活動',
        ),
      );
      expect(dotColor(tester, 3), tones.accentDeep);
      expect(find.text('14:00'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: run** — `flutter test test/features/trip_detail/widgets/timeline_entry_tile_test.dart` — Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/features/trip_detail/widgets/timeline_entry_tile_test.dart
git commit -m "test: TimelineEntryTile meta 顯示與圓點 tone 色" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: `TripCard` + `displayTitle` 測試

**Files:**
- Create: `test/features/trips/trip_card_test.dart`

- [ ] **Step 1: 寫測試**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/features/trips/trip_card.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpCard(
  WidgetTester tester,
  TripSummary trip, {
  TripCardTone tone = TripCardTone.accent,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: TripCard(
        trip: trip,
        tone: tone,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    ),
  ));
}

void main() {
  group('TripSummary.displayTitle', () {
    test('title 有值 → title(trim)', () {
      expect(
        const TripSummary(tripId: 't', name: 'okinawa', title: '  沖繩  ')
            .displayTitle,
        '沖繩',
      );
    });
    test('title null / 空字串 → 退回 name', () {
      expect(
        const TripSummary(tripId: 't', name: 'okinawa').displayTitle,
        'okinawa',
      );
      expect(
        const TripSummary(tripId: 't', name: 'okinawa', title: '   ')
            .displayTitle,
        'okinawa',
      );
    });
  });

  group('TripCard 渲染與互動', () {
    testWidgets('cover 首字、eyebrow、標題;tap / long-press 回呼', (tester) async {
      var tapped = 0;
      var longPressed = 0;
      await pumpCard(
        tester,
        const TripSummary(
          tripId: 'okinawa',
          name: 'okinawa',
          title: '沖繩家族之旅',
          totalDays: 5,
        ),
        onTap: () => tapped++,
        onLongPress: () => longPressed++,
      );

      expect(find.text('沖繩家族之旅'), findsOneWidget);
      expect(find.text('沖'), findsOneWidget); // cover 首字
      expect(find.text('5 天'), findsOneWidget); // eyebrow

      await tester.tap(find.text('沖繩家族之旅'));
      await tester.longPress(find.text('沖繩家族之旅'));
      expect(tapped, 1);
      expect(longPressed, 1);
    });

    testWidgets('totalDays 為 null → 不顯示 eyebrow', (tester) async {
      await pumpCard(
        tester,
        const TripSummary(tripId: 'b', name: 'busan', title: '釜山美食團'),
      );
      expect(find.text('釜山美食團'), findsOneWidget);
      expect(find.textContaining('天'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: run** — `flutter test test/features/trips/trip_card_test.dart` — Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/features/trips/trip_card_test.dart
git commit -m "test: TripCard displayTitle / eyebrow / 點擊回呼" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: `PlaceholderScreen` + `AppShell` 5-tab 導航測試

**Files:**
- Create: `test/features/shell/app_shell_test.dart`

說明:`AppShell` 需 `StatefulNavigationShell`,只能經 `StatefulShellRoute` 建構。用自建 router + 探針 branch(內容用不會撞 tab label 的字串)聚焦測 `goBranch` 切換。

- [ ] **Step 1: 寫測試**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tripline/features/shell/app_shell.dart';
import 'package:tripline/theme/app_theme.dart';

GoRouter buildShellRouter() {
  StatefulShellBranch probe(String path, String marker) => StatefulShellBranch(
        routes: [GoRoute(path: path, builder: (_, __) => Text(marker))],
      );
  return GoRouter(
    initialLocation: '/chat',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          probe('/chat', 'PROBE-CHAT'),
          probe('/trips', 'PROBE-TRIPS'),
          probe('/map', 'PROBE-MAP'),
          probe('/favorites', 'PROBE-FAV'),
          probe('/account', 'PROBE-ACCOUNT'),
        ],
      ),
    ],
  );
}

void main() {
  group('PlaceholderScreen', () {
    testWidgets('顯示 title 與「即將推出」', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PlaceholderScreen(title: '收藏'),
      ));
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('即將推出'), findsOneWidget);
    });
  });

  group('AppShell 5-tab 導航', () {
    testWidgets('5 個 tab,點擊切換到對應 branch', (tester) async {
      await tester.pumpWidget(MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: buildShellRouter(),
      ));
      await tester.pumpAndSettle();

      // 初始 branch 0
      expect(find.text('PROBE-CHAT'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(5));

      // 點「地圖」→ branch 2
      await tester.tap(find.text('地圖'));
      await tester.pumpAndSettle();
      expect(find.text('PROBE-MAP'), findsOneWidget);
      expect(find.text('PROBE-CHAT'), findsNothing);

      // 點「帳號」→ branch 4
      await tester.tap(find.text('帳號'));
      await tester.pumpAndSettle();
      expect(find.text('PROBE-ACCOUNT'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: run** — `flutter test test/features/shell/app_shell_test.dart` — Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/features/shell/app_shell_test.dart
git commit -m "test: AppShell 5-tab goBranch 切換 + PlaceholderScreen" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: 跨畫面流程測試

**Files:**
- Create: `test/flows/trip_browsing_flow_test.dart`

說明:兩個流程——(A)未登入填表登入 → 清單;(B)已登入 清單→時間軸→筆記。皆用真 `TriplineApp`(真 router),override repository。`login` 為 named 參數,mocktail 用 `any(named: ...)`。

- [ ] **Step 1: 寫測試**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/features/trip_detail/trip_notes_screen.dart';
import 'package:tripline/features/trip_detail/trip_timeline_screen.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/main.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/user.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockTripRepository extends Mock implements TripRepository {}

/// 已登入的假 AuthNotifier(不打 API)。
class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  Future<UserInfo?> build() async =>
      const UserInfo(id: 'u1', email: 'ray@example.com', displayName: 'Ray');
}

const _trip = Trip(id: 'okinawa', name: 'okinawa', title: '沖繩家族之旅');
const _days = [
  TripDay(
    id: 1,
    dayNum: 1,
    title: '抵達那霸',
    version: 0,
    timeline: [
      TimelineEntry(
        id: 11,
        sortOrder: 0,
        version: 0,
        startTime: '10:00',
        title: '那霸機場',
      ),
    ],
  ),
];

void main() {
  testWidgets('A:未登入填表登入 → 進入行程清單', (tester) async {
    final mockAuth = _MockAuthRepository();
    final mockTrips = _MockTripRepository();
    when(() => mockAuth.currentUser()).thenAnswer((_) async => null);
    when(() => mockAuth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async =>
        const UserInfo(id: 'u1', email: 'ray@example.com'));
    when(mockTrips.fetchMyTrips).thenAnswer((_) async => const <TripSummary>[]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuth),
        tripRepositoryProvider.overrideWithValue(mockTrips),
      ],
      child: const TriplineApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'ray@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(TripsListScreen), findsOneWidget);
    verify(() => mockAuth.login(email: 'ray@example.com', password: 'secret'))
        .called(1);
  });

  testWidgets('B:已登入 清單→點卡片→時間軸→點筆記→筆記頁', (tester) async {
    final mockTrips = _MockTripRepository();
    when(mockTrips.fetchMyTrips).thenAnswer((_) async => const [
          TripSummary(
            tripId: 'okinawa',
            name: 'okinawa',
            title: '沖繩家族之旅',
            totalDays: 1,
          ),
        ]);
    when(() => mockTrips.fetchTrip('okinawa')).thenAnswer((_) async => _trip);
    when(() => mockTrips.fetchDays('okinawa')).thenAnswer((_) async => _days);
    when(() => mockTrips.fetchNotes('okinawa'))
        .thenAnswer((_) async => const TripNotes());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
        tripRepositoryProvider.overrideWithValue(mockTrips),
      ],
      child: const TriplineApp(),
    ));
    await tester.pumpAndSettle();

    // 清單
    expect(find.byType(TripsListScreen), findsOneWidget);
    expect(find.text('沖繩家族之旅'), findsOneWidget);

    // 點卡片 → 時間軸
    await tester.tap(find.text('沖繩家族之旅'));
    await tester.pumpAndSettle();
    expect(find.byType(TripTimelineScreen), findsOneWidget);
    expect(find.text('那霸機場'), findsOneWidget);

    // 點筆記 action → 筆記頁
    await tester.tap(find.byTooltip('筆記'));
    await tester.pumpAndSettle();
    expect(find.byType(TripNotesScreen), findsOneWidget);
    expect(find.text('行程筆記'), findsOneWidget);
  });
}
```

- [ ] **Step 2: run** — `flutter test test/flows/trip_browsing_flow_test.dart` — Expected: PASS

除錯提示(用 superpowers:systematic-debugging):
- 流程 A 仍停 LoginScreen:確認 `authRepositoryProvider` 被 override、`currentUser` 回 `null`、`login` 回 user;login 成功後 `authState` 轉 data → router `refreshListenable` 重算 redirect。
- `login` 為 named 參數,mocktail 須用 `any(named: 'email')` / `any(named: 'password')`(String 無需 `registerFallbackValue`)。
- 若 `pumpAndSettle` timeout:多半是某 loading 的 `CircularProgressIndicator` 永久存在(mock 未 resolve)。確認所有 mock 都 `thenAnswer` 立即回值;暫態 indicator 不會卡 settle,永久 loading 才會。

- [ ] **Step 3: Commit**

```bash
git add test/flows/trip_browsing_flow_test.dart
git commit -m "test: 登入與行程瀏覽跨畫面流程" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: device smoke test(`integration_test/`)

**Files:**
- Modify: `pubspec.yaml`(dev_dependencies)
- Create: `integration_test/app_smoke_test.dart`

- [ ] **Step 1: 加 dev_dependency**(`pubspec.yaml`,`dev_dependencies:` 區塊內 `flutter_test:` 之後)

```yaml
  integration_test:
    sdk: flutter
```

- [ ] **Step 2: pub get**

Run: `flutter pub get`
Expected: 成功解析 integration_test

- [ ] **Step 3: 寫 smoke test**

```dart
/// device smoke:app 啟動(未登入、完全不打 prod API)→ 停在登入頁。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/main.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockTripRepository extends Mock implements TripRepository {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app 啟動 → 登入頁(未登入,不打 prod)', (tester) async {
    final mockAuth = _MockAuthRepository();
    final mockTrips = _MockTripRepository();
    when(() => mockAuth.currentUser()).thenAnswer((_) async => null);
    when(mockTrips.fetchMyTrips).thenAnswer((_) async => const []);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuth),
        tripRepositoryProvider.overrideWithValue(mockTrips),
      ],
      child: const TriplineApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
```

- [ ] **Step 4: 嘗試執行(需模擬器/實機)**

Run: `flutter test integration_test/app_smoke_test.dart`
Expected: PASS。**若無可用 device/模擬器而失敗**:記下實際錯誤訊息,於 PR 描述標明「device smoke 已撰寫,因 CI/代理環境無 device 未能在此跑綠,需本機驗證」。不得假裝通過。

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock integration_test/app_smoke_test.dart
git commit -m "test: integration_test device smoke(啟動到登入頁)" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: 全套驗收 + CHANGELOG

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: analyze**

Run: `flutter analyze`
Expected: `No issues found!`(若有,逐一修)

- [ ] **Step 2: 全套 test**

Run: `flutter test`
Expected: 全綠。新增約 25+ 測試(2 dart-define + 各 widget/logic/流程),總數應為 144 + 新增。記下實際 passed 數。

- [ ] **Step 3: 更新 CHANGELOG**(`CHANGELOG.md`,`## [Unreleased]` 或新版段落;對齊既有格式)

```markdown
### Added
- `--dart-define=TRIPLINE_API_ORIGIN`:可在 build/run 時覆寫 API origin（本機後端開發），預設仍為正式站。新增 `docs/howto-local-backend.md`。
- 測試補強:trip_detail widgets（DayHeader/DayPills/HotelCard/TravelPill/TimelineEntryTile/entry_tone）、TripCard、AppShell 5-tab 導航、跨畫面流程（登入＋瀏覽）、integration_test device smoke。

### Changed
- `kTriplineOrigin` 由固定常數改為 `String.fromEnvironment`（預設值不變）。
- `docs/PORTING_PLAN.md`:`TRIPLINE_API_URL` 更正為 `TRIPLINE_API_ORIGIN`（origin 語意）。
```

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: CHANGELOG 記錄 dart-define 與測試補強" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: 交付**

- `git push -u origin feat/dart-define-and-tests`
- 開 PR(或用 `/ship`)。PR 描述須含:Task 1 Step 5 的 dart-define 端到端證明、device smoke 執行結果(綠或環境限制說明)、`flutter test` 最終 passed 數。

---

## 驗收條件(對照 spec)

- [ ] `flutter analyze` 0 issues。
- [ ] `flutter test` 全綠(既有 144 + 新增)。
- [ ] dart-define 端到端:`flutter test --dart-define=TRIPLINE_API_ORIGIN=https://example.test test/api/api_client_test.dart` 通過且覆寫測試真正執行。
- [ ] device smoke:環境允許則綠,否則文件化交付並說明。
- [ ] PORTING_PLAN / TODOS / CHANGELOG / howto-local-backend 更新完成。
