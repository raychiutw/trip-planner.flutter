# 時間軸 Entry CRUD（C+D+E 合併）實作計畫

> 用 executing-plans 逐 task TDD。分支 `feat/timeline-entry-crud-cde`（疊在 A+B）。
> spec：`docs/superpowers/specs/2026-06-11-timeline-entry-crud-cde-design.md`。

**Goal:** C 拖曳排序/跨天搬移、D 地點管理全頁、E 交通編輯，合併單一 PR、分 4 階段。

**Tech:** flutter_riverpod 3.x / go_router / dio mock + mocktail。

---

# 階段 0：model + repository

## Task 0.1：model 欄位 + TripSegment

**Files:** `lib/models/entry.dart`、新 `lib/models/segment.dart`；test `test/models/entry_test.dart`(擴)、新 `test/models/segment_test.dart`。

- [ ] 測試（segment_test）：TripSegment.fromJson 解析 id/fromEntryId/toEntryId/mode/min/distanceM/source/version；entry_test 擴：`entryPoisVersion`（int 或 string wire 都轉 string）、`EntryPoiInfo.reservation/reservationUrl/description`。
- [ ] 跑測試 → 失敗。
- [ ] 實作：
  - `TimelineEntry` 加 `final String? entryPoisVersion;`（建構子選填）、fromJson `entryPoisVersion: json['entryPoisVersion']?.toString()`。
  - `EntryPoiInfo` 加 `final String? reservation; final String? reservationUrl; final String? description;`，fromJson 對應 `as String?`。
  - 新 `lib/models/segment.dart`：
    ```dart
    class TripSegment {
      const TripSegment({
        required this.id, this.fromEntryId, this.toEntryId,
        required this.mode, this.min, this.distanceM, this.source,
        required this.version,
      });
      final int id;
      final int? fromEntryId;
      final int? toEntryId;
      final String mode;
      final int? min;
      final int? distanceM;
      final String? source;
      final int version;
      factory TripSegment.fromJson(Map<String, dynamic> json) => TripSegment(
        id: (json['id'] as num).toInt(),
        fromEntryId: (json['fromEntryId'] as num?)?.toInt(),
        toEntryId: (json['toEntryId'] as num?)?.toInt(),
        mode: json['mode'] as String? ?? 'driving',
        min: (json['min'] as num?)?.toInt(),
        distanceM: (json['distanceM'] as num?)?.toInt(),
        source: json['source'] as String?,
        version: (json['version'] as num?)?.toInt() ?? 0,
      );
    }
    ```
- [ ] 跑測試 → 綠。commit `feat: entry model entryPoisVersion/reservation + TripSegment model`。

## Task 0.2：repository — C/E 方法（batch / recompute / segments）

**Files:** `lib/api/trip_repository.dart`；test `test/api/trip_repository_test.dart`(擴)。

- [ ] 測試：
  - `reorderEntries`：PATCH `/trips/okinawa/entries/batch`，data `{'updates':[{'id':11,'sort_order':0},{'id':12,'sort_order':1,'day_id':2}]}` → 200 `{ok:true,updated:2}` completes。
  - `recomputeTravel`：POST `/trips/okinawa/recompute-travel`，query `{'day':'all'}` → 200 completes。
  - `fetchSegments`：GET `/trips/okinawa/segments` → list，解析 single.version。
  - `updateSegment`：PATCH `/trips/okinawa/segments/5`，data `{'mode':'transit','min':20,'expectedVersion':1}` → 200 segment row，回 TripSegment。
  - `updateSegment` 409 → throwsA ApiError(409)。
- [ ] 跑 → 失敗。
- [ ] 實作（import `../models/segment.dart`）：
    ```dart
    Future<void> reorderEntries({
      required String tripId,
      required List<({int id, int sortOrder, int? dayId})> updates,
    }) {
      return _client.patch(
        '/trips/${Uri.encodeComponent(tripId)}/entries/batch',
        body: {
          'updates': [
            for (final u in updates)
              {
                'id': u.id,
                'sort_order': u.sortOrder,
                if (u.dayId != null) 'day_id': u.dayId,
              },
          ],
        },
      );
    }

    Future<void> recomputeTravel({required String tripId, String day = 'all'}) {
      return _client.post(
        '/trips/${Uri.encodeComponent(tripId)}/recompute-travel',
        query: {'day': day},
      );
    }

    Future<List<TripSegment>> fetchSegments({required String tripId}) async {
      final body =
          await _client.get('/trips/${Uri.encodeComponent(tripId)}/segments');
      return (body as List<dynamic>)
          .map((e) => TripSegment.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    Future<TripSegment> updateSegment({
      required String tripId,
      required int segmentId,
      required String mode,
      int? min,
      int? expectedVersion,
    }) async {
      final body = await _client.patch(
        '/trips/${Uri.encodeComponent(tripId)}/segments/$segmentId',
        body: {
          'mode': mode,
          if (min != null) 'min': min,
          if (expectedVersion != null) 'expectedVersion': expectedVersion,
        },
      );
      return TripSegment.fromJson(body as Map<String, dynamic>);
    }
    ```
  > 確認 `ApiClient.post` 支援 `query:`（既有 fetchDays 用 `_client.get(..., query:)`；post 若無 query 參數則改用 path `?day=all`）。
