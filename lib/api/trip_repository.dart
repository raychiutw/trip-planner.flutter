/// 行程資料 repository：my-trips / trips / days / notes / stats / profile。
library;

import '../models/day.dart';
import '../models/destination_input.dart';
import '../models/entry.dart';
import '../models/note_section.dart';
import '../models/notes.dart';
import '../models/poi_search_result.dart';
import '../models/poi_type.dart';
import '../models/segment.dart';
import '../models/trip.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'cache/cache_keys.dart';
import 'cache/offline_op.dart';

/// 對應 `/api/my-trips`、`/api/trips/*`、`/api/account/*`。
class TripRepository {
  TripRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// days 快取 key(離線 entry 樂觀 patch 的目標)。
  String _daysKey(String tripId) => cacheKeyFor(
    'GET',
    '/trips/${Uri.encodeComponent(tripId)}/days',
    const {'all': '1'},
  );

  /// GET /my-trips。
  Future<List<TripSummary>> fetchMyTrips() async {
    final responseBody = await _client.get('/my-trips');
    return (responseBody as List<dynamic>)
        .map(
          (tripJson) => TripSummary.fromJson(tripJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// GET /my-trips（SWR stream:stale→fresh）。
  Stream<List<TripSummary>> watchMyTrips() => _client
      .getStream('/my-trips')
      .map(
        (body) => (body as List<dynamic>)
            .map(
              (tripJson) =>
                  TripSummary.fromJson(tripJson as Map<String, dynamic>),
            )
            .toList(),
      );

  /// POST /trips（建立;body 混 camel + snake_case destinations）→ {tripId,...}。
  /// 後端自動建好每日 days + owner 權限;不回整列。
  Future<({String tripId, int daysCreated, int destinationsCreated})>
  createTrip({
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
    final body = await _client.post(
      '/trips',
      body: {
        'id': id,
        'name': name,
        'startDate': startDate,
        'endDate': endDate,
        'title': ?title,
        'description': ?description,
        'countries': countries,
        'published': published,
        'data_source': dataSource,
        'lang': lang,
        'destinations': [for (final d in destinations) d.toJson()],
      },
    );
    final map = body as Map<String, dynamic>;
    return (
      tripId: map['tripId'] as String? ?? id,
      daysCreated: (map['daysCreated'] as num?)?.toInt() ?? 0,
      destinationsCreated: (map['destinationsCreated'] as num?)?.toInt() ?? 0,
    );
  }

  /// PUT /trips/:id（編輯;diff-only,只送非 null;無 OCC,不要送 expectedVersion）。
  /// destinations 給了才全量替換(給 `[]` 清空、不給不動)。
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
    await _client.put(
      '/trips/${Uri.encodeComponent(id)}',
      body: {
        'name': ?name,
        'title': ?title,
        'description': ?description,
        'countries': ?countries,
        'published': ?published,
        'data_source': ?dataSource,
        'lang': ?lang,
        if (destinations != null)
          'destinations': [for (final d in destinations) d.toJson()],
      },
    );
  }

  /// GET /trips（published 行程清單）。
  Future<List<Trip>> fetchTrips() async {
    final responseBody = await _client.get('/trips');
    return (responseBody as List<dynamic>)
        .map((tripJson) => Trip.fromJson(tripJson as Map<String, dynamic>))
        .toList();
  }

  /// GET /trips/:id。
  Future<Trip> fetchTrip(String id) async {
    final responseBody = await _client.get('/trips/${Uri.encodeComponent(id)}');
    return Trip.fromJson(responseBody as Map<String, dynamic>);
  }

  /// GET /trips/:id（SWR stream）。
  Stream<Trip> watchTrip(String id) => _client
      .getStream('/trips/${Uri.encodeComponent(id)}')
      .map((body) => Trip.fromJson(body as Map<String, dynamic>));

  /// GET /trips/:id/days?all=1（完整 timeline）。
  Future<List<TripDay>> fetchDays(String id) async {
    final responseBody = await _client.get(
      '/trips/${Uri.encodeComponent(id)}/days',
      query: {'all': '1'},
    );
    return (responseBody as List<dynamic>)
        .map((dayJson) => TripDay.fromJson(dayJson as Map<String, dynamic>))
        .toList();
  }

  /// GET /trips/:id/days?all=1（SWR stream）。
  Stream<List<TripDay>> watchDays(String id) => _client
      .getStream('/trips/${Uri.encodeComponent(id)}/days', query: {'all': '1'})
      .map(
        (body) => (body as List<dynamic>)
            .map((dayJson) => TripDay.fromJson(dayJson as Map<String, dynamic>))
            .toList(),
      );

  /// GET /trips/:id/notes（5 區聚合）。
  Future<TripNotes> fetchNotes(String id) async {
    final responseBody = await _client.get(
      '/trips/${Uri.encodeComponent(id)}/notes',
    );
    return TripNotes.fromJson(responseBody as Map<String, dynamic>);
  }

  /// GET /trips/:id/notes（SWR stream）。
  Stream<TripNotes> watchNotes(String id) => _client
      .getStream('/trips/${Uri.encodeComponent(id)}/notes')
      .map((body) => TripNotes.fromJson(body as Map<String, dynamic>));

  /// POST /trips/:id/notes/{section}（建立筆記;body snake_case 欄位,5 區共用）。
  Future<void> createNote(
    NoteSection section, {
    required String tripId,
    required Map<String, dynamic> fields,
  }) {
    return _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/notes/${section.name}',
      body: fields,
    );
  }

  /// PATCH /trips/:id/notes/{section}/:rowId（OCC expectedVersion;409 STALE_ENTRY）。
  Future<void> updateNote(
    NoteSection section, {
    required String tripId,
    required int rowId,
    required Map<String, dynamic> fields,
    int? expectedVersion,
  }) {
    return _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/notes/${section.name}/$rowId',
      body: {...fields, 'expectedVersion': ?expectedVersion},
    );
  }

  /// DELETE /trips/:id/notes/{section}/:rowId（回 200 {ok:true},忽略 body）。
  Future<void> deleteNote(
    NoteSection section, {
    required String tripId,
    required int rowId,
  }) {
    return _client.delete(
      '/trips/${Uri.encodeComponent(tripId)}/notes/${section.name}/$rowId',
    );
  }

  /// PATCH /trips/:id/notes/{section}/reorder（items camelCase）。
  Future<void> reorderNotes(
    NoteSection section, {
    required String tripId,
    required List<({int id, int sortOrder})> items,
  }) {
    return _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/notes/${section.name}/reorder',
      body: {
        'items': [
          for (final it in items) {'id': it.id, 'sortOrder': it.sortOrder},
        ],
      },
    );
  }

