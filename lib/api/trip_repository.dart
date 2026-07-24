/// 行程資料 repository：my-trips / trips / days / notes / stats / profile。
library;

import 'dart:convert';

import '../models/day.dart';
import '../models/destination_input.dart';
import '../models/entry.dart';
import '../models/note_section.dart';
import '../models/notes.dart';
import '../models/oauth.dart';
import '../models/poi_search_result.dart';
import '../models/poi_type.dart';
import '../models/segment.dart';
import '../models/share.dart';
import '../models/trip.dart';
import '../models/trip_audit.dart';
import '../models/trip_doc.dart';
import '../models/trip_health.dart';
import '../models/trip_poi_health.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'cache/cache_keys.dart';
import 'cache/offline_op.dart';

/// 行程 JSON 匯出結果，`content` 可直接寫入 `fileName`。
class TripJsonExport {
  const TripJsonExport({required this.fileName, required this.content});

  final String fileName;
  final String content;
}

/// 置換正選或加入備選時使用的自訂 POI payload。
class CustomEntryPoi {
  const CustomEntryPoi({
    required this.name,
    required this.lat,
    required this.lng,
    this.poiType = 'attraction',
    this.category,
    this.address,
  });

  /// 顯示名稱。
  final String name;

  /// 緯度。
  final double lat;

  /// 經度。
  final double lng;

  /// 後端 `pois.type` 白名單值。
  final String poiType;

  /// 原始分類；未提供時沿用 [poiType]。
  final String? category;