- [ ] 跑 → 綠。commit `feat: TripRepository reorderEntries/recomputeTravel/fetchSegments/updateSegment`。

## Task 0.3：repository — D 方法（POI 管理）

**Files:** `lib/api/trip_repository.dart`；test 同檔擴。`PoiSearchResult` 來自 `../models/poi_search_result.dart`。

- [ ] 測試（重點 case）：
  - `fetchEntry`：GET `/trips/okinawa/entries/11` → entry row（含 master/alternates/entryPoisVersion）→ 解析。
  - `setEntryMaster`：PATCH `/trips/okinawa/entries/11/master`，data `{'poiId':501,'entryPoisVersion':'2'}` → 200 completes。
  - `addEntryAlternate`：POST `/trips/okinawa/entries/11/alternates`，data 含 `name/lat/lng/type`（find-or-create）+ entryPoisVersion → 201 completes。
  - `removeEntryAlternate`：DELETE `/trips/okinawa/entries/11/alternates/502`，query `{'entryPoisVersion':'2'}` → 200 completes。
  - `reorderEntryAlternates`：PATCH `.../alternates/reorder`，data `{'order':[503,502],'entryPoisVersion':'2'}` → 200 completes。
  - `updateEntryPoi`：PATCH `.../pois/501`，data 只含有值欄位（如 `{'note':'記得訂位','poi_type':'restaurant'}`）→ 200 completes（無 OCC）。
- [ ] 跑 → 失敗。
- [ ] 實作：
    ```dart
    Future<TimelineEntry> fetchEntry({
      required String tripId,
      required int entryId,
    }) async {
      final body = await _client
          .get('/trips/${Uri.encodeComponent(tripId)}/entries/$entryId');
      return TimelineEntry.fromJson(body as Map<String, dynamic>);
    }

    Future<void> setEntryMaster({
      required String tripId,
      required int entryId,
      required int poiId,
      String? entryPoisVersion,
    }) {
      return _client.patch(
        '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId/master',
        body: {
          'poiId': poiId,
          if (entryPoisVersion != null) 'entryPoisVersion': entryPoisVersion,
        },
      );
    }

    Future<void> addEntryAlternate({
      required String tripId,
      required int entryId,
      required PoiSearchResult poi,
      String? entryPoisVersion,
    }) {
      return _client.post(
        '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId/alternates',
        body: {
          'name': poi.name,
          'lat': poi.lat,
          'lng': poi.lng,
          'type': mapGooglePrimaryTypeToPoiType(poi.category),
          'category': poi.category,
          'address': poi.address,
          'rating': poi.rating,
          'source': 'search',
          if (entryPoisVersion != null) 'entryPoisVersion': entryPoisVersion,
        },
      );
    }

    Future<void> removeEntryAlternate({
      required String tripId,
      required int entryId,
      required int poiId,
      String? entryPoisVersion,
    }) {
      return _client.delete(
        '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId/alternates/$poiId',
        query: {if (entryPoisVersion != null) 'entryPoisVersion': entryPoisVersion},
      );
    }

    Future<void> reorderEntryAlternates({
      required String tripId,
      required int entryId,
      required List<int> order,
      String? entryPoisVersion,
    }) {
      return _client.patch(
        '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId/alternates/reorder',
        body: {
          'order': order,
          if (entryPoisVersion != null) 'entryPoisVersion': entryPoisVersion,
        },
      );
    }

    Future<void> updateEntryPoi({
      required String tripId,
      required int entryId,
      required int poiId,
      String? note,
      String? poiType,
      String? reservation,
    }) {
      return _client.patch(
        '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId/pois/$poiId',
        body: {
          if (note != null) 'note': note,
          if (poiType != null) 'poi_type': poiType,
          if (reservation != null) 'reservation': reservation,
        },
      );
    }
    ```
  > 需 import `../models/poi_search_result.dart` 與 `../models/poi_type.dart`（mapGooglePrimaryTypeToPoiType）。確認 `ApiClient.delete` 支援 `query:`；若無則改 path 串 `?entryPoisVersion=`。
