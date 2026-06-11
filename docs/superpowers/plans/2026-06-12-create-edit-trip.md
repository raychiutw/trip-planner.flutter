# 建立／編輯行程 實作計畫

> executing-plans 逐 task TDD。分支 `feat/create-edit-trip`。spec：`docs/superpowers/specs/2026-06-12-create-edit-trip-design.md`。

**Goal:** 行程清單可建立(目的地優先 + 固定/彈性日期 + 每地天數)與編輯(PUT 欄位 + 明確儲存)。
**Tech:** flutter_riverpod 3.x / go_router / dio mock + mocktail / intl + flutter_localizations。單一 PR、3 phase。

**心智模型**：建立衍生 `name`/`id`/`countries` 後 POST；編輯讀 `tripDetailProvider` 帶入、儲存時 diff-only PUT(無 OCC、不動日期/name)。

---

# 階段 0：models + API + 純函式 + localization

## Task 0.1：DestinationInput model

**Files:** 新 `lib/models/destination_input.dart`;test 新 `test/models/destination_input_test.dart`。

- [ ] 測試:`fromPoi` 帶入 name/lat/lng/country;`toCreateJson` 出 snake_case `{name,lat,lng,day_quota}`(null 值省略);`copyWith(dayQuota:)`。
- [ ] 實作:
  ```dart
  /// 建立/編輯行程表單用的目的地值型別(對應後端 destinations[] snake_case)。
  library;

  import 'poi_search_result.dart';

  class DestinationInput {
    const DestinationInput({
      required this.name, this.lat, this.lng, this.country, this.dayQuota,
    });
    final String name;
    final double? lat;
    final double? lng;
    final String? country;
    final int? dayQuota;

    factory DestinationInput.fromPoi(PoiSearchResult p) => DestinationInput(
          name: p.name, lat: p.lat, lng: p.lng, country: p.country,
        );

    DestinationInput copyWith({int? dayQuota}) => DestinationInput(
          name: name, lat: lat, lng: lng, country: country,
          dayQuota: dayQuota ?? this.dayQuota,
        );

    /// 送 POST/PUT 的 destinations[] 元素(snake_case;null 省略)。
    Map<String, dynamic> toJson() => {
          'name': name,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (dayQuota != null) 'day_quota': dayQuota,
        };
  }
  ```
- [ ] 綠 → commit `feat: DestinationInput model（建立/編輯行程目的地）`。

## Task 0.2：trip_form_logic 純函式

**Files:** 新 `lib/features/trips/trip_form_logic.dart`;test 新 `test/features/trips/trip_form_logic_test.dart`。

- [ ] 測試:
  - `slugify('東京、京都')` → `''`(全非 ascii);`slugify('Tokyo Kyoto!!')` → `'tokyo-kyoto'`;首尾/連續分隔收斂。
  - `genTripId('Tokyo', 1717000000000)` → `'tokyo-<base36後4>'`;`genTripId('東京',n)` → `'trip-<base36後4>'`;長度 ≤100。
  - `deriveTripName([a,b])` → `'A、B'`。
  - `deriveCountries`:有 country 去重 join;全無 → `'JP'`。
  - `flexibleRange(2026, 7, 5)` → `('2026-07-01','2026-07-05')`。
  - `tripDayCount('2026-07-01','2026-07-05')` → 5。
  - `isTripDatesValid`:格式錯/順序錯/31 天 → false;正常 → true。
- [ ] 實作:
  ```dart
  /// 建立/編輯行程的純衍生邏輯(無 Flutter 依賴,可單測)。
  library;

  import '../../models/destination_input.dart';

  final _nonSlug = RegExp(r'[^a-z0-9]+');

  String slugify(String s) =>
      s.toLowerCase().replaceAll(_nonSlug, '-').replaceAll(RegExp(r'^-+|-+$'), '');

  /// client 產 tripId:slug + '-' + base36(now) 後 4 碼;slug 空 → 'trip-<suffix>';≤100。
  String genTripId(String name, int nowMillis) {
    final suffix = nowMillis.toRadixString(36);
    final tail = suffix.substring(suffix.length - 4 < 0 ? 0 : suffix.length - 4);
    final base = slugify(name);
    final id = base.isEmpty ? 'trip-$tail' : '$base-$tail';
    return id.length <= 100 ? id : id.substring(0, 100);
  }

  String deriveTripName(List<DestinationInput> dests) =>
      dests.map((d) => d.name).join('、');

  String deriveCountries(List<DestinationInput> dests) {
    final codes = <String>[];
    for (final d in dests) {
      final c = d.country;
      if (c != null && c.isNotEmpty && !codes.contains(c)) codes.add(c);
    }
    return codes.isEmpty ? 'JP' : codes.join(',');
  }

  String _pad2(int n) => n.toString().padLeft(2, '0');
  String _ymd(DateTime d) => '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';

  /// 彈性模式:該月 1 號起算 dayCount 天 → (start, end)。
  (String, String) flexibleRange(int year, int month, int dayCount) {
    final start = DateTime(year, month, 1);
    final end = start.add(Duration(days: dayCount - 1));
    return (_ymd(start), _ymd(end));
  }

  int tripDayCount(String start, String end) {
    final s = DateTime.parse(start);
    final e = DateTime.parse(end);
    return e.difference(s).inDays + 1;
  }

  final _ymdRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  bool isTripDatesValid(String start, String end) {
    if (!_ymdRe.hasMatch(start) || !_ymdRe.hasMatch(end)) return false;
    final days = tripDayCount(start, end);
    return days >= 1 && days <= 30;
  }
  ```