  /// DELETE /trips/:id（限 owner/admin）。
  Future<void> deleteTrip(String id) =>
      _client.delete('/trips/${Uri.encodeComponent(id)}');

  /// POST /trips/:id/days/:num/entries（direct add,body snake_case;後端自動 find-or-create POI）。
  Future<void> addEntryToDay({
    required String tripId,
    required int dayNum,
    required String title,
    String? description,
    String? poiType,
    double? lat,
    double? lng,
    String? startTime,
    String? endTime,
    String source = 'user-explore',
  }) {
    return _client.sendMutation(
      'POST',
      '/trips/${Uri.encodeComponent(tripId)}/days/$dayNum/entries',
      body: {
        'title': title,
        'description': description,
        'poi_type': poiType,
        'lat': lat,
        'lng': lng,
        'start_time': startTime,
        'end_time': endTime,
        'source': source,
      },
      optimistic: OfflineOp('entry.add', _daysKey(tripId), {
        'dayNum': dayNum,
        'title': title,
        'description': description,
        'startTime': startTime,
        'endTime': endTime,
        'poiType': poiType,
        'lat': lat,
        'lng': lng,
      }),
    );
  }

  /// PATCH /trips/:id/entries/:eid（meta 編輯;欄位 snake_case + OCC camelCase expectedVersion）。
  /// 409 STALE_ENTRY 時 ApiClient 丟 ApiError(status 409)。
  Future<void> updateEntry({
    required String tripId,
    required int entryId,
    required int expectedVersion,
    required String title,
    String? description,
    String? startTime,
    String? endTime,
  }) {
    return _client.sendMutation(
      'PATCH',
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId',
      body: {
        'title': title,
        'description': description,
        'start_time': startTime,
        'end_time': endTime,
        'expectedVersion': expectedVersion,
      },
      optimistic: OfflineOp('entry.update', _daysKey(tripId), {
        'entryId': entryId,
        'title': title,
        'description': description,
        'startTime': startTime,
        'endTime': endTime,
      }),
    );
  }

  /// DELETE /trips/:id/entries/:eid（後端回 200 {ok:true},忽略 body）。
  Future<void> deleteEntry({required String tripId, required int entryId}) {
    return _client.sendMutation(
      'DELETE',
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId',
      optimistic: OfflineOp('entry.delete', _daysKey(tripId), {
        'entryId': entryId,
      }),
    );
  }