- [ ] 跑 → 綠。commit `feat: TripRepository POI 管理（fetchEntry/setMaster/alternates*/updateEntryPoi）`。

> Task 0.3 後 repository 已 +13 方法。評估抽 `EntryMutationRepository`：本計畫**先不抽**（同檔內聚、provider 鏈不變、測試集中）；若 analyze 抱怨檔過大或可讀性差再於收尾抽。

---

# 階段 C：拖曳排序 + 跨天搬移

## Task C.1：providers + `_DaySection` 拖曳

**Files:** `lib/features/trip_detail/trip_timeline_screen.dart`；test `test/features/trip_detail/trip_timeline_screen_test.dart`(擴)。

- [ ] 測試：
  - 拖曳：`ReorderableListView` 內以 `ReorderableDragStartListener`（drag handle key `entry-drag-<id>`）模擬 reorder → verify `reorderEntries` 被呼叫（updates 含新 sort_order）。（widget 拖曳測試可用 `tester.drag` handle 或直接呼叫 onReorder 的近似；以 drag handle 拖動實作。）
  - 既有 tap（開編輯 sheet）、左滑（deleteEntry）測試保持綠。
- [ ] 實作：
  - `_DaySection` entries 區改 `ReorderableListView`（`shrinkWrap: true`、`physics: const NeverScrollableScrollPhysics()`、`buildDefaultDragHandles: false`）。
  - item（key `ValueKey('entry-${entry.id}')`）= `Column[ if leading travel _TravelRow, Row[ Expanded(Dismissible→TimelineEntryTile(onTap 編輯)), ReorderableDragStartListener(index:i, child: Icon(Icons.drag_handle, key: entry-drag-<id>)) ] ]`。
  - `onReorder: (oldI, newI) { 調整 index → 計算該日新順序 → reorderEntries(updates: [for i: (id: e.id, sortOrder: i, dayId: null)]) → invalidate(tripDaysProvider) → recomputeTravel(fire-and-forget) }`。
  - 注意 `onReorder` 的 newIndex 修正（newIndex > oldIndex 時 -1）。
- [ ] 跑 → 綠。commit `feat: timeline 同日拖曳排序（drag handle + batch sort_order）`。

## Task C.2：跨天搬移 action

**Files:** 同上 + 可能小 helper sheet。

- [ ] 測試：tile 的 `⋮`（key `entry-menu-<id>`）→「移到其他天」→ 選 day（key `move-day-<dayId>`）→ verify `reorderEntries(updates:[(id, sortOrder: 末位, dayId: 目標)])`。
- [ ] 實作：tile trailing 加 `⋮` `PopupMenuButton`（或 IconButton 開 sheet）→「移到其他天」→ `showModalBottomSheet` 列出所有 day（排除目前 day）→ 選定 → `reorderEntries` 帶 dayId（sort_order = 目標日末位，可用該日 timeline.length）→ invalidate + recompute。需把 `List<TripDay> allDays` 傳進 `_DaySection`（或從 provider 讀）。
- [ ] 跑 → 綠。commit `feat: entry 跨天搬移（移到其他天 action）`。

---

# 階段 D：地點管理全頁

## Task D.1：EntryPoiScreen + 路由 + 入口（顯示）

**Files:** 新 `lib/features/trip_detail/entry_poi_screen.dart`；`lib/features/trip_detail/trip_providers.dart`（+`entryDetailProvider`）；`lib/app/router.dart`（+子路由）；`lib/features/trip_detail/widgets/entry_edit_sheet.dart`（+「管理地點」入口）；test 新 `test/features/trip_detail/entry_poi_screen_test.dart`。

- [ ] 測試：override `tripRepositoryProvider` mock，`entryDetailProvider` 回含 master + 2 alternates 的 entry → 畫面顯示 master 名稱、alternates 名稱、各操作鈕（set-master/remove/add）。
- [ ] 實作：
  - `entryDetailProvider = FutureProvider.family<TimelineEntry, ({String tripId, int entryId})>((ref, k) => ref.watch(tripRepositoryProvider).fetchEntry(tripId: k.tripId, entryId: k.entryId));`
  - `EntryPoiScreen({tripId, entryId})` watch `entryDetailProvider((tripId, entryId))`：master 卡 + alternates 列（每列 set-master/remove）+「加入備選」鈕 + per-POI 編輯區。ValueKey：`poi-master`、`alt-<poiId>`、`alt-setmaster-<poiId>`、`alt-remove-<poiId>`、`add-alternate`、`poi-note`、`poi-type-<t>`、`poi-reservation`、`poi-save`。
  - router：`trips/:tripId` 下加 `GoRoute(path: 'entries/:eid/pois', builder: EntryPoiScreen(tripId: pathParam tripId, entryId: int.parse(eid)))`。
  - `EntryEditSheet` 加「管理地點 ▸」按鈕（僅 existing 模式）→ `Navigator.pop()` 後 `context.push('/trips/$tripId/entries/${entry.id}/pois')`。