- [ ] 綠 → commit `feat: trip_form_logic（slugify/genTripId/日期推算/驗證）`。

## Task 0.3：trip_repository createTrip/updateTrip

**Files:** `lib/api/trip_repository.dart`;test `test/api/trip_repository_test.dart`。

- [ ] 測試:
  - createTrip:POST `/trips` body `{id,name,startDate,endDate,title,description,countries,published,data_source,lang,destinations:[{name,lat,lng,day_quota}]}` → 201 `{ok:true,tripId:'x',daysCreated:3,destinationsCreated:1}` → 回 record。
  - updateTrip diff:只給 `title` → PUT `/trips/x` body `{title:'新'}`(不含其他 key)。
  - updateTrip destinations:給 destinations → body 含 `destinations` 全量 + `countries`。
  - updateTrip 無 expectedVersion(body 不含該 key)。
- [ ] 實作(加在 TripRepository,參考既有方法風格;import destination_input):
  ```dart
  /// POST /trips（建立;body 混合 camel + snake_case destinations）→ {tripId,...}。
  Future<({String tripId, int daysCreated, int destinationsCreated})> createTrip({
    required String id,
    required String name,
    required String startDate,
    required String endDate,
    String? title,
    String? description,
    String countries = 'JP',
    int published = 1,
    String dataSource = 'manual',
    String lang = 'zh-TW',
    List<DestinationInput> destinations = const [],
  }) async {
    final body = await _client.post('/trips', body: {
      'id': id, 'name': name, 'startDate': startDate, 'endDate': endDate,
      'title': ?title, 'description': ?description,
      'countries': countries, 'published': published,
      'data_source': dataSource, 'lang': lang,
      'destinations': [for (final d in destinations) d.toJson()],
    });
    final map = body as Map<String, dynamic>;
    return (
      tripId: map['tripId'] as String? ?? id,
      daysCreated: (map['daysCreated'] as num?)?.toInt() ?? 0,
      destinationsCreated: (map['destinationsCreated'] as num?)?.toInt() ?? 0,
    );
  }

  /// PUT /trips/:id（編輯;diff-only,只送非 null;無 OCC）。destinations 給了才全量替換。
  Future<void> updateTrip(
    String id, {
    String? name,
    String? title,
    String? description,
    String? countries,
    int? published,
    String? dataSource,
    String? lang,
    List<DestinationInput>? destinations,
  }) async {
    await _client.put('/trips/${Uri.encodeComponent(id)}', body: {
      'name': ?name,
      'title': ?title,
      'description': ?description,
      'countries': ?countries,
      'published': ?published,
      'data_source': ?dataSource,
      'lang': ?lang,
      if (destinations != null)
        'destinations': [for (final d in destinations) d.toJson()],
    });
  }
  ```
  - **若 `ApiClient` 無 `put`**:於 `api_client.dart` 仿 `post` 加 `put`(帶 Origin header);加最小測試。先確認:`grep -n "Future.*put" lib/api/api_client.dart`。
- [ ] 綠 → commit `feat: trip_repository createTrip/updateTrip（+ ApiClient.put 視需要）`。

## Task 0.4：flutter_localizations（zh-TW 日期選擇）

**Files:** `pubspec.yaml`;`lib/app/app.dart`(MaterialApp.router)。

- [ ] `pubspec.yaml` dependencies 加：
  ```yaml
  flutter_localizations:
    sdk: flutter
  ```
  `flutter pub get`。