  /// 地址或補充位置文字。
  final String? address;
}

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

  /// notes 快取 key(離線 note 樂觀 patch 的目標)。
  String _notesKey(String tripId) =>
      cacheKeyFor('GET', '/trips/${Uri.encodeComponent(tripId)}/notes');

  /// 聚合 GET /notes 的 response 段名(pretrip/emergency 與 URL 段名不同)。
  String _notesSectionKey(NoteSection s) => switch (s) {
    NoteSection.pretrip => 'pretripNotes',
    NoteSection.emergency => 'emergencyContacts',
    _ => s.name,
  };

  // 一次性 fetch 與 SWR watch 共用的解析器(消成對重複)。
  static T _one<T>(Object? body, T Function(Map<String, dynamic>) fromJson) =>
      fromJson(body as Map<String, dynamic>);
  static List<T> _list<T>(
    Object? body,
    T Function(Map<String, dynamic>) fromJson,
  ) => (body as List<dynamic>)
      .map((e) => fromJson(e as Map<String, dynamic>))
      .toList();

  static TripHealthReport? _optionalHealthReport(Object? body) {
    final map = body as Map<String, dynamic>;
    final report = map['report'];
    if (report == null) return null;
    return TripHealthReport.fromJson(Map<String, dynamic>.from(report as Map));
  }

  /// GET /my-trips。
  Future<List<TripSummary>> fetchMyTrips() async =>
      _list(await _client.get('/my-trips'), TripSummary.fromJson);

  /// GET /my-trips（SWR stream:stale→fresh）。
  Stream<List<TripSummary>> watchMyTrips() =>
      _client.getStream('/my-trips').map((b) => _list(b, TripSummary.fromJson));

  /// POST /trips（建立;body 混 camel + snake_case destinations）→ {tripId,...}。
  /// 後端自動建好每日 days + owner 權限;不回整列。
  Future<({String tripId, int daysCreated, int destinationsCreated})>
  createTrip({
    required String name,
    required String startDate,
    required String endDate,
    String? title,
    String? description,
    String countries = 'JP',
    int published = 0,
    String dataSource = 'manual',
    String lang = 'zh-TW',
    List<DestinationInput> destinations = const [],
  }) async {
    final body = await _client.post(
      '/trips',
      body: {
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
      tripId: map['tripId'] as String,
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

  /// GET /trips（published 行程清單；service token 可用 all=1 取全列表）。
  Future<List<Trip>> fetchTrips({bool all = false}) async => _list(
    await _client.get('/trips', query: {if (all) 'all': '1'}),
    Trip.fromJson,
  );

  /// GET /trips/:id。
  Future<Trip> fetchTrip(String id) async => _one(
    await _client.get('/trips/${Uri.encodeComponent(id)}'),
    Trip.fromJson,
  );

  /// GET /trips/:id/health-check（AI 健檢 report;不走離線 cache）。
  Future<TripHealthReport?> fetchHealthReport(String id) async {
    final body = await _client.get(
      '/trips/${Uri.encodeComponent(id)}/health-check',
      writeCache: false,
      fallbackToCache: false,
    );
    return _optionalHealthReport(body);
  }

  /// GET /trips/:id/health（POI closed/missing 摘要）。
  Future<TripPoiHealthReport> fetchPoiHealth(String id) async {
    final body = await _client.get('/trips/${Uri.encodeComponent(id)}/health');
    return TripPoiHealthReport.fromJson(body as Map<String, dynamic>);
  }

  /// POST /trips/:id/health-check（啟動 AI 健檢）。
  Future<TripHealthReport> startHealthCheck(String id) async {
    final body = await _client.post(
      '/trips/${Uri.encodeComponent(id)}/health-check',
    );
    final report = _optionalHealthReport(body);
    if (report == null) {
      throw const FormatException('Missing health-check report');
    }
    return report;
  }

  /// GET /trips/:id（SWR stream）。
  Stream<Trip> watchTrip(String id) => _client
      .getStream('/trips/${Uri.encodeComponent(id)}')
      .map((b) => _one(b, Trip.fromJson));

  /// GET /trips/:id/days?all=1（完整 timeline）。
  Future<List<TripDay>> fetchDays(String id) async => _list(
    await _client.get(
      '/trips/${Uri.encodeComponent(id)}/days',
      query: {'all': '1'},
    ),
    TripDay.fromJson,
  );

  /// GET /trips/:id/days（僅 day 摘要，不含 timeline）。
  Future<List<TripDay>> fetchDaySummaries(
    String id, {
    bool fallbackToCache = true,
  }) async => _list(
    await _client.get(
      '/trips/${Uri.encodeComponent(id)}/days',
      fallbackToCache: fallbackToCache,
    ),
    TripDay.fromJson,
  );

  /// GET /trips/:id/days/:num（完整單日 timeline）。
  Future<TripDay> fetchDay({
    required String tripId,
    required int dayNum,
  }) async => _one(
    await _client.get('/trips/${Uri.encodeComponent(tripId)}/days/$dayNum'),
    TripDay.fromJson,
  );

  /// GET /trips/:id/days?all=1（SWR stream）。
  Stream<List<TripDay>> watchDays(String id) => _client
      .getStream('/trips/${Uri.encodeComponent(id)}/days', query: {'all': '1'})
      .map((b) => _list(b, TripDay.fromJson));

  /// PUT /trips/:id/days/:num（整天覆寫；timeline 必須是完整新狀態）。
  Future<int> updateDay({
    required String tripId,
    required int dayNum,
    required String date,
    required String dayOfWeek,
    required String label,
    required List<Map<String, dynamic>> timeline,
    Map<String, dynamic>? hotel,
    int? expectedDayVersion,
  }) async {
    final body = await _client.put(
      '/trips/${Uri.encodeComponent(tripId)}/days/$dayNum',
      body: {
        'date': date,
        'dayOfWeek': dayOfWeek,
        'label': label,
        'hotel': ?hotel,
        'timeline': timeline,
        'expectedDayVersion': ?expectedDayVersion,
      },
    );
    final map = body as Map<String, dynamic>;
    return (map['dayVersion'] as num?)?.toInt() ?? 0;
  }

  /// POST /trips/:id/days（position=start/end/insert；insert 需 date）。
  Future<TripDay> createDay({
    required String tripId,
    required String position,
    String? date,
  }) async {
    final body = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/days',
      body: {'position': position, 'date': ?date},
    );
    final map = body as Map<String, dynamic>;
    return TripDay.fromJson(Map<String, dynamic>.from(map['day'] as Map));
  }

  /// DELETE /trips/:id/days/:num（刪除一天並重新編號後續 day_num）。
  Future<int> deleteDay({required String tripId, required int dayNum}) async {
    final body = await _client.delete(
      '/trips/${Uri.encodeComponent(tripId)}/days/$dayNum',
    );
    final map = body as Map<String, dynamic>;
    return (map['removedEntryCount'] as num?)?.toInt() ?? 0;
  }

  /// POST /trips/:id/days/shift（整體平移日期，startDate 為新 Day 1 日期）。
  Future<({String newStartDate, String? newEndDate, int daysShifted})>
  shiftDays({required String tripId, required String startDate}) async {
    final body = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/days/shift',
      body: {'startDate': startDate},
    );
    final map = body as Map<String, dynamic>;
    return (
      newStartDate: map['newStartDate'] as String? ?? startDate,
      newEndDate: map['newEndDate'] as String?,
      daysShifted: (map['daysShifted'] as num?)?.toInt() ?? 0,
    );
  }

  /// GET /trips/:id/notes（5 區聚合）。
  Future<TripNotes> fetchNotes(String id) async => _one(
    await _client.get('/trips/${Uri.encodeComponent(id)}/notes'),
    TripNotes.fromJson,
  );

  /// GET /trips/:id/notes（SWR stream）。
  Stream<TripNotes> watchNotes(String id) => _client
      .getStream('/trips/${Uri.encodeComponent(id)}/notes')
      .map((b) => _one(b, TripNotes.fromJson));

  /// GET /trips/:id/docs（batch 讀取全部 trip_docs；缺的 doc type 為 null）。
  Future<TripDocs> fetchTripDocs(String id) async {
    final body = await _client.get('/trips/${Uri.encodeComponent(id)}/docs');
    return TripDocs.fromJson(body as Map<String, dynamic>);
  }

  /// GET /trips/:id/docs/:type。
  Future<TripDoc> fetchTripDoc({
    required String tripId,
    required TripDocType type,
  }) async {
    final body = await _client.get(
      '/trips/${Uri.encodeComponent(tripId)}/docs/${tripDocTypeKey(type)}',
    );
    return TripDoc.fromJson(body as Map<String, dynamic>);
  }

  /// PUT /trips/:id/docs/:type（title + entries 全量覆寫）。
  Future<void> saveTripDoc({
    required String tripId,
    required TripDocType type,
    required String title,
    required List<TripDocEntry> entries,
  }) {
    return _client.put(
      '/trips/${Uri.encodeComponent(tripId)}/docs/${tripDocTypeKey(type)}',
      body: {
        'title': title,
        'entries': [for (final entry in entries) entry.toJson()],
      },
    );
  }

  /// POST /trips/:id/notes/{section}（建立筆記;body snake_case 欄位,5 區共用）。
  Future<void> createNote(
    NoteSection section, {
    required String tripId,
    required Map<String, dynamic> fields,
  }) {
    return _client.sendMutation(
      'POST',
      '/trips/${Uri.encodeComponent(tripId)}/notes/${section.name}',
      body: fields,
      optimistic: OfflineOp('note.create', _notesKey(tripId), {
        'sectionKey': _notesSectionKey(section),
        'fields': fields,
      }),
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
    return _client.sendMutation(
      'PATCH',
      '/trips/${Uri.encodeComponent(tripId)}/notes/${section.name}/$rowId',
      body: {...fields, 'expectedVersion': ?expectedVersion},
      optimistic: OfflineOp('note.update', _notesKey(tripId), {
        'sectionKey': _notesSectionKey(section),
        'rowId': rowId,
        'fields': fields,
      }),
    );
  }

  /// DELETE /trips/:id/notes/{section}/:rowId（回 200 {ok:true},忽略 body）。
  Future<void> deleteNote(
    NoteSection section, {
    required String tripId,
    required int rowId,
  }) {
    return _client.sendMutation(
      'DELETE',
      '/trips/${Uri.encodeComponent(tripId)}/notes/${section.name}/$rowId',
      optimistic: OfflineOp('note.delete', _notesKey(tripId), {
        'sectionKey': _notesSectionKey(section),
        'rowId': rowId,
      }),
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

  /// POST /trips/:id/notes/:type/generate（啟動 AI 產生筆記 job）。
  Future<
    ({int jobId, int requestId, String status, String tripId, String docType})
  >
  generateNotes(NoteGenerationType type, {required String tripId}) async {
    final body = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/notes/${type.pathSegment}/generate',
    );
    final map = body as Map<String, dynamic>;
    return (
      jobId: (map['jobId'] as num).toInt(),
      requestId: (map['requestId'] as num).toInt(),
      status: map['status'] as String? ?? 'pending',
      tripId: map['tripId'] as String? ?? tripId,
      docType: map['docType'] as String? ?? type.pathSegment,
    );
  }

  /// GET /trips/:id/audit（依 trip 權限讀 audit log；requestId 可篩單次 AI/job）。
  Future<List<TripAuditRow>> fetchAuditLog(
    String id, {
    int? limit,
    int? requestId,
  }) async => _list(
    await _client.get(
      '/trips/${Uri.encodeComponent(id)}/audit',
      query: {
        'limit': ?limit?.toString(),
        'request_id': ?requestId?.toString(),
      },
    ),
    TripAuditRow.fromJson,
  );

  /// POST /trips/:id/audit/:aid/rollback（回滾指定 audit row）。
  Future<TripAuditRollbackResult> rollbackAudit({
    required String tripId,
    required int auditId,
  }) async {
    final body = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/audit/$auditId/rollback',
    );
    return TripAuditRollbackResult.fromJson(body as Map<String, dynamic>);
  }

  /// DELETE /trips/:id（限 owner/admin）。
  Future<void> deleteTrip(String id) =>
      _client.delete('/trips/${Uri.encodeComponent(id)}');

  /// POST /trips/import，送出 web 匯出的 raw JSON text 並回傳新 tripId。
  Future<String> importTripJson(String jsonText) async {
    final responseBody = await _client.post('/trips/import', body: jsonText);
    return (responseBody as Map<String, dynamic>)['tripId'] as String;
  }

  /// 匯出 web import 可吃的 schemaVersion 1 JSON。
  Future<TripJsonExport> exportTripJson(String tripId, {DateTime? now}) async {
    final encodedTripId = Uri.encodeComponent(tripId);
    final meta = _copyJsonMap(await _client.get('/trips/$encodedTripId'));
    final days = _asRecordList(
      await _client.get('/trips/$encodedTripId/days', query: {'all': '1'}),
    );
    final segments = await _fetchOptionalRecordList(
      '/trips/$encodedTripId/segments',
    );
    final notes = await _fetchOptionalMap('/trips/$encodedTripId/notes');
    final output = _buildTripExportJson(
      meta: meta,
      days: days,
      segments: segments,
      notes: notes,
    );

    return TripJsonExport(
      fileName:
          '${_tripExportFileBase(meta, tripId, now ?? DateTime.now())}.json',
      content: const JsonEncoder.withIndent('  ').convert(output),
    );
  }

  /// POST /trips/:id/days/:num/entries（direct add,body snake_case;後端自動 find-or-create POI）。
  Future<void> addEntryToDay({
    required String tripId,
    required int dayNum,
    required String title,
    String? description,
    String? note,
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
        'name': title,
        'description': description,
        'note': note,
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
        'note': note,
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
    String? description,
    String? startTime,
    String? endTime,
  }) {
    return _client.sendMutation(
      'PATCH',
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId',
      body: {
        'description': description,
        'start_time': startTime,
        'end_time': endTime,
        'expectedVersion': expectedVersion,
      },
      optimistic: OfflineOp('entry.update', _daysKey(tripId), {
        'entryId': entryId,
        'description': description,
        'startTime': startTime,
        'endTime': endTime,
      }),
    );
  }

  /// POST /trips/:id/entries/:eid/copy（複製到指定 day id;回傳新 entry id）。
  Future<int> copyEntry({
    required String tripId,
    required int entryId,
    required int targetDayId,
    int? sortOrder,
    String? time,
  }) async {
    final body = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId/copy',
      body: {
        'targetDayId': targetDayId,
        'sortOrder': ?sortOrder,
        'time': ?time,
      },
    );
    final map = body as Map<String, dynamic>;
    return (map['id'] as num).toInt();
  }

  /// PATCH /trips/:id/entries/:eid day_id（跨日移動;不帶 OCC,對齊 web EntryActionPage）。
  Future<void> moveEntry({
    required String tripId,
    required int entryId,
    required int targetDayId,
  }) {
    return _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId',
      body: {'day_id': targetDayId},
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
  Future<List<TripSegment>> fetchSegments({required String tripId}) async =>
      _list(
        await _client.get('/trips/${Uri.encodeComponent(tripId)}/segments'),
        TripSegment.fromJson,
      );

  /// POST /trips/:id/segments（from/to entry pair upsert）。
  Future<TripSegment> createSegment({
    required String tripId,
    required int fromEntryId,
    required int toEntryId,
    String? mode,
    String? submode,
    int? min,
    bool? noTravel,
  }) async {
    final body = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/segments',
      body: {
        'from_entry_id': fromEntryId,
        'to_entry_id': toEntryId,
        'mode': ?mode,
        'submode': ?submode,
        'min': ?min,
        'noTravel': ?noTravel,
      },
    );
    return TripSegment.fromJson(body as Map<String, dynamic>);
  }

  /// GET /trips/:id/segments（SWR stream）。
  Stream<List<TripSegment>> watchSegments({required String tripId}) => _client
      .getStream('/trips/${Uri.encodeComponent(tripId)}/segments')
      .map((b) => _list(b, TripSegment.fromJson));

  /// PATCH /trips/:id/segments/:sid（交通方式或 noTravel；OCC expectedVersion）。
  /// 省略 min 會恢復自動計算；submode 需顯式 null 才會清除。
  Future<TripSegment> updateSegment({
    required String tripId,
    required int segmentId,
    String? mode,
    String? submode,
    bool clearSubmode = false,
    int? min,
    bool? noTravel,
    int? expectedVersion,
  }) async {
    final body = await _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/segments/$segmentId',
      body: {
        'mode': ?mode,
        if (submode != null || clearSubmode) 'submode': submode,
        'min': ?min,
        'noTravel': ?noTravel,
        'expectedVersion': ?expectedVersion,
      },
    );
    return TripSegment.fromJson(body as Map<String, dynamic>);
  }

  /// GET /trips/:id/entries/:eid（單筆;含 master/alternates/entryPoisVersion,無 travel）。
  Future<TimelineEntry> fetchEntry({
    required String tripId,
    required int entryId,
  }) async => _one(
    await _client.get('/trips/${Uri.encodeComponent(tripId)}/entries/$entryId'),
    TimelineEntry.fromJson,
  );

  /// GET /trips/:id/entries/:eid（SWR stream）。
  Stream<TimelineEntry> watchEntry({
    required String tripId,
    required int entryId,
  }) => _client
      .getStream('/trips/${Uri.encodeComponent(tripId)}/entries/$entryId')
      .map((b) => _one(b, TimelineEntry.fromJson));

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

  /// PUT /trips/:id/entries/:eid/poi-id（更換正選 POI;支援既有 poiId 或搜尋結果 find-or-create）。
  Future<int> changeEntryPoi({
    required String tripId,
    required int entryId,
    int? poiId,
    PoiSearchResult? poi,
    CustomEntryPoi? customPoi,
    String? entryPoisVersion,
  }) async {
    final payload = _entryPoiPayload(
      poiId: poiId,
      poi: poi,
      customPoi: customPoi,
      includeCountry: true,
      includePlaceId: true,
    );
    final body = await _client.put(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId/poi-id',
      body: {...payload, 'entryPoisVersion': ?entryPoisVersion},
    );
    final map = body as Map<String, dynamic>;
    return (map['poiId'] as num).toInt();
  }

  /// POST /trips/:id/entries/:eid/alternates（既有 poiId 或 find-or-create 變體;POI 分類欄用 `type`）。
  Future<void> addEntryAlternate({
    required String tripId,
    required int entryId,
    int? poiId,
    PoiSearchResult? poi,
    CustomEntryPoi? customPoi,
    String? entryPoisVersion,
  }) {
    final payload = _entryPoiPayload(
      poiId: poiId,
      poi: poi,
      customPoi: customPoi,
    );
    return _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId/alternates',
      body: {...payload, 'entryPoisVersion': ?entryPoisVersion},
    );
  }

  /// POST /trips/:id/entries/:eid/trip-pois（往既有 entry 加 POI;支援 per-POI 訂位欄位）。
  Future<({int id, int poiId, int sortOrder})> addEntryTripPoi({
    required String tripId,
    required int entryId,
    required String name,
    required String poiType,
    String? description,
    String? note,
    String? hours,
    double? rating,
    String? category,
    double? lat,
    double? lng,
    String? price,
    String? reservation,
    String? reservationUrl,
  }) async {
    final body = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId/trip-pois',
      body: {
        'name': name,
        'type': poiType,
        'description': ?description,
        'note': ?note,
        'hours': ?hours,
        'rating': ?rating,
        'category': ?category,
        'lat': ?lat,
        'lng': ?lng,
        'price': ?price,
        'reservation': ?reservation,
        'reservation_url': ?reservationUrl,
      },
    );
    final map = body as Map<String, dynamic>;
    return (
      id: (map['id'] as num).toInt(),
      poiId: (map['poi_id'] as num).toInt(),
      sortOrder: (map['sort_order'] as num).toInt(),
    );
  }

  static Map<String, dynamic> _entryPoiPayload({
    int? poiId,
    PoiSearchResult? poi,
    CustomEntryPoi? customPoi,
    bool includeCountry = false,
    bool includePlaceId = false,
  }) {
    final count = [
      poiId != null,
      poi != null,
      customPoi != null,
    ].where((v) => v).length;
    if (count != 1) {
      throw ArgumentError('Provide exactly one of poiId, poi, or customPoi');
    }
    if (poiId != null) return {'poiId': poiId};
    if (customPoi != null) {
      return {
        'name': customPoi.name,
        'lat': customPoi.lat,
        'lng': customPoi.lng,
        'type': customPoi.poiType,
        'category': customPoi.category ?? customPoi.poiType,
        'address': ?customPoi.address,
        'source': 'custom',
      };
    }
    return {
      'name': poi!.name,
      'lat': poi.lat,
      'lng': poi.lng,
      'type': mapGooglePrimaryTypeToPoiType(poi.category),
      'category': poi.category,
      'address': poi.address,
      'rating': poi.rating,
      if (includeCountry) 'country': poi.country,
      if (includePlaceId) 'place_id': poi.placeId,
      'source': 'search',
    };
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

  /// GET /account/notifications，讀取通知偏好。
  Future<AccountNotificationPreferences>
  fetchAccountNotificationPreferences() async {
    final responseBody = await _client.get('/account/notifications');
    final preferencesJson =
        (responseBody as Map<String, dynamic>)['preferences']
            as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return AccountNotificationPreferences.fromJson(preferencesJson);
  }

  /// PATCH /account/notifications，更新單一或多個通知偏好。
  Future<AccountNotificationPreferences> updateAccountNotificationPreferences({
    bool? tripUpdates,
    bool? invitations,
    bool? system,
  }) async {
    final body = <String, bool>{
      'tripUpdates': ?tripUpdates,
      'invitations': ?invitations,
      'system': ?system,
    };
    if (body.isEmpty) {
      throw ArgumentError.value(body, 'body', '至少提供一個通知設定欄位');
    }
    final responseBody = await _client.patch(
      '/account/notifications',
      body: body,
    );
    final preferencesJson =
        (responseBody as Map<String, dynamic>)['preferences']
            as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return AccountNotificationPreferences.fromJson(preferencesJson);
  }

  /// GET /account/sessions，列出目前帳號登入裝置。
  Future<AccountSessionsPage> fetchAccountSessions() async {
    final responseBody = await _client.get('/account/sessions');
    return AccountSessionsPage.fromJson(responseBody as Map<String, dynamic>);
  }

  /// DELETE /account/sessions，登出其他裝置並回傳撤銷數量。
  Future<int> revokeOtherAccountSessions() async {
    final responseBody = await _client.delete('/account/sessions');
    if (responseBody is Map<String, dynamic>) {
      return (responseBody['revoked'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  /// DELETE /account/sessions/:sid，登出指定裝置。
  Future<void> revokeAccountSession(String sid) {
    return _client.delete('/account/sessions/${Uri.encodeComponent(sid)}');
  }

  /// GET /account/connected-apps，列出目前帳號授權過的 OAuth app。
  Future<List<ConnectedApp>> fetchConnectedApps() async {
    final responseBody = await _client.get('/account/connected-apps');
    final appsJson =
        (responseBody as Map<String, dynamic>)['apps'] as List<dynamic>? ??
        const [];
    return appsJson
        .map(
          (appJson) => ConnectedApp.fromJson(appJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// DELETE /account/connected-apps/:clientId，撤銷 app access/refresh token。
  Future<void> revokeConnectedApp(String clientId) {
    return _client.delete(
      '/account/connected-apps/${Uri.encodeComponent(clientId)}',
    );
  }

  /// GET /dev/apps，列出目前帳號建立的 OAuth client apps。
  Future<List<DeveloperApp>> fetchDeveloperApps() async {
    final responseBody = await _client.get('/dev/apps');
    final appsJson =
        (responseBody as Map<String, dynamic>)['apps'] as List<dynamic>? ??
        const [];
    return appsJson
        .map(
          (appJson) => DeveloperApp.fromJson(appJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// GET /dev/apps/:clientId，讀取單一 OAuth client app。
  Future<DeveloperApp> fetchDeveloperApp(String clientId) async {
    final responseBody = await _client.get(
      '/dev/apps/${Uri.encodeComponent(clientId)}',
    );
    return DeveloperApp.fromJson(responseBody as Map<String, dynamic>);
  }

  /// POST /dev/apps，建立 OAuth client app。
  Future<CreatedDeveloperApp> createDeveloperApp({
    required String appName,
    String clientType = 'public',
    required List<String> redirectUris,
    List<String> allowedScopes = const ['openid', 'profile', 'email'],
    String? appDescription,
    String? homepageUrl,
  }) async {
    final responseBody = await _client.post(
      '/dev/apps',
      body: {
        'app_name': appName.trim(),
        'client_type': clientType == 'confidential' ? 'confidential' : 'public',
        'redirect_uris': redirectUris
            .map((uri) => uri.trim())
            .where((uri) => uri.isNotEmpty)
            .toList(),
        'allowed_scopes': allowedScopes
            .where(kDeveloperAllowedScopes.contains)
            .toList(),
        'app_description': _trimmedOrNull(appDescription),
        'homepage_url': _trimmedOrNull(homepageUrl),
      },
    );
    return CreatedDeveloperApp.fromJson(responseBody as Map<String, dynamic>);
  }

  /// PATCH /dev/apps/:clientId，更新 OAuth client app metadata。
  Future<DeveloperApp> updateDeveloperApp({
    required String clientId,
    String? appName,
    String? appDescription,
    bool clearAppDescription = false,
    String? appLogoUrl,
    bool clearAppLogoUrl = false,
    String? homepageUrl,
    bool clearHomepageUrl = false,
    List<String>? redirectUris,
    List<String>? allowedScopes,
  }) async {
    final body = <String, dynamic>{
      'app_name': ?_trimmedOrNull(appName),
      if (appDescription != null || clearAppDescription)
        'app_description': clearAppDescription
            ? null
            : _trimmedOrNull(appDescription),
      if (appLogoUrl != null || clearAppLogoUrl)
        'app_logo_url': clearAppLogoUrl ? null : _trimmedOrNull(appLogoUrl),
      if (homepageUrl != null || clearHomepageUrl)
        'homepage_url': clearHomepageUrl ? null : _trimmedOrNull(homepageUrl),
      if (redirectUris != null)
        'redirect_uris': redirectUris
            .map((uri) => uri.trim())
            .where((uri) => uri.isNotEmpty)
            .toList(),
      if (allowedScopes != null)
        'allowed_scopes': allowedScopes
            .where(kDeveloperAllowedScopes.contains)
            .toList(),
    };
    if (body.isEmpty) {
      throw ArgumentError.value(body, 'body', '至少提供一個應用更新欄位');
    }
    final responseBody = await _client.patch(
      '/dev/apps/${Uri.encodeComponent(clientId)}',
      body: body,
    );
    return DeveloperApp.fromJson(responseBody as Map<String, dynamic>);
  }

  /// DELETE /dev/apps/:clientId，soft-delete 為 suspended。
  Future<String> suspendDeveloperApp(String clientId) async {
    final responseBody = await _client.delete(
      '/dev/apps/${Uri.encodeComponent(clientId)}',
    );
    if (responseBody is Map<String, dynamic>) {
      return responseBody['suspended_client_id'] as String? ?? clientId;
    }
    return clientId;
  }

  /// GET /share/:token（公開分享頁,不需登入）。
  Future<PublicTripShare> fetchPublicTripShare(String token) async {
    final responseBody = await _client.get(
      '/share/${Uri.encodeComponent(token)}',
    );
    return PublicTripShare.fromJson(responseBody as Map<String, dynamic>);
  }

  /// POST /share/:token/clone，將公開行程複製到目前登入帳號。
  Future<String> clonePublicTripShare(String token) async {
    final responseBody = await _client.post(
      '/share/${Uri.encodeComponent(token)}/clone',
      body: <String, dynamic>{},
    );
    return (responseBody as Map<String, dynamic>)['tripId'] as String;
  }

  Future<List<Map<String, dynamic>>> _fetchOptionalRecordList(
    String path,
  ) async {
    try {
      return _asRecordList(await _client.get(path));
    } on Exception {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> _fetchOptionalMap(String path) async {
    try {
      return _copyJsonMap(await _client.get(path));
    } on Exception {
      return _emptyExportNotes();
    }
  }
}

Map<String, dynamic> _buildTripExportJson({
  required Map<String, dynamic> meta,
  required List<Map<String, dynamic>> days,
  required List<Map<String, dynamic>> segments,
  required Map<String, dynamic> notes,
}) {
  final entryIdToPosition = <int, int>{};
  var entryPosition = 0;
  final exportDays = days.map((day) {
    final dayCopy = Map<String, dynamic>.from(day);
    final timeline = _asRecordList(dayCopy['timeline']).map((entry) {
      final entryCopy = Map<String, dynamic>.from(entry);
      final id = _intOrNull(entryCopy['id']);
      if (id != null) {
        entryIdToPosition[id] = entryPosition;
      }
      entryCopy['entryPosition'] = entryPosition;
      entryPosition++;
      return entryCopy;
    }).toList();
    dayCopy['timeline'] = timeline;
    return dayCopy;
  }).toList();

  final exportSegments = <Map<String, dynamic>>[];
  for (final segment in segments) {
    final fromEntryPosition =
        entryIdToPosition[_intFromAnyKey(
          segment,
          'fromEntryId',
          'from_entry_id',
        )];
    final toEntryPosition =
        entryIdToPosition[_intFromAnyKey(segment, 'toEntryId', 'to_entry_id')];
    if (fromEntryPosition == null || toEntryPosition == null) continue;
    exportSegments.add({
      'fromEntryIdx': fromEntryPosition,
      'toEntryIdx': toEntryPosition,
      'mode': _stringOrNull(segment['mode']) ?? '',
      'submode': _stringOrNull(segment['submode']),
      'min': _numberOrNull(segment['min']),
      'distanceM': _numberFromAnyKey(segment, 'distanceM', 'distance_m'),
      'source': _stringOrNull(segment['source']),
      'noTravel':
          segment['noTravel'] == 1 ||
              segment['noTravel'] == true ||
              segment['no_travel'] == 1 ||
              segment['no_travel'] == true
          ? 1
          : null,
    });
  }

  return {
    'schemaVersion': 1,
    'meta': meta,
    'days': exportDays,
    'notes': notes,
    'segments': exportSegments,
  };
}

List<Map<String, dynamic>> _asRecordList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> _copyJsonMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic> _emptyExportNotes() {
  return {
    'flights': const <dynamic>[],
    'lodgings': const <dynamic>[],
    'reservations': const <dynamic>[],
    'pretripNotes': const <dynamic>[],
    'emergencyContacts': const <dynamic>[],
  };
}

String _tripExportFileBase(
  Map<String, dynamic> meta,
  String fallbackTripId,
  DateTime now,
) {
  final rawName = _stringOrNull(meta['name']) ?? fallbackTripId;
  return _safeFileBase('$rawName-${_datePart(now)}');
}

String _safeFileBase(String raw) {
  final stripped = raw.replaceAll(RegExp(r'[\\/\x00-\x1F<>:"|?*]'), '_').trim();
  if (stripped.isEmpty) return 'trip';
  return stripped.length > 80 ? stripped.substring(0, 80) : stripped;
}

String _datePart(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String? _stringOrNull(Object? value) => value is String ? value : null;

int? _intFromAnyKey(Map<String, dynamic> json, String key, String fallbackKey) {
  return _intOrNull(json[key]) ?? _intOrNull(json[fallbackKey]);
}

num? _numberFromAnyKey(
  Map<String, dynamic> json,
  String key,
  String fallbackKey,
) {
  return _numberOrNull(json[key]) ?? _numberOrNull(json[fallbackKey]);
}

int? _intOrNull(Object? value) => (value as num?)?.toInt();

num? _numberOrNull(Object? value) => value is num ? value : null;

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