- [ ] 跑 → 綠。commit `feat: EntryPoiScreen 顯示 + 路由 + 編輯 sheet 入口`。

## Task D.2：POI 操作（set master / remove / add / per-POI 編輯）

**Files:** 同 D.1。

- [ ] 測試：set-master→`setEntryMaster(poiId, entryPoisVersion)`；remove→`removeEntryAlternate`；加備選（mock `poiRepositoryProvider.searchPois`）選結果→`addEntryAlternate`；per-POI 存→`updateEntryPoi(note/poiType/reservation)`；各操作後 invalidate entryDetail。OCC token 取自 entry.entryPoisVersion。
- [ ] 實作：各鈕呼叫對應 repository（帶 `entry.entryPoisVersion`）→ `invalidate(entryDetailProvider((tripId,entryId)))` + `invalidate(tripDaysProvider(tripId))` + snackbar；409 → invalidate + snackbar「地點已更新,已重新載入」。加備選用 `showModalBottomSheet` + reuse explore 的 `poiRepositoryProvider.searchPois`（簡版搜尋列）。per-POI 區：note TextField、poi_type 8 chips（`kPoiTypeLabels`）、reservation TextField + 儲存鈕。
- [ ] 跑 → 綠。commit `feat: EntryPoiScreen POI 操作（master/alternates/per-POI + OCC）`。

## Task D.3（選配）：alternates 重排

- [ ] alternates 列表用 `ReorderableListView` → `reorderEntryAlternates(order: poiId[])`。測試 + 實作 + commit。（若時間/複雜度高可延後，但本 PR 範圍內盡量含。）

---

# 階段 E：交通編輯

## Task E.1：tripSegmentsProvider + travel pill 編輯

**Files:** `lib/features/trip_detail/trip_providers.dart`（+`tripSegmentsProvider`）；`trip_timeline_screen.dart`（_TravelRow 接 onTap + segment 比對）；新 `lib/features/trip_detail/widgets/travel_edit_sheet.dart`；test 擴 + 新。

- [ ] 測試：
  - `tripSegmentsProvider` override → `_DaySection` 比對 travel pill 對應 segment（fromEntryId/toEntryId）→ travel pill 可點。
  - 點 travel pill → sheet；選「大眾運輸」填分鐘送出 → `updateSegment(segmentId, mode:'transit', min, expectedVersion)`；選「開車」送出不帶 min。
  - 無對應 segment → pill onTap null（不可點）。
- [ ] 實作：
  - `tripSegmentsProvider = FutureProvider.family<List<TripSegment>, String>((ref, id) => ref.watch(tripRepositoryProvider).fetchSegments(tripId: id));`
  - `_DaySection` watch segments（`ref.watch(tripSegmentsProvider(tripId)).valueOrNull ?? []`，用 pattern match 取 AsyncData）。對每個 leading travel（entry[i] 前），比對 `seg.fromEntryId==timeline[i-1].id && seg.toEntryId==timeline[i].id` → 傳給 `_TravelRow(travel, segment?, onTap)`。
  - `_TravelRow` 包 InkWell（segment 非 null 才可點）→ `showTravelEditSheet(context, tripId, segment)`。
  - `travel_edit_sheet.dart`：mode 三選一（開車=driving/步行=walking/大眾運輸=transit）；transit 顯示分鐘 TextField（必填）；送出 `updateSegment` → invalidate days + segments + snackbar；409 → invalidate segments + snackbar。
- [ ] 跑 → 綠。commit `feat: 交通編輯（segments provider + travel pill 編輯 sheet）`。

---

# 收尾

- [ ] 全專案 `flutter analyze`（0）+ `flutter test`（全綠）。
- [ ] 評估 `EntryMutationRepository` 抽離（若 repository 過肥）。
- [ ] finishing-a-development-branch：push。開 PR：若 #7 已 merge master → base master；否則 base `feat/timeline-entry-edit-delete-add`（stacked）。
- [ ] （選配，使用者授權後）iOS smoke：拖曳排序 / 跨天搬移 / 換正選+加備選+備註 / 改交通；自建自刪清乾淨。

## 自我審查（plan vs spec）
- C 拖曳+跨天 move → C.1/C.2；D 全頁+POI 操作 → D.1/D.2(/D.3)；E segment 編輯 → E.1；model/repo → 階段 0。
- OCC：D `entryPoisVersion`(string)、E `expectedVersion`(number)、C 無 OCC，三處一致。
- ValueKey 與路由命名一致；無 placeholder。