- [ ] `lib/app/app.dart` 的 `MaterialApp.router` 加：
  ```dart
  localizationsDelegates: GlobalMaterialLocalizations.delegates, // import flutter_localizations
  supportedLocales: const [Locale('zh', 'TW'), Locale('en'), Locale('ja')],
  ```
  (import `package:flutter_localizations/flutter_localizations.dart`)
- [ ] `flutter analyze` 0 + 既有測試全綠 → commit `chore: flutter_localizations（zh-TW 日期選擇）`。

---

# 階段 1：建立流程

## Task 1.1：CreateTripController

**Files:** 新 `lib/features/trips/create/create_trip_controller.dart`;test 新 `test/features/trips/create/create_trip_controller_test.dart`。

- [ ] state(`CreateTripState`,copyWith;不可變):
  - `List<DestinationInput> destinations`、`enum TripDateMode {fixed, flexible} dateMode`、`String? fixedStart/fixedEnd`、`int flexYear/flexMonth/flexDayCount`、`bool submitting`、`String? error`。
  - 衍生 getter:`String? startDate`/`String? endDate`(依 mode)、`int totalDays`、`bool canSubmit`(≥1 dest && dates valid && dest≤30 && !submitting)。
- [ ] 測試(override `tripRepositoryProvider` mock;`poiRepositoryProvider` 視需要):
  - add/remove/reorder destination 改 state。
  - dateMode=flexible + setFlex(2026,7,5) → startDate/endDate = `flexibleRange`。
  - 無 destination → canSubmit false;1 dest + 有效日期 → true。
  - `submit()` → 呼叫 `createTrip`(verify body 衍生 name/countries/id 非空)、回 tripId;submitting 過程 true→false。
  - createTrip 丟 409 → error 設值、submitting false。
- [ ] 實作要點:
  - `genTripId(deriveTripName(dests), DateTime.now().millisecondsSinceEpoch)`、`deriveCountries`。
  - `submit`:guard canSubmit;`submitting=true`;try createTrip(...) → 回 tripId;catch ApiError/Exception → error。
  - quota:`setQuota(index, n)` 更新 `destinations[i].copyWith(dayQuota:n)`。
- [ ] provider:`NotifierProvider<CreateTripController, CreateTripState>`。
- [ ] 綠 → commit `feat: CreateTripController（目的地/日期模式/衍生/submit）`。

## Task 1.2：CreateTripScreen + 路由 + 入口

**Files:** 新 `lib/features/trips/create/create_trip_screen.dart`;`lib/app/router.dart`(+`/new-trip`);`lib/features/trips/trips_list_screen.dart`(+FAB);test 新 `test/features/trips/create/create_trip_screen_test.dart`。

- [ ] 測試(override `tripRepositoryProvider`+`poiRepositoryProvider` mock,假 GoRouter 探針):
  - 目的地空 → 送出鈕 disabled。
  - POI 搜尋(`chat`/`create-poi-search` key 輸入 → 結果 tap)加入目的地 → 顯示。
  - 加目的地 + 固定日期(設 state 或點 picker;測試可直接驅動 controller 設日期)→ 送出 → verify `createTrip` 被呼叫、導去 `/trips/<id>`。
  - 切到彈性模式 → 顯示天數 stepper。
- [ ] 實作:
  - `ConsumerWidget`;watch `createTripControllerProvider`。AppBar「建立行程」。
  - body `ListView`:`_DestinationPicker`(POI 搜尋 TextField key `create-poi-search` + 結果清單 + 熱門 chips + `ReorderableListView` 目的地 + 移除)、`_DateModeSection`(`SegmentedButton<TripDateMode>`;fixed→兩個 date field 點開 `showDatePicker`;flexible→天數 stepper + 月份 chips)、`_DayQuotaSection`(destinations.length≥2 時 per-dest stepper)、description `TextField`。
  - 底部送出鈕(key `create-submit`)`onPressed: state.canSubmit ? () => _submit(...) : null`。
  - `_submit`:`final id = await controller.submit(); if (id != null) { ref.invalidate(myTripsProvider); context.go('/trips/$id'); }`。
  - 路由:`router.dart` 頂層加 `GoRoute(path: '/new-trip', builder: (_, __) => const CreateTripScreen())`(與 `/login`、shell 同層)。
  - 入口:`TripsListScreen` Scaffold 加 `floatingActionButton: FloatingActionButton(onPressed: () => context.push('/new-trip'), child: Icon(Icons.add))`。
