# 加入行程(AddToTrip)Implementation Plan — PR-B

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把收藏 / 探索的 POI 加入某行程某天:favorite mode(`POST /poi-favorites/:id/add-to-trip`)+ direct mode(探索 POI `POST /trips/:id/days/:num/entries`),選 trip/day/時間 + 409 衝突對話框。

**Architecture:** `AddToTripScreen`(fullpage)以 sealed `AddToTripArgs` 區分兩 mode;`ApiError` 加 `payload` 欄位以取 409 `conflictWith`;repository 方法 favorite→`FavoritesRepository.addFavoriteToTrip`、direct→`TripRepository.addEntryToDay`。入口:收藏 card +探索 POI card 的「加入行程」按鈕。

**Tech Stack:** Flutter 3.43、flutter_riverpod 3.x、go_router 17.x、dio + http_mock_adapter、mocktail。

**對應 spec:** `docs/superpowers/specs/2026-06-11-explore-and-add-to-trip-design.md`(C 段 + 後端契約附錄)。

---

## Commit 慣例
- 前綴 `feat:`/`test:`/`docs:`;每 commit message 結尾空一行加 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`。
- riverpod 3.x:overrides list literal inline;error 測試 `ProviderScope(retry: (_, _) => null)`。
- 起點:branch `feat/add-to-trip`(從 master,已含探索+收藏清單)。`flutter test` 起點應全綠。

## 後端契約(自 spec 附錄,雙向驗證)
- **favorite mode** `POST /api/poi-favorites/:id/add-to-trip`(`:id`=favorite id):body **camelCase** `{tripId(String), dayNum(int 1-based), startTime "HH:MM", endTime "HH:MM"}`(後端強制必填)→ 201 `{ok, entryId, dayId, sortOrder, startTime, endTime, note}`;**409** `{error:'CONFLICT', conflictWith:{entryId, time?, title, dayNum}}`;403/404/400。
- **direct mode** `POST /api/trips/:id/days/:num/entries`:body **snake_case** `{title(必), poi_type?, lat?, lng?, start_time?, end_time?, source?}` → 201 entry。

## File Structure
| 檔案 | 責任 | 動作 |
|---|---|---|
| `lib/api/api_error.dart` | + `payload`(原始 body) | 修改(Task 1) |
| `lib/models/add_to_trip.dart` | `AddToTripResult`/`TripEntryConflict`/`AddToTripArgs` | 建立(Task 2) |
| `lib/api/favorites_repository.dart` | + `addFavoriteToTrip` | 修改(Task 3) |
| `lib/api/trip_repository.dart` | + `addEntryToDay`(direct) | 修改(Task 3) |
| `lib/features/favorites/add_to_trip/add_to_trip_screen.dart` | 選 trip/day/時間 + 送出 + 409 dialog | 建立(Task 4) |
| `lib/features/favorites/poi_favorite_card.dart` | + 加入行程按鈕 | 修改(Task 5) |
| `lib/features/favorites/explore/poi_search_card.dart` | + 加入行程按鈕 | 修改(Task 5) |
| `lib/features/favorites/favorites_screen.dart` / `explore/explore_screen.dart` / `lib/app/router.dart` | 入口接線 + route | 修改(Task 5) |
| `docs/*` `TODOS.md` `CHANGELOG.md` | 文件 | 修改(Task 6) |

---

## Task 1: ApiError 加 payload

**Files:** Modify `lib/api/api_error.dart`;Modify `test/api/api_error_test.dart`

- [ ] **Step 1: 追加測試**(`test/api/api_error_test.dart` 末,`main` `}` 前)

```dart
  group('payload（保留原始 body 供 409 conflictWith）', () {
    test('Map body → payload 保留整個原始 body', () {
      final error = ApiError.fromResponse(409, {
        'error': 'CONFLICT',
        'conflictWith': {'entryId': 5, 'time': '10:00-11:00', 'title': '午餐', 'dayNum': 1},
      });
      expect(error.status, 409);
      expect(error.code, 'CONFLICT');
      expect(error.payload?['conflictWith'], isA<Map>());
      expect((error.payload!['conflictWith'] as Map)['entryId'], 5);
    });

    test('非 Map body → payload null', () {
      final error = ApiError.fromResponse(500, 'oops');
      expect(error.payload, isNull);
    });
  });
```

- [ ] **Step 2: run fail** — `flutter test test/api/api_error_test.dart` — Expected: FAIL（`payload` getter 不存在）

- [ ] **Step 3: 改 `lib/api/api_error.dart`**

建構子加 `this.payload,`(在 `this.detail,` 之後);加欄位 `final Map<String, dynamic>? payload;`(在 `final String? detail;` 之後)。`fromResponse` 開頭算出 payload 並三條 return 都帶上:
```dart
  factory ApiError.fromResponse(int status, dynamic body) {
    final payload = body is Map ? Map<String, dynamic>.from(body) : null;
    if (body is Map) {
      final errorField = body['error'];
      if (errorField is Map) {
        return ApiError(
          status: status,
          code: errorField['code']?.toString() ?? 'HTTP_$status',
          message: errorField['message']?.toString() ?? 'HTTP $status',
          detail: _truncateDetail(errorField['detail']?.toString()),
          payload: payload,
        );
      }
      if (errorField is String && errorField.isNotEmpty) {
        return ApiError(
          status: status,
          code: errorField,
          message: body['error_description']?.toString() ?? errorField,
          payload: payload,
        );
      }
    }
    return ApiError(
      status: status,
      code: 'HTTP_$status',
      message: 'HTTP $status',
      payload: payload,
    );
  }
```

- [ ] **Step 4: run pass** — `flutter test test/api/api_error_test.dart` — Expected: PASS（既有 + 新 payload）

- [ ] **Step 5: Commit**
```bash
git add lib/api/api_error.dart test/api/api_error_test.dart
git commit -m "feat: ApiError 加 payload（保留原始 body 供 409 conflictWith）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: models（AddToTripResult / TripEntryConflict / AddToTripArgs）

**Files:** Create `test/models/add_to_trip_test.dart`;Create `lib/models/add_to_trip.dart`

- [ ] **Step 1: 寫測試**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/add_to_trip.dart';
import 'package:tripline/models/poi_search_result.dart';

void main() {
  group('AddToTripResult.fromJson', () {
    test('camelCase 201 body', () {
      final r = AddToTripResult.fromJson({
        'ok': true, 'entryId': 11, 'dayId': 2, 'sortOrder': 0,
        'startTime': '10:00', 'endTime': '11:00', 'note': '...',
      });
      expect(r.ok, isTrue);
      expect(r.entryId, 11);
      expect(r.dayId, 2);
      expect(r.startTime, '10:00');
    });
  });

  group('TripEntryConflict.fromJson', () {
    test('解析 conflictWith', () {
      final c = TripEntryConflict.fromJson({
        'entryId': 5, 'time': '10:00-11:00', 'title': '午餐', 'dayNum': 1,
      });
      expect(c.entryId, 5);
      expect(c.time, '10:00-11:00');
      expect(c.title, '午餐');
      expect(c.dayNum, 1);
    });
    test('time 可為 null', () {
      final c = TripEntryConflict.fromJson(
          {'entryId': 6, 'title': '景點', 'dayNum': 2});
      expect(c.time, isNull);
    });
  });

  group('AddToTripArgs', () {
    test('favorite / direct 兩型', () {
      final fav = AddToTripFavorite(favoriteId: 7, displayName: '首里城');
      final direct = AddToTripDirect(
          poi: const PoiSearchResult(placeId: 'p1', name: '拉麵'));
      expect(fav.favoriteId, 7);
      expect(direct.poi.name, '拉麵');
      expect(fav, isA<AddToTripArgs>());
      expect(direct, isA<AddToTripArgs>());
    });
  });
}
```

- [ ] **Step 2: run fail** — `flutter test test/models/add_to_trip_test.dart` — FAIL

- [ ] **Step 3: 建 `lib/models/add_to_trip.dart`**
```dart
/// 加入行程 models 與導航參數。
library;

import 'poi_search_result.dart';

/// `POST /poi-favorites/:id/add-to-trip` 成功 201 回應（camelCase）。
class AddToTripResult {
  const AddToTripResult({
    required this.ok,
    required this.entryId,
    required this.dayId,
    required this.sortOrder,
    required this.startTime,
    required this.endTime,
  });

  final bool ok;
  final int entryId;
  final int dayId;
  final int sortOrder;
  final String startTime;
  final String endTime;

  factory AddToTripResult.fromJson(Map<String, dynamic> json) {
    return AddToTripResult(
      ok: json['ok'] == true,
      entryId: (json['entryId'] as num).toInt(),
      dayId: (json['dayId'] as num).toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
    );
  }
}

/// 409 `conflictWith`：時段與既有 entry 重疊。
class TripEntryConflict {
  const TripEntryConflict({
    required this.entryId,
    this.time,
    required this.title,
    required this.dayNum,
  });

  final int entryId;
  final String? time; // "HH:MM-HH:MM" 或單一 或 null
  final String title;
  final int dayNum;

  factory TripEntryConflict.fromJson(Map<String, dynamic> json) {
    return TripEntryConflict(
      entryId: (json['entryId'] as num).toInt(),
      time: json['time'] as String?,
      title: json['title'] as String? ?? '',
      dayNum: (json['dayNum'] as num?)?.toInt() ?? 0,
    );
  }
}

/// AddToTripScreen 的導航參數（go_router extra）。
sealed class AddToTripArgs {
  const AddToTripArgs();
}

/// 從收藏進：已有 favorite id。
class AddToTripFavorite extends AddToTripArgs {
  const AddToTripFavorite({required this.favoriteId, required this.displayName});
  final int favoriteId;
  final String displayName;
}

/// 從探索 POI 進：直接建 entry（不經收藏）。
class AddToTripDirect extends AddToTripArgs {
  const AddToTripDirect({required this.poi});
  final PoiSearchResult poi;
}
```

- [ ] **Step 4: run pass** — `flutter test test/models/add_to_trip_test.dart` — PASS

- [ ] **Step 5: Commit**
```bash
git add lib/models/add_to_trip.dart test/models/add_to_trip_test.dart
git commit -m "feat: 加入行程 models（AddToTripResult/TripEntryConflict/AddToTripArgs）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: repository（addFavoriteToTrip + addEntryToDay）

**Files:** Modify `lib/api/favorites_repository.dart` + `test/api/favorites_repository_test.dart`;Modify `lib/api/trip_repository.dart` + `test/api/trip_repository_test.dart`

- [ ] **Step 1: 追加測試**

`test/api/favorites_repository_test.dart`（末,main `}` 前）:
```dart
  test('addFavoriteToTrip：POST /poi-favorites/:id/add-to-trip camelCase → 201 result',
      () async {
    dioAdapter.onPost(
      '/poi-favorites/7/add-to-trip',
      (server) => server.reply(201, {
        'ok': true, 'entryId': 11, 'dayId': 2, 'sortOrder': 0,
        'startTime': '10:00', 'endTime': '11:00', 'note': '...',
      }),
      data: {'tripId': 'okinawa', 'dayNum': 1, 'startTime': '10:00', 'endTime': '11:00'},
    );

    final result = await favoritesRepository.addFavoriteToTrip(
      favoriteId: 7, tripId: 'okinawa', dayNum: 1,
      startTime: '10:00', endTime: '11:00',
    );

    expect(result.entryId, 11);
    expect(result.ok, isTrue);
  });

  test('addFavoriteToTrip：409 → 拋 ApiError 帶 conflictWith payload', () async {
    dioAdapter.onPost(
      '/poi-favorites/7/add-to-trip',
      (server) => server.reply(409, {
        'error': 'CONFLICT',
        'conflictWith': {'entryId': 5, 'time': '10:00-11:00', 'title': '午餐', 'dayNum': 1},
      }),
      data: {'tripId': 'okinawa', 'dayNum': 1, 'startTime': '10:00', 'endTime': '11:00'},
    );

    await expectLater(
      favoritesRepository.addFavoriteToTrip(
        favoriteId: 7, tripId: 'okinawa', dayNum: 1,
        startTime: '10:00', endTime: '11:00'),
      throwsA(isA<ApiError>()
          .having((e) => e.status, 'status', 409)
          .having((e) => e.payload?['conflictWith'], 'conflictWith', isA<Map>())),
    );
  });
```
（檔頂若無 `import 'package:tripline/api/api_error.dart';` 請加。）

`test/api/trip_repository_test.dart`（末,main `}` 前）:
```dart
  test('addEntryToDay：POST /trips/:id/days/:num/entries snake_case body', () async {
    dioAdapter.onPost(
      '/trips/okinawa/days/1/entries',
      (server) => server.reply(201, {'id': 99}),
      data: {
        'title': '美麗海水族館', 'poi_type': 'attraction',
        'lat': 26.69, 'lng': 127.87,
        'start_time': '10:00', 'end_time': '11:00', 'source': 'user-explore',
      },
    );

    await expectLater(
      tripRepository.addEntryToDay(
        tripId: 'okinawa', dayNum: 1, title: '美麗海水族館',
        poiType: 'attraction', lat: 26.69, lng: 127.87,
        startTime: '10:00', endTime: '11:00'),
      completes,
    );
  });
```

- [ ] **Step 2: run fail** — `flutter test test/api/favorites_repository_test.dart test/api/trip_repository_test.dart` — FAIL

- [ ] **Step 3: 實作**

`lib/api/favorites_repository.dart` 加（檔頂 import `'../models/add_to_trip.dart';`;`addFavorite` 之後）:
```dart
  /// POST /poi-favorites/:id/add-to-trip（body camelCase,startTime/endTime 必填 HH:MM）。
  /// 409 時 ApiClient 會丟 ApiError（status 409,payload 含 conflictWith）。
  Future<AddToTripResult> addFavoriteToTrip({
    required int favoriteId,
    required String tripId,
    required int dayNum,
    required String startTime,
    required String endTime,
  }) async {
    final body = await _client.post('/poi-favorites/$favoriteId/add-to-trip', body: {
      'tripId': tripId,
      'dayNum': dayNum,
      'startTime': startTime,
      'endTime': endTime,
    });
    return AddToTripResult.fromJson(body as Map<String, dynamic>);
  }
```

`lib/api/trip_repository.dart` 加（`deleteTrip` 之後）:
```dart
  /// POST /trips/:id/days/:num/entries（direct add,body snake_case;後端自動 find-or-create POI）。
  Future<void> addEntryToDay({
    required String tripId,
    required int dayNum,
    required String title,
    String? poiType,
    double? lat,
    double? lng,
    String? startTime,
    String? endTime,
    String source = 'user-explore',
  }) {
    return _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/days/$dayNum/entries',
      body: {
        'title': title,
        'poi_type': poiType,
        'lat': lat,
        'lng': lng,
        'start_time': startTime,
        'end_time': endTime,
        'source': source,
      },
    );
  }
```

- [ ] **Step 4: run pass** — `flutter test test/api/favorites_repository_test.dart test/api/trip_repository_test.dart` — PASS

- [ ] **Step 5: Commit**
```bash
git add lib/api/favorites_repository.dart lib/api/trip_repository.dart test/api/favorites_repository_test.dart test/api/trip_repository_test.dart
git commit -m "feat: addFavoriteToTrip（favorite mode）+ addEntryToDay（direct mode）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `AddToTripScreen`（選 trip/day/時間 + 送出 + 409 dialog）

**Files:** Create `test/features/favorites/add_to_trip/add_to_trip_screen_test.dart`;Create `lib/features/favorites/add_to_trip/add_to_trip_screen.dart`

說明:`ConsumerStatefulWidget`,建構子收 `AddToTripArgs args`。選 trip(`myTripsProvider` → `TripSummary` dropdown)、選 day(選定 trip 的 `tripDaysProvider(tripId)` → `TripDay` dropdown)、startTime/endTime(`showTimePicker` → `HH:MM`)。送出依 mode:favorite→`addFavoriteToTrip`、direct→`addEntryToDay`(poi 的 title/poiType(`mapGooglePrimaryTypeToPoiType(category)`)/lat/lng)。409 → `ConflictDialog`。成功 → SnackBar + pop。

- [ ] **Step 1: 寫測試**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/add_to_trip/add_to_trip_screen.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/models/add_to_trip.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

class _MockTripRepository extends Mock implements TripRepository {}

const _trips = [TripSummary(tripId: 'okinawa', name: 'okinawa', title: '沖繩')];
const _days = [TripDay(id: 1, dayNum: 1, title: '第一天', version: 0)];

void main() {
  late _MockFavoritesRepository favRepo;
  late _MockTripRepository tripRepo;

  setUp(() {
    favRepo = _MockFavoritesRepository();
    tripRepo = _MockTripRepository();
    when(tripRepo.fetchMyTrips).thenAnswer((_) async => _trips);
    when(() => tripRepo.fetchDays('okinawa')).thenAnswer((_) async => _days);
  });

  // 統一 override tripRepositoryProvider（myTripsProvider/tripDaysProvider 皆走它,
  // 避免 family instance override 語法不確定）。
  Widget buildApp(AddToTripArgs args) {
    return ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        favoritesRepositoryProvider.overrideWithValue(favRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: AddToTripScreen(args: args),
      ),
    );
  }

  testWidgets('favorite mode：選 trip/day(預設)→ 送出呼叫 addFavoriteToTrip',
      (tester) async {
    when(() => favRepo.addFavoriteToTrip(
          favoriteId: any(named: 'favoriteId'),
          tripId: any(named: 'tripId'),
          dayNum: any(named: 'dayNum'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        )).thenAnswer((_) async => const AddToTripResult(
        ok: true, entryId: 11, dayId: 1, sortOrder: 0,
        startTime: '10:00', endTime: '11:00'));

    await tester.pumpWidget(
        buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();

    verify(() => favRepo.addFavoriteToTrip(
        favoriteId: 7,
        tripId: 'okinawa',
        dayNum: 1,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'))).called(1);
  });

  testWidgets('direct mode：送出呼叫 addEntryToDay(poiType 經映射)', (tester) async {
    when(() => tripRepo.addEntryToDay(
          tripId: any(named: 'tripId'),
          dayNum: any(named: 'dayNum'),
          title: any(named: 'title'),
          poiType: any(named: 'poiType'),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp(const AddToTripDirect(
        poi: PoiSearchResult(
            placeId: 'p1', name: '美麗海水族館',
            category: 'aquarium', lat: 26.69, lng: 127.87))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();

    verify(() => tripRepo.addEntryToDay(
        tripId: 'okinawa',
        dayNum: 1,
        title: '美麗海水族館',
        poiType: 'activity', // aquarium → activity（mapGooglePrimaryTypeToPoiType）
        lat: 26.69,
        lng: 127.87,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'))).called(1);
  });

  testWidgets('favorite mode：409 → 顯示 ConflictDialog', (tester) async {
    when(() => favRepo.addFavoriteToTrip(
          favoriteId: any(named: 'favoriteId'),
          tripId: any(named: 'tripId'),
          dayNum: any(named: 'dayNum'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        )).thenThrow(const ApiError(
      status: 409, code: 'CONFLICT', message: 'CONFLICT',
      payload: {
        'conflictWith': {'entryId': 5, 'time': '10:00-11:00', 'title': '午餐', 'dayNum': 1}
      },
    ));

    await tester.pumpWidget(
        buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('午餐'), findsOneWidget); // conflict entry 標題
  });
}
```

- [ ] **Step 2: run fail** — `flutter test test/features/favorites/add_to_trip/add_to_trip_screen_test.dart` — FAIL

- [ ] **Step 3: 建 `lib/features/favorites/add_to_trip/add_to_trip_screen.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../models/add_to_trip.dart';
import '../../../models/day.dart';
import '../../../models/poi_type.dart';
import '../../../models/trip.dart';
import '../../../theme/tokens.dart';
import '../../trip_detail/trip_providers.dart';
import '../../trips/trips_list_screen.dart';
import '../favorites_providers.dart';

/// 加入行程（fullpage）：選 trip/day/時間 → 送出（favorite / direct mode）。
class AddToTripScreen extends ConsumerStatefulWidget {
  const AddToTripScreen({super.key, required this.args});

  final AddToTripArgs args;

  @override
  ConsumerState<AddToTripScreen> createState() => _AddToTripScreenState();
}

class _AddToTripScreenState extends ConsumerState<AddToTripScreen> {
  String? _tripId;
  int? _dayNum;
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 11, minute: 0);
  bool _submitting = false;

  String get _title => switch (widget.args) {
        AddToTripFavorite(:final displayName) => displayName,
        AddToTripDirect(:final poi) => poi.name,
      };

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked =
        await showTimePicker(context: context, initialTime: isStart ? _start : _end);
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  Future<void> _submit() async {
    final tripId = _tripId;
    final dayNum = _dayNum;
    if (tripId == null || dayNum == null) return;
    setState(() => _submitting = true);
    try {
      switch (widget.args) {
        case AddToTripFavorite(:final favoriteId):
          await ref.read(favoritesRepositoryProvider).addFavoriteToTrip(
                favoriteId: favoriteId,
                tripId: tripId,
                dayNum: dayNum,
                startTime: _fmt(_start),
                endTime: _fmt(_end),
              );
        case AddToTripDirect(:final poi):
          await ref.read(tripRepositoryProvider).addEntryToDay(
                tripId: tripId,
                dayNum: dayNum,
                title: poi.name,
                poiType: mapGooglePrimaryTypeToPoiType(poi.category),
                lat: poi.lat,
                lng: poi.lng,
                startTime: _fmt(_start),
                endTime: _fmt(_end),
              );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已加入行程')));
      Navigator.of(context).pop();
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (error.status == 409) {
        final raw = error.payload?['conflictWith'];
        if (raw is Map) {
          await _showConflict(
              TripEntryConflict.fromJson(Map<String, dynamic>.from(raw)));
          return;
        }
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('加入行程失敗,請稍後再試')));
    } on Exception {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('加入行程失敗,請稍後再試')));
    }
  }

  Future<void> _showConflict(TripEntryConflict conflict) {
    final timeLabel = conflict.time == null ? '' : '（${conflict.time}）';
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('時段衝突'),
        content: Text(
            '該時段已有「${conflict.title}」$timeLabel。請改選其他時間後再試。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(myTripsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('加入行程：$_title')),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(TpSpacing.s6),
            child: Text('無法載入行程清單:$e', textAlign: TextAlign.center),
          ),
        ),
        data: (trips) => _form(context, trips),
      ),
    );
  }

  Widget _form(BuildContext context, List<TripSummary> trips) {
    // 預設選第一個 trip
    final tripId = _tripId ??= trips.isEmpty ? null : trips.first.tripId;
    final daysAsync =
        tripId == null ? null : ref.watch(tripDaysProvider(tripId));

    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('add-to-trip-trip'),
          initialValue: tripId,
          decoration: const InputDecoration(labelText: '行程'),
          items: [
            for (final t in trips)
              DropdownMenuItem(value: t.tripId, child: Text(t.displayTitle)),
          ],
          onChanged: (v) => setState(() {
            _tripId = v;
            _dayNum = null; // 換 trip 重置 day
          }),
        ),
        const SizedBox(height: TpSpacing.s4),
        if (daysAsync != null)
          daysAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('無法載入日程:$e'),
            data: (days) {
              final dayNum = _dayNum ??=
                  days.isEmpty ? null : days.first.dayNum;
              return DropdownButtonFormField<int>(
                key: const ValueKey('add-to-trip-day'),
                initialValue: dayNum,
                decoration: const InputDecoration(labelText: '日期'),
                items: [
                  for (final d in days)
                    DropdownMenuItem(
                        value: d.dayNum,
                        child: Text('DAY ${d.dayNum} · ${d.displayTitle}')),
                ],
                onChanged: (v) => setState(() => _dayNum = v),
              );
            },
          ),
        const SizedBox(height: TpSpacing.s4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('add-to-trip-start'),
                onPressed: () => _pickTime(true),
                child: Text('開始 ${_fmt(_start)}'),
              ),
            ),
            const SizedBox(width: TpSpacing.s3),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('add-to-trip-end'),
                onPressed: () => _pickTime(false),
                child: Text('結束 ${_fmt(_end)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: TpSpacing.s6),
        FilledButton(
          key: const ValueKey('add-to-trip-submit'),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '加入中…' : '加入行程'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: run pass** — `flutter test test/features/favorites/add_to_trip/add_to_trip_screen_test.dart` — PASS。除錯提示:`tripDaysProvider('okinawa').overrideWith` 需 family override 正確 tripId;dropdown 預設選第一個靠 `??=`;若 day dropdown 沒出現,確認 `_tripId` 在 build 時已設(form 內 `??=`)。

- [ ] **Step 5: commit 前 `flutter analyze`（0 issues）**,然後 Commit
```bash
git add lib/features/favorites/add_to_trip/add_to_trip_screen.dart test/features/favorites/add_to_trip/add_to_trip_screen_test.dart
git commit -m "feat: AddToTripScreen（選 trip/day/時間 + favorite/direct 送出 + 409 ConflictDialog）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 入口 + router

**Files:** Modify `lib/features/favorites/poi_favorite_card.dart`、`lib/features/favorites/explore/poi_search_card.dart`、`lib/features/favorites/favorites_screen.dart`、`lib/features/favorites/explore/explore_screen.dart`、`lib/app/router.dart`

說明:① 兩個 card 各加 `onAddToTrip` 回呼 + 一個「加入行程」`IconButton`(`Icons.add_location_alt_outlined`)。② FavoritesScreen / ExploreScreen 傳 `onAddToTrip` → `context.go('/favorites/add-to-trip', extra: <AddToTripArgs>)`。③ router 加 `/favorites/add-to-trip`(讀 `state.extra as AddToTripArgs`)。

- [ ] **Step 1: 改 `poi_favorite_card.dart`** — 建構子加 `this.onAddToTrip`(`final VoidCallback? onAddToTrip;`);在 heart `IconButton` 之前(同 Row 末)加:
```dart
          if (onAddToTrip != null)
            IconButton(
              key: ValueKey('favorite-add-to-trip-${favorite.id}'),
              tooltip: '加入行程',
              icon: const Icon(Icons.add_location_alt_outlined),
              onPressed: onAddToTrip,
            ),
```

- [ ] **Step 2: 改 `poi_search_card.dart`** — 建構子加 `this.onAddToTrip`(`final VoidCallback? onAddToTrip;`);在 heart `IconButton`(Stack 內 Positioned)旁加一個 Positioned「加入行程」按鈕:
```dart
              if (onAddToTrip != null)
                Positioned(
                  top: 0,
                  left: 0,
                  child: IconButton(
                    key: ValueKey('poi-add-to-trip-${poi.placeId}'),
                    tooltip: '加入行程',
                    icon: const Icon(Icons.add_location_alt_outlined),
                    onPressed: onAddToTrip,
                  ),
                ),
```

- [ ] **Step 3: 改 screen 接線**

`favorites_screen.dart`:`PoiFavoriteCard(...)` 加 `onAddToTrip: () => context.go('/favorites/add-to-trip', extra: AddToTripFavorite(favoriteId: favorite.id, displayName: favorite.displayName))`;檔頂 import `'../../models/add_to_trip.dart';`(go_router 已 import)。

`explore/explore_screen.dart`:`PoiSearchCard(...)` 加 `onAddToTrip: () => context.go('/favorites/add-to-trip', extra: AddToTripDirect(poi: poi))`;檔頂 import `'package:go_router/go_router.dart';` 與 `'../../../models/add_to_trip.dart';`。

`lib/app/router.dart`:import `add_to_trip_screen.dart` 與 `add_to_trip.dart`;在 favorites branch 的 `/favorites` 子 routes 加(與 `explore` 並列):
```dart
                  GoRoute(
                    path: 'add-to-trip',
                    builder: (context, state) =>
                        AddToTripScreen(args: state.extra! as AddToTripArgs),
                  ),
```

- [ ] **Step 4: 追加 card 測試**(各 card test 加一個「按加入行程 → onAddToTrip 觸發」)

`test/features/favorites/poi_favorite_card_test.dart` 加:
```dart
    testWidgets('有 onAddToTrip → 點加入行程鈕觸發', (tester) async {
      var added = 0;
      await pumpCard(tester, _favorite, onAddToTrip: () => added++);
      await tester.tap(find.byKey(const ValueKey('favorite-add-to-trip-7')));
      expect(added, 1);
    });
```
並把該檔的 `pumpCard` helper 加上 `VoidCallback? onAddToTrip` 參數傳入 `PoiFavoriteCard(... onAddToTrip: onAddToTrip)`。

`test/features/favorites/explore/poi_search_card_test.dart` 加類似(key `poi-add-to-trip-p1`),`pumpCard` 加 `onAddToTrip` 參數。

- [ ] **Step 5: run + analyze + Commit**

Run: `flutter test` + `flutter analyze`(0 issues)。Expected: 全綠。
```bash
git add lib/features/favorites/poi_favorite_card.dart lib/features/favorites/explore/poi_search_card.dart lib/features/favorites/favorites_screen.dart lib/features/favorites/explore/explore_screen.dart lib/app/router.dart test/features/favorites/poi_favorite_card_test.dart test/features/favorites/explore/poi_search_card_test.dart
git commit -m "feat: 收藏/探索 card 加入行程入口 + /favorites/add-to-trip route" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 文件 + 驗收

**Files:** Modify `docs/reference-navigation.md`、`docs/reference-api.md`、`TODOS.md`、`CHANGELOG.md`

- [ ] **Step 1: analyze** — `flutter analyze` → `No issues found!`
- [ ] **Step 2: 全套 test** — `flutter test` → 全綠,記下 passed 數。
- [ ] **Step 3: 更新文件**(先讀各檔當前內容再 Edit)
  - `reference-navigation.md`:加 `/favorites/add-to-trip`(`AddToTripScreen`,tab 4 子路由,extra `AddToTripArgs`)。
  - `reference-api.md`:`FavoritesRepository` 補 `addFavoriteToTrip`;`TripRepository` 補 `addEntryToDay`;註記 `ApiError` 新增 `payload`。
  - `TODOS.md`:P1「加入行程」項標 ✅ 完成(2026-06-11);若「收藏 + 探索」整組已完成,移到 Completed 區。
  - `CHANGELOG.md` `## [Unreleased] ### 新增`:加「加入行程:收藏/探索 POI → 選 trip/day/時間加入行程(favorite + direct mode);409 時段衝突對話框。」
- [ ] **Step 4: Commit**
```bash
git add docs/reference-navigation.md docs/reference-api.md TODOS.md CHANGELOG.md
git commit -m "docs: 加入行程文件更新 + 標記 P1 收藏+探索完成" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```
- [ ] **Step 5: 交付** — `git push -u origin feat/add-to-trip`;REST API 建 PR(gh graphql 401)。PR 描述含 test passed 數、analyze 結果、PR-B 範圍(完成 P1 收藏+探索)。

---

## 驗收條件
- [ ] `flutter analyze` 0 issues、`flutter test` 全綠。
- [ ] favorite mode(收藏 card → 選 trip/day/時間 → addFavoriteToTrip)+ direct mode(探索 POI card → addEntryToDay)皆動(mock 驗證)。
- [ ] 409 → ConflictDialog 顯示衝突 entry。
- [ ] ApiError payload 保留;reference / TODOS / CHANGELOG 更新。
