/// 行程資料 repository：my-trips / trips / days / notes / stats / profile。
library;

import '../models/day.dart';
import '../models/notes.dart';
import '../models/segment.dart';
import '../models/trip.dart';
import '../models/user.dart';
import 'api_client.dart';

/// 對應 `/api/my-trips`、`/api/trips/*`、`/api/account/*`。
class TripRepository {
  TripRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /my-trips。
  Future<List<TripSummary>> fetchMyTrips() async {
    final responseBody = await _client.get('/my-trips');
    return (responseBody as List<dynamic>)
        .map((tripJson) =>
            TripSummary.fromJson(tripJson as Map<String, dynamic>))
        .toList();
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
    final responseBody =
        await _client.get('/trips/${Uri.encodeComponent(id)}');
    return Trip.fromJson(responseBody as Map<String, dynamic>);
  }

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

  /// GET /trips/:id/notes（5 區聚合）。
  Future<TripNotes> fetchNotes(String id) async {
    final responseBody =
        await _client.get('/trips/${Uri.encodeComponent(id)}/notes');
    return TripNotes.fromJson(responseBody as Map<String, dynamic>);
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
    return _client.post(
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
    return _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId',
      body: {
        'title': title,
        'description': description,
        'start_time': startTime,
        'end_time': endTime,
        'expectedVersion': expectedVersion,
      },
    );
  }

  /// DELETE /trips/:id/entries/:eid（後端回 200 {ok:true},忽略 body）。
  Future<void> deleteEntry({required String tripId, required int entryId}) {
    return _client.delete(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId',
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
            {
              'id': u.id,
              'sort_order': u.sortOrder,
              if (u.dayId != null) 'day_id': u.dayId,
            },
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
    final body =
        await _client.get('/trips/${Uri.encodeComponent(tripId)}/segments');
    return (body as List<dynamic>)
        .map((e) => TripSegment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

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
      body: {
        'mode': mode,
        if (min != null) 'min': min,
        if (expectedVersion != null) 'expectedVersion': expectedVersion,
      },
    );
    return TripSegment.fromJson(body as Map<String, dynamic>);
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