- [ ] 綠 → commit `feat: CreateTripScreen（目的地優先 + 日期模式 + 每地天數）+ /new-trip + FAB`。

---

# 階段 2：編輯流程

## Task 2.1：EditTripController

**Files:** 新 `lib/features/trips/edit/edit_trip_controller.dart`;test 新 `test/features/trips/edit/edit_trip_controller_test.dart`。

- [ ] state(`EditTripState`):`loading`、`title`、`description`、`lang`、`published`、`List<DestinationInput> destinations`、`saving`、`error`、`saved`;記 `_original`(算 diff)。
- [ ] 測試(override `tripRepositoryProvider` mock 回一個 Trip;constructor 注入 tripId):
  - build 帶入初值(title/description/lang/published/destinations 來自 `tripDetailProvider`)。
  - 改 title → diff 含 title;未改不送。
  - destinations 改 → save 送 destinations + 重算 countries。
  - `save()` → updateTrip diff-only;成功 saved=true、invalidate。
  - 無變更 → save no-op(或 saved=true 直接返回)。
- [ ] 實作要點:
  - `NotifierProvider.autoDispose.family<EditTripController, EditTripState, String>(EditTripController.new)`;`EditTripController(this.tripId)`。
  - `build`:`ref.watch(tripDetailProvider(tripId))` → 有 data 時帶入(loading 態對應 AsyncLoading)。用 `Trip` 的 title/description/lang/published/destinations(注意 `Trip` 有 `destinations: List<TripDestination>` → 轉 `DestinationInput`)。
  - `save`:組 diff map(只放與 `_original` 不同者);destinations 改則 `updateTrip(..., destinations: x, countries: deriveCountries(x))`;成功 `ref.invalidate(myTripsProvider); ref.invalidate(tripDetailProvider(tripId)); saved=true`。
- [ ] 綠 → commit `feat: EditTripController（帶入/diff/save）`。

## Task 2.2：EditTripScreen + 路由 + 入口

**Files:** 新 `lib/features/trips/edit/edit_trip_screen.dart`;`lib/app/router.dart`(+`/edit-trip/:tripId`);`lib/features/trip_detail/trip_timeline_screen.dart`(AppBar 編輯 action);test 新 `test/features/trips/edit/edit_trip_screen_test.dart`。

- [ ] 測試:
  - 載入態 → 帶入欄位(title 顯示原值)。
  - 改 title + 點儲存 → verify `updateTrip(id, title:'新')`、返回(pop 探針)。
  - 目的地移除 → 儲存送 destinations + countries。
- [ ] 實作:
  - `ConsumerWidget` watch `editTripControllerProvider(tripId)`。AppBar「編輯行程」+ 儲存 action(或底部儲存鈕,key `edit-save`)。
  - 載入:state.loading → spinner。
  - 表單:目的地(同 create 的可加/排序/移除,抽共用 `_DestinationList` 若划算)、title `TextField`、description `TextField`、lang `DropdownButtonFormField`(zh-TW/en/ja)、published `SwitchListTile`。
  - 儲存:`await controller.save(); if (saved && context.mounted) context.pop();`。
  - 路由:頂層 `GoRoute(path: '/edit-trip/:tripId', builder: (_, s) => EditTripScreen(tripId: s.pathParameters['tripId']!))`。
  - 入口:`TripTimelineScreen` AppBar `actions: [IconButton(icon: Icon(Icons.edit_outlined), onPressed: () => context.push('/edit-trip/$tripId'))]`。
- [ ] 綠 → commit `feat: EditTripScreen（目的地/title/描述/語言/發布 + 儲存）+ /edit-trip/:id + 入口`。

---

# 收尾
- [ ] 全 `flutter analyze` 0 + `flutter test` 全綠。
- [ ] `dart format` 新檔。
- [ ] CHANGELOG `[Unreleased]` + TODOS(建立/編輯行程 → Completed)。
- [ ] finishing：push + PR(base master)。

## 自我審查（plan vs spec）
- 契約(POST/PUT diff/無 OCC/不動日期)→ 0.3;衍生(id/name/countries/日期)→ 0.2;目的地優先 + 日期模式 + 每地天數 → 1.x;編輯帶入/diff/儲存鈕 → 2.x。
- 路由 top-level `/new-trip`、`/edit-trip/:tripId` 避開 shell 衝突;入口 FAB + timeline AppBar。
- 無 placeholder;純函式先行(測試友善);ValueKey 一致。
- 風險:`ApiClient.put` 可能不存在 → 0.3 先確認、必要時補。`showDatePicker` 需 localizations → 0.4。