  /// PATCH /trips/:id/entries/batch（批次 reorder/搬移,snake_case,無 OCC）。
  /// 同天 reorder 只帶 sortOrder;跨天搬移帶 dayId。
  Future<void> reorderEntries({
    required String tripId,
    required List<({int id, int sortOrder, int? dayId})> updates,
  }) {
    return _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/entries/batch',
      body: {
        'updates': [
          for (final u in updates)
            {'id': u.id, 'sort_order': u.sortOrder, 'day_id': ?u.dayId},
        ],
      },
    );
  }

  /// POST /trips/:id/recompute-travel?day=（reorder/換 POI 後重算交通,fire-and-forget）。
  Future<void> recomputeTravel({required String tripId, String day = 'all'}) {
    return _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/recompute-travel',
      query: {'day': day},
    );
  }

  /// GET /trips/:id/segments（交通段;含 id/version 供編輯）。
  Future<List<TripSegment>> fetchSegments({required String tripId}) async {
    final body = await _client.get(
      '/trips/${Uri.encodeComponent(tripId)}/segments',
    );
    return (body as List<dynamic>)
        .map((e) => TripSegment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /trips/:id/segments（SWR stream）。
  Stream<List<TripSegment>> watchSegments({required String tripId}) => _client
      .getStream('/trips/${Uri.encodeComponent(tripId)}/segments')
      .map(
        (body) => (body as List<dynamic>)
            .map((e) => TripSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// PATCH /trips/:id/segments/:sid（mode driving/walking/transit;OCC expectedVersion）。
  /// transit 必帶 min;driving/walking 後端打 Google 重算(忽略 min)。
  Future<TripSegment> updateSegment({
    required String tripId,
    required int segmentId,
    required String mode,
    int? min,
    int? expectedVersion,
  }) async {
    final body = await _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/segments/$segmentId',
      body: {'mode': mode, 'min': ?min, 'expectedVersion': ?expectedVersion},
    );
    return TripSegment.fromJson(body as Map<String, dynamic>);
  }

  /// GET /trips/:id/entries/:eid（單筆;含 master/alternates/entryPoisVersion,無 travel）。
  Future<TimelineEntry> fetchEntry({
    required String tripId,
    required int entryId,
  }) async {
    final body = await _client.get(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId',
    );
    return TimelineEntry.fromJson(body as Map<String, dynamic>);
  }

  /// GET /trips/:id/entries/:eid（SWR stream）。
  Stream<TimelineEntry> watchEntry({
    required String tripId,
    required int entryId,
  }) => _client
      .getStream('/trips/${Uri.encodeComponent(tripId)}/entries/$entryId')
      .map((body) => TimelineEntry.fromJson(body as Map<String, dynamic>));

  /// PATCH /trips/:id/entries/:eid/master（設正選;OCC entryPoisVersion）。
  Future<void> setEntryMaster({
    required String tripId,
    required int entryId,
    required int poiId,
    String? entryPoisVersion,
  }) {
    return _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId/master',
      body: {'poiId': poiId, 'entryPoisVersion': ?entryPoisVersion},
    );
  }

  /// POST /trips/:id/entries/:eid/alternates（find-or-create 變體;POI 分類欄用 `type`）。
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
        'entryPoisVersion': ?entryPoisVersion,
      },
    );
  }

  /// DELETE /trips/:id/entries/:eid/alternates/:poiId（OCC token 走 query）。
  Future<void> removeEntryAlternate({
    required String tripId,
    required int entryId,
    required int poiId,
    String? entryPoisVersion,
  }) {
    return _client.delete(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId/alternates/$poiId',
      query: {'entryPoisVersion': ?entryPoisVersion},
    );
  }

  /// PATCH /trips/:id/entries/:eid/alternates/reorder（order 為 poiId 陣列,不含 master）。
  Future<void> reorderEntryAlternates({
    required String tripId,
    required int entryId,
    required List<int> order,
    String? entryPoisVersion,
  }) {
    return _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId/alternates/reorder',
      body: {'order': order, 'entryPoisVersion': ?entryPoisVersion},
    );
  }

  /// PATCH /trips/:id/entries/:eid/pois/:poiId（per-POI 備註/分類/訂位;LWW 無 OCC）。
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
      body: {'note': ?note, 'poi_type': ?poiType, 'reservation': ?reservation},
    );
  }

  /// GET /account/stats。
  Future<AccountStats> fetchStats() async {
    final responseBody = await _client.get('/account/stats');
    return AccountStats.fromJson(responseBody as Map<String, dynamic>);
  }

  /// PATCH /account/profile（displayName 傳 null 表示清除）。
  Future<UserInfo> updateProfile({String? displayName}) async {
    final responseBody = await _client.patch(
      '/account/profile',
      body: {'displayName': displayName},
    );
    return UserInfo.fromJson(responseBody as Map<String, dynamic>);
  }
}
