# WS-A 導覽統一 + WS-B 交通 label 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 3 個根層清單頁升級成 iOS 原生大標題(捲動收合),統一全 app 標題/捲動慣例;並在時間軸交通 pill 顯示方式文字 label(區分地鐵/火車/高鐵/單軌)。

**Architecture:** 在既有 `lib/app/adaptive.dart` 加一個**最小侵入的 adaptive 大標題 sliver**(`SliverAdaptiveLargeTitle`):iOS/macOS → `CupertinoSliverNavigationBar`(原生大標題 + 捲動收合 + 模糊),其餘平台 → Material `SliverAppBar.large`。各清單頁只把第一個 sliver 換成它,保留原本 Scaffold/RefreshIndicator/FAB/body slivers。C3 明細頁已是一致的 `AppBar`,不動。WS-B 把交通方式 SoT(`_methods`)抽到 `lib/models/travel_method.dart` 並加 `travelMethodLabel`,pill 與 edit sheet 共用。

**Tech Stack:** Flutter 3.11 / Dart 3、flutter_riverpod 3.x、`Theme.of(context).platform` 平台分支、`flutter_test`(widget test）。

## Global Constraints

- 文件、註解、commit message 一律繁體中文(台灣),技術名詞保留英文。
- TDD 紅綠重構:production code 變更前先寫失敗測試。
- 完成定義:`flutter analyze` 零 error/warning + `flutter test` 全綠。
- 不直接 commit 到 `master`;在 feature branch 上進行。
- 平台自適應一律用 `Theme.of(context).platform`(非 `defaultTargetPlatform`),測試以 `ThemeData(platform:)` override。
- 設計禁忌:無 gradient、無 emoji icon、無 rainbow 色;icon 用 `CupertinoIcons`/`Icons`。
- 語意色走 `colorScheme`;三色 tone 走 `Theme.of(context).extension<TpTones>()!`,不直接引用 `TpColorsLight/Dark`。
- 既有 gotcha:測試平台常解析為 macOS(Apple)→ adaptive helper 走 Cupertino 分支;`SliverAppBar.large` 雙渲染標題 → `find.text` 用 `findsWidgets`。

## 分支前置

- 本計畫工作基準 = 目前 `fix/timeline-recompute-use-after-dispose` HEAD(已含 timeline sync,WS-B 六成基礎)。
- 新開分支 `feature/native-nav-and-travel-label`(off 現有 HEAD),完工 `/ship` 出 PR。D4(現有分支落地)由使用者於 GitHub 決定合併時機,不阻塞本計畫。

## File Structure

- **Create** `lib/models/travel_method.dart` — 交通方式 SoT:`TravelMethod` record 清單 + `travelMethodLabel(String type, {String? submode})`。純 Dart。
- **Modify** `lib/app/adaptive.dart` — 加 `SliverAdaptiveLargeTitle`。
- **Modify** `lib/features/trips/trips_list_screen.dart:266` — `SliverAppBar.large` → `SliverAdaptiveLargeTitle`。
- **Modify** `lib/features/favorites/favorites_screen.dart:28` — 同上。
- **Modify** `lib/features/account/account_screen.dart:37` — 同上。
- **Modify** `lib/features/trip_detail/widgets/travel_edit_sheet.dart:12-35` — `_methods` 改 import 自 `travel_method.dart`。
- **Modify** `lib/features/trip_detail/widgets/travel_pill.dart:63-80` — label 前置方式名。
- **Test** `test/app/adaptive_large_title_test.dart`(新)、`test/models/travel_method_test.dart`(新);既有 `test/features/trips/...`、`travel_pill` 相關測試依需更新。

---

### Task 1: `SliverAdaptiveLargeTitle` adaptive 大標題 sliver

**Files:**
- Modify: `lib/app/adaptive.dart`(檔尾新增)
- Test: `test/app/adaptive_large_title_test.dart`

**Interfaces:**
- Produces: `class SliverAdaptiveLargeTitle extends StatelessWidget` — 建構子 `({Key? key, required String title, List<Widget> actions = const [], bool automaticallyImplyLeading = true})`。回傳一個 sliver(iOS `CupertinoSliverNavigationBar` / 其餘 `SliverAppBar.large`)。

- [ ] **Step 1: 寫失敗測試**

```dart
// test/app/adaptive_large_title_test.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/adaptive.dart';

Widget _host(TargetPlatform platform) => MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: CustomScrollView(
          slivers: const [
            SliverAdaptiveLargeTitle(title: '我的行程'),
            SliverToBoxAdapter(child: SizedBox(height: 1200, child: Text('body'))),
          ],
        ),
      ),
    );

void main() {
  testWidgets('iOS 走 CupertinoSliverNavigationBar 並顯示標題', (tester) async {
    await tester.pumpWidget(_host(TargetPlatform.iOS));
    expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
    expect(find.text('我的行程'), findsWidgets);
  });

  testWidgets('Android 走 SliverAppBar.large 並顯示標題', (tester) async {
    await tester.pumpWidget(_host(TargetPlatform.android));
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.text('我的行程'), findsWidgets);
  });

  testWidgets('actions 會渲染在標題列', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Scaffold(
        body: CustomScrollView(slivers: [
          SliverAdaptiveLargeTitle(
            title: 'X',
            actions: [
              IconButton(
                key: const ValueKey('act'),
                icon: const Icon(CupertinoIcons.add),
                onPressed: () {},
              ),
            ],
          ),
        ]),
      ),
    ));
    expect(find.byKey(const ValueKey('act')), findsOneWidget);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/app/adaptive_large_title_test.dart`
Expected: FAIL(`SliverAdaptiveLargeTitle` 未定義)

- [ ] **Step 3: 實作**

在 `lib/app/adaptive.dart` 檔尾加(`flutter/cupertino.dart` 已 import):

```dart
/// 平台自適應大標題 sliver(root 清單頁用)。
///
/// - iOS/macOS → [CupertinoSliverNavigationBar]:原生大標題,捲動平滑收合成置中
///   inline 標題 + 半透明模糊(scroll-under),對標 Apple 設定/Mail/Notes。
/// - 其餘平台 → Material [SliverAppBar.large]。
///
/// 只負責標題列;搜尋/篩選等放在此 sliver「之後」的 sliver(隨內容捲動)。
class SliverAdaptiveLargeTitle extends StatelessWidget {
  const SliverAdaptiveLargeTitle({
    super.key,
    required this.title,
    this.actions = const [],
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final List<Widget> actions;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (isApple) {
      return CupertinoSliverNavigationBar(
        largeTitle: Text(title),
        automaticallyImplyLeading: automaticallyImplyLeading,
        trailing: actions.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions),
      );
    }

    return SliverAppBar.large(
      pinned: true,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: Text(title),
      actions: actions.isEmpty ? null : actions,
    );
  }
}
```

**驗證點(執行時確認,非 placeholder)**:①`CupertinoSliverNavigationBar` 的 `trailing` 為單一 Widget,故多 action 包 `Row`。②Material `IconButton` 置於 Cupertino nav bar `trailing` 需 Material 祖先 — Scaffold 已提供;若拋「No Material widget」則把 action 包 `Material(type: transparency)` 或改 `CupertinoButton`。③深色模式若 Cupertino 預設底色突兀,加 `backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)`。

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/app/adaptive_large_title_test.dart`
Expected: PASS(3 綠)

- [ ] **Step 5: analyze**

Run: `flutter analyze lib/app/adaptive.dart test/app/adaptive_large_title_test.dart`
Expected: 零 error/warning

- [ ] **Step 6: commit**

```bash
git add lib/app/adaptive.dart test/app/adaptive_large_title_test.dart
git commit -m "feat: 加 SliverAdaptiveLargeTitle(iOS 原生大標題 adaptive sliver)"
```

---

### Task 2: 遷移 trips_list 到原生大標題

**Files:**
- Modify: `lib/features/trips/trips_list_screen.dart:266-314`(`SliverAppBar.large(...)` 整塊)
- Test: 既有 `test/features/trips/trips_list_screen_test.dart`(跑回歸,依需調整)

**Interfaces:**
- Consumes: `SliverAdaptiveLargeTitle`(Task 1)

- [ ] **Step 1: 先跑既有 trips_list 測試建立綠色基準**

Run: `flutter test test/features/trips/trips_list_screen_test.dart`
Expected: PASS(記錄目前綠;若已有 large-title `findsWidgets` 斷言,遷移後仍應成立)

- [ ] **Step 2: 替換 app bar sliver**

把 `trips_list_screen.dart` build() 內 `SliverAppBar.large(...)`(行 266–314,含 `title`/`actions` 兩顆 IconButton/PopupMenuButton)整塊換成:

```dart
SliverAdaptiveLargeTitle(
  title: '我的行程',
  automaticallyImplyLeading: false,
  actions: [
    IconButton(
      key: const ValueKey('trips-list-import-trigger'),
      tooltip: '匯入行程 JSON',
      icon: _isImporting
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : const Icon(CupertinoIcons.cloud_upload),
      onPressed: _isImporting ? null : _importTripFromJson,
    ),
    PopupMenuButton<TripSortOrder>(
      key: const ValueKey('trips-sort-button'),
      icon: const Icon(CupertinoIcons.arrow_up_arrow_down),
      tooltip: '排序',
      initialValue: _sortOrder,
      onSelected: (order) => setState(() => _sortOrder = order),
      itemBuilder: (context) => const [
        PopupMenuItem(value: TripSortOrder.defaultOrder, child: Text('預設順序')),
        PopupMenuItem(value: TripSortOrder.nameAsc, child: Text('名稱 A→Z')),
        PopupMenuItem(value: TripSortOrder.updatedDesc, child: Text('最新編輯')),
        PopupMenuItem(value: TripSortOrder.startDateAsc, child: Text('出發日')),
      ],
    ),
  ],
),
```

搜尋 + 分段篩選的 `SliverToBoxAdapter`(行 315–370)**維持不動**,續接其後(隨內容捲動,即 Apple 慣例)。確認 `adaptive.dart` 已 export(`import '../../app/adaptive.dart';` 行 12 已在)。

- [ ] **Step 3: 跑 trips_list 測試 + analyze**

Run: `flutter test test/features/trips/trips_list_screen_test.dart && flutter analyze lib/features/trips/trips_list_screen.dart`
Expected: PASS + 零問題。若測試以 `find.byType(SliverAppBar)` 斷言標題,iOS 分支下改為 `find.byWidgetPredicate((w) => w is SliverAppBar || w is CupertinoSliverNavigationBar)`,標題 `find.text` 用 `findsWidgets`。

- [ ] **Step 4: commit**

```bash
git add lib/features/trips/trips_list_screen.dart test/features/trips/trips_list_screen_test.dart
git commit -m "feat: trips_list 改用 iOS 原生大標題"
```

---

### Task 3: 遷移 favorites + account 到原生大標題

**Files:**
- Modify: `lib/features/favorites/favorites_screen.dart:28`(`SliverAppBar.large`)
- Modify: `lib/features/account/account_screen.dart:37`(`const SliverAppBar.large(pinned: true, title: Text('帳號'))`)
- Test: 既有 `test/features/favorites/...`、`test/features/account/...`

- [ ] **Step 1: 跑既有測試建立基準**

Run: `flutter test test/features/favorites/ test/features/account/`
Expected: 記錄目前綠。

- [ ] **Step 2: 替換兩頁 app bar sliver**

- `favorites_screen.dart`:把 `SliverAppBar.large(...)` 換成 `SliverAdaptiveLargeTitle(title: <原標題>, actions: <原 actions,若有>)`,`automaticallyImplyLeading` 沿用原值。加 `import '../../app/adaptive.dart';`(若未 import)。
- `account_screen.dart`:`const SliverAppBar.large(pinned: true, title: Text('帳號'))` → `SliverAdaptiveLargeTitle(title: '帳號', automaticallyImplyLeading: false)`(移除 `const`,因 widget 內含 `Theme.of`)。加 import(若未 import)。

- [ ] **Step 3: 跑測試 + analyze**

Run: `flutter test test/features/favorites/ test/features/account/ && flutter analyze lib/features/favorites/favorites_screen.dart lib/features/account/account_screen.dart`
Expected: PASS + 零問題(標題斷言同 Task 2 gotcha 處理)。

- [ ] **Step 4: commit**

```bash
git add lib/features/favorites/favorites_screen.dart lib/features/account/account_screen.dart test/features/favorites/ test/features/account/
git commit -m "feat: favorites/account 改用 iOS 原生大標題"
```

---

### Task 4: WS-B — 交通方式 SoT + pill 顯示方式 label

**Files:**
- Create: `lib/models/travel_method.dart`
- Modify: `lib/features/trip_detail/widgets/travel_edit_sheet.dart:12-45`(`_methods` / `_initialMethodKey` 改用共用 SoT)
- Modify: `lib/features/trip_detail/widgets/travel_pill.dart:63-80`(label 前置方式名)
- Test: `test/models/travel_method_test.dart`(新);既有 `travel_pill` 測試依需更新

**Interfaces:**
- Produces:
  - `typedef TravelMethod = ({String key, String mode, String? submode, String label, bool auto});`
  - `const List<TravelMethod> kTravelMethods;`(現 `_methods` 內容)
  - `String travelMethodLabel(String type, {String? submode});` — 由 `Travel.type`(已把 submode 併入,見 `entry.dart:28-31`)回方式中文名;未知回 `''`。

- [ ] **Step 1: 寫失敗測試**

先讀 web SoT `/Users/ray/Projects/trip-planner/src/lib/travelMode.ts` 取得完整標籤(taxi/flight/boat/bike/tram 等 pill 用到但 `_methods` 未列者),再定測試。已知(來自現有 `_methods`):driving→駕車、walking→步行、monorail→單軌、bus→公車、metro→地鐵、train→火車、hsr→高鐵。

```dart
// test/models/travel_method_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/travel_method.dart';

void main() {
  test('transit submode 各有中文名', () {
    expect(travelMethodLabel('metro'), '地鐵');
    expect(travelMethodLabel('train'), '火車');
    expect(travelMethodLabel('hsr'), '高鐵');
    expect(travelMethodLabel('monorail'), '單軌');
    expect(travelMethodLabel('bus'), '公車');
  });

  test('driving/walking 有中文名', () {
    expect(travelMethodLabel('driving'), '駕車');
    expect(travelMethodLabel('walking'), '步行');
  });

  test('未知 type 回空字串(pill 會 fallback)', () {
    expect(travelMethodLabel('unknowntype'), '');
  });

  test('kTravelMethods 含 8 個編輯選項', () {
    expect(kTravelMethods.length, 8);
    expect(kTravelMethods.map((m) => m.key), contains('other'));
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/models/travel_method_test.dart`
Expected: FAIL(`travel_method.dart` 不存在)

- [ ] **Step 3: 建 SoT 檔**

```dart
// lib/models/travel_method.dart
/// 交通方式 SoT(對照 web `src/lib/travelMode.ts`)。
/// 編輯 sheet 的 8 選項與 pill 的方式標籤共用同一份,避免兩處漂移。
library;

typedef TravelMethod = ({
  String key,
  String mode,
  String? submode,
  String label,
  bool auto,
});

/// 交通編輯 sheet 的 8 個方式選項(auto=可自動偵測)。
const List<TravelMethod> kTravelMethods = [
  (key: 'driving', mode: 'driving', submode: null, label: '駕車', auto: true),
  (key: 'walking', mode: 'walking', submode: null, label: '步行', auto: true),
  (key: 'monorail', mode: 'transit', submode: 'monorail', label: '單軌', auto: true),
  (key: 'bus', mode: 'transit', submode: 'bus', label: '公車', auto: true),
  (key: 'metro', mode: 'transit', submode: 'metro', label: '地鐵', auto: false),
  (key: 'train', mode: 'transit', submode: 'train', label: '火車', auto: false),
  (key: 'hsr', mode: 'transit', submode: 'hsr', label: '高鐵', auto: false),
  (key: 'other', mode: 'transit', submode: null, label: '其他', auto: false),
];

/// `Travel.type` → 方式中文名。`type` 已把 submode 併入(見 entry.dart)。
/// pill 額外會遇到 `_methods` 未列的 type(taxi/flight/boat/bike/tram/car…),
/// 一併對照 web travelMode.ts 補齊;未知回空字串,由 pill 端 fallback。
String travelMethodLabel(String type, {String? submode}) {
  switch (type) {
    case 'driving':
    case 'car':
    case 'drive':
      return '駕車';
    case 'walking':
    case 'walk':
      return '步行';
    case 'monorail':
      return '單軌';
    case 'tram':
      return '路面電車';
    case 'bus':
      return '公車';
    case 'metro':
    case 'subway':
      return '地鐵';
    case 'train':
      return '火車';
    case 'hsr':
      return '高鐵';
    case 'taxi':
      return '計程車';
    case 'flight':
    case 'plane':
      return '航班';
    case 'ferry':
    case 'boat':
      return '渡輪';
    case 'bike':
    case 'cycle':
      return '自行車';
    case 'transit':
      return '大眾運輸';
    default:
      return '';
  }
}
```

**驗證點**:執行時對照 web `travelMode.ts` 校正 taxi/flight/boat/bike/tram/transit 的實際中文用詞(以 web 為準)。

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/models/travel_method_test.dart`
Expected: PASS

- [ ] **Step 5: edit sheet 改用共用 SoT**

`travel_edit_sheet.dart`:刪除本地 `_TravelMethod` typedef(行 12–18)與 `_methods`(行 20–35),改 `import '../../../models/travel_method.dart';`,把 `_methods` 用處改 `kTravelMethods`、型別 `_TravelMethod` 改 `TravelMethod`。`_initialMethodKey`(行 37–45)照舊但引用 `kTravelMethods`。

Run: `flutter test test/features/trip_detail/ && flutter analyze lib/features/trip_detail/widgets/travel_edit_sheet.dart`
Expected: PASS + 零問題(行為不變,純抽取)。

- [ ] **Step 6: pill 顯示方式 label(先寫失敗測試)**

在 `travel_pill` 測試檔(或新增)加:非同地點、有分鐘時,pill 文字含方式名。

```dart
testWidgets('pill 顯示交通方式名 + 分鐘 + 距離', (tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(
      body: TravelPill(
        travel: Travel(type: 'metro', submode: 'metro', min: 25, distanceM: 3000),
      ),
    ),
  ));
  expect(find.textContaining('地鐵'), findsOneWidget);
  expect(find.textContaining('25 分鐘'), findsOneWidget);
});
```

Run: 該測試 → FAIL(目前無方式名)。

- [ ] **Step 7: pill label 前置方式名**

`travel_pill.dart` build():`import '../../../models/travel_method.dart';`。改 label 組法(行 63–80),在非 sameplace/非 status 分支前置方式名:

```dart
final method = sameplace ? '' : travelMethodLabel(travel.type, submode: travel.submode);
final String core;
if (hasMin && hasDist) {
  core = '${travel.min} 分鐘 · ${_formatDistance(travel.distanceM!)}';
} else if (hasMin) {
  core = '${travel.min} 分鐘';
} else if (hasDist) {
  core = _formatDistance(travel.distanceM!);
} else {
  core = travel.desc ?? '移動';
}

if (sameplace) {
  label = '同一地點';
} else if (hasStatus) {
  label = statusLabel!;
} else if (method.isEmpty) {
  label = core;
} else {
  label = '$method · $core';
}
```

- [ ] **Step 8: 跑測試 + analyze**

Run: `flutter test test/models/ test/features/trip_detail/ && flutter analyze lib/`
Expected: PASS + 零 error/warning。

- [ ] **Step 9: commit**

```bash
git add lib/models/travel_method.dart lib/features/trip_detail/widgets/travel_edit_sheet.dart lib/features/trip_detail/widgets/travel_pill.dart test/models/travel_method_test.dart test/features/trip_detail/
git commit -m "feat: 交通方式共用 SoT + pill 顯示方式名(區分地鐵/火車/高鐵/單軌)"
```

---

### Task 5(選配): 手動覆寫 pill 加鎖標

**Files:** Modify `lib/features/trip_detail/widgets/travel_pill.dart`

先確認 web pill 是否真顯示鎖標(讀 web `src/components/trip/TravelPill.tsx`)。若是:`travel.source == 'manual'` 且非 sameplace 時,在 icon 後加 `Icon(Icons.lock_outline, size: 12, ...)`。附測試:source='manual' 有鎖、source='auto' 無鎖。若 web 無此視覺 → **跳過本 task**。

---

## Self-Review

**Spec coverage(對 spec §4 WS-A / §6 WS-B):**
- WS-A C1 三頁原生大標題 → Task 1–3 ✅
- WS-A C2(map/chat 無大標題)→ 維持現狀,無 task ✅(HIG 慣例)
- WS-A C3 明細頁一致 → 已一致(`AppBar`),無 task ✅
- WS-B DO-1 方式 label → Task 4 ✅
- WS-B DO-2 手動鎖標(選配)→ Task 5 ✅
- 未涵蓋:WS-C(地圖)= 另出 Plan 2,不在本計畫。

**Placeholder scan:** 無 TBD/TODO;兩處「驗證點」為執行時對 web SoT/Flutter API 校正的具體指示(附條件與 fallback),非 vague placeholder。

**Type consistency:** `SliverAdaptiveLargeTitle({title, actions, automaticallyImplyLeading})` 於 Task 2/3 一致使用;`travelMethodLabel(String, {String? submode})`、`kTravelMethods`、`TravelMethod` 於 Task 4 定義並於 edit sheet/pill 一致引用。

**Execution note:** 每 task 結尾 `flutter test`(全域)確保未破壞既有;最終 `/ship` 前跑一次完整 `flutter test` + `flutter analyze`。
