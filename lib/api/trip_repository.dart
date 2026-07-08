/// 行程資料 repository：my-trips / trips / days / notes / stats / profile。
library;

import '../models/day.dart';
import '../models/entry.dart';
import '../models/chat.dart';
import '../models/collab.dart';
import '../models/notes.dart';
import '../models/poi.dart';
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
        .map(
          (tripJson) => TripSummary.fromJson(tripJson as Map<String, dynamic>),
        )
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
    final responseBody = await _client.get('/trips/${Uri.encodeComponent(id)}');
    return Trip.fromJson(responseBody as Map<String, dynamic>);
  }

  /// GET /permissions?tripId=...，讀取行程成員與角色。
  Future<List<TripPermission>> fetchTripPermissions(String tripId) async {
    final responseBody = await _client.get(
      '/permissions',
      query: {'tripId': tripId},
    );
    return (responseBody as List<dynamic>)
        .map(
          (permissionJson) =>
              TripPermission.fromJson(permissionJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// GET /invitations?tripId=...，讀取待接受邀請。
  Future<PendingInvitationPage> fetchPendingInvitations(String tripId) async {
    final responseBody = await _client.get(
      '/invitations',
      query: {'tripId': tripId},
    );
    if (responseBody is List<dynamic>) {
      return PendingInvitationPage(
        items: responseBody
            .map(
              (itemJson) =>
                  PendingInvitation.fromJson(itemJson as Map<String, dynamic>),
            )
            .toList(),
      );
    }
    return PendingInvitationPage.fromJson(responseBody as Map<String, dynamic>);
  }

  /// POST /permissions，新增既有成員權限或寄出 pending invitation。
  Future<PermissionInviteResult> createTripPermissionInvite({
    required String tripId,
    required String email,
    String role = 'member',
  }) async {
    final responseBody = await _client.post(
      '/permissions',
      body: {
        'tripId': tripId,
        'email': email.trim().toLowerCase(),
        'role': role == 'viewer' ? 'viewer' : 'member',
      },
    );
    return PermissionInviteResult.fromJson(
      responseBody as Map<String, dynamic>,
    );
  }

  /// POST /invitations/revoke，撤回指定 email 的 pending invitation。
  Future<void> revokeTripInvitation({
    required String tripId,
    required String email,
  }) {
    return _client.post(
      '/invitations/revoke',
      body: {'tripId': tripId, 'email': email.trim().toLowerCase()},
    );
  }

  /// GET /invitations?token=...，公開邀請預覽。
  Future<InvitationPreview> fetchInvitation(String token) async {
    final responseBody = await _client.get(
      '/invitations',
      query: {'token': token},
    );
    return InvitationPreview.fromJson(responseBody as Map<String, dynamic>);
  }

  /// POST /invitations/accept，接受登入使用者 email 相符的邀請。
  Future<InvitationAcceptResult> acceptInvitation(String token) async {
    final responseBody = await _client.post(
      '/invitations/accept',
      body: {'token': token},
    );
    return InvitationAcceptResult.fromJson(
      responseBody as Map<String, dynamic>,
    );
  }

  /// GET /requests?tripId=...，讀取 AI request queue。
  Future<TripRequestPage> fetchTripRequests({
    required String tripId,
    int limit = 5,
    String sort = 'desc',
    String? before,
    int? beforeId,
  }) async {
    final responseBody = await _client.get(
      '/requests',
      query: {
        'tripId': tripId,
        'limit': '$limit',
        'sort': sort == 'asc' ? 'asc' : 'desc',
        if (before != null && before.isNotEmpty) 'before': before,
        if (beforeId != null) 'beforeId': '$beforeId',
      },
    );
    if (responseBody is List<dynamic>) {
      return TripRequestPage(
        items: responseBody
            .map(
              (itemJson) =>
                  TripRequest.fromJson(itemJson as Map<String, dynamic>),
            )
            .toList(),
        hasMore: false,
      );
    }
    return TripRequestPage.fromJson(responseBody as Map<String, dynamic>);
  }

  /// POST /requests，建立 AI request。
  Future<TripRequest> createTripRequest({
    required String tripId,
    required String message,
  }) async {
    final responseBody = await _client.post(
      '/requests',
      body: {'tripId': tripId, 'message': message.trim()},
    );
    return TripRequest.fromJson(responseBody as Map<String, dynamic>);
  }

  /// GET /requests/:id，取得 request 最新狀態與 reply。
  Future<TripRequest> fetchTripRequest(int id) async {
    final responseBody = await _client.get(
      '/requests/${Uri.encodeComponent('$id')}',
    );
    return TripRequest.fromJson(responseBody as Map<String, dynamic>);
  }

  /// POST /trips，建立行程、days、owner permission 與文件 stub。
  Future<String> createTrip({
    required String id,
    required String name,
    required String? title,
    required String? description,
    required String startDate,
    required String endDate,
    String countries = 'JP',
    bool published = true,
    String lang = 'zh-TW',
    List<TripDestinationInput> destinations = const [],
  }) async {
    final responseBody = await _client.post(
      '/trips',
      body: {
        'id': id.trim(),
        'name': name.trim(),
        'startDate': startDate.trim(),
        'endDate': endDate.trim(),
        'title': ?_trimmedOrNull(title),
        'description': ?_trimmedOrNull(description),
        'countries': countries.trim().isEmpty ? 'JP' : countries.trim(),
        'published': published ? 1 : 0,
        'lang': lang,
        'data_source': 'manual',
        'destinations': _destinationPayload(destinations),
      },
    );
    return (responseBody as Map<String, dynamic>)['tripId'] as String;
  }

  /// PUT /trips/:id，更新 scalar 欄位並用 full-replacement 寫 destinations。
  Future<void> updateTrip({
    required String id,
    required String? title,
    required String? description,
    required bool published,
    required String lang,
    required List<TripDestinationInput> destinations,
  }) {
    return _client.put(
      '/trips/${Uri.encodeComponent(id)}',
      body: {
        'title': _trimmedOrNull(title),
        'description': _trimmedOrNull(description),
        'published': published ? 1 : 0,
        'lang': lang,
        'destinations': _destinationPayload(destinations),
      },
    );
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

  /// GET /trips/:id/entries/:entryId。
  Future<TimelineEntry> fetchEntry(String tripId, int entryId) async {
    final responseBody = await _client.get(
      '/trips/${Uri.encodeComponent(tripId)}/entries/${Uri.encodeComponent('$entryId')}',
    );
    return TimelineEntry.fromJson(responseBody as Map<String, dynamic>);
  }

  /// PATCH /trips/:id/entries/:entryId（OCC：expectedVersion 必帶）。
  Future<TimelineEntry> updateEntry(
    String tripId,
    int entryId, {
    required int expectedVersion,
    required String? startTime,
    required String? endTime,
    required String? description,
  }) async {
    final responseBody = await _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/entries/${Uri.encodeComponent('$entryId')}',
      body: {
        'start_time': startTime,
        'end_time': endTime,
        'description': description,
        'expectedVersion': expectedVersion,
      },
    );
    return TimelineEntry.fromJson(responseBody as Map<String, dynamic>);
  }

  /// DELETE /trips/:id/entries/:entryId。
  Future<void> deleteEntry(String tripId, int entryId) {
    return _client.delete(
      '/trips/${Uri.encodeComponent(tripId)}/entries/${Uri.encodeComponent('$entryId')}',
    );
  }

  /// POST /trips/:id/entries/:entryId/copy。
  Future<TimelineEntry> copyEntry({
    required String tripId,
    required int entryId,
    required int targetDayId,
  }) async {
    final responseBody = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/entries/${Uri.encodeComponent('$entryId')}/copy',
      body: {'targetDayId': targetDayId},
    );
    return TimelineEntry.fromJson(responseBody as Map<String, dynamic>);
  }

  /// PATCH /trips/:id/entries/:entryId，用 `day_id` 跨日移動 entry。
  Future<TimelineEntry> moveEntry({
    required String tripId,
    required int entryId,
    required int targetDayId,
    required int expectedVersion,
  }) async {
    final responseBody = await _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/entries/${Uri.encodeComponent('$entryId')}',
      body: {'day_id': targetDayId, 'expectedVersion': expectedVersion},
    );
    return TimelineEntry.fromJson(responseBody as Map<String, dynamic>);
  }

  /// PUT /trips/:id/entries/:entryId/poi-id，用搜尋結果置換 master POI。
  Future<void> replaceEntryMasterPoiFromSearchResult({
    required String tripId,
    required int entryId,
    required PoiSearchResult poi,
    required String? entryPoisVersion,
  }) {
    return _client.put(
      '/trips/${Uri.encodeComponent(tripId)}/entries/${Uri.encodeComponent('$entryId')}/poi-id',
      body: _poiSearchMutationBody(poi, entryPoisVersion: entryPoisVersion),
    );
  }

  /// PUT /trips/:id/entries/:entryId/poi-id，用既有 POI id 置換 master POI。
  Future<void> replaceEntryMasterPoiWithPoiId({
    required String tripId,
    required int entryId,
    required int poiId,
    required String? entryPoisVersion,
  }) {
    return _client.put(
      '/trips/${Uri.encodeComponent(tripId)}/entries/${Uri.encodeComponent('$entryId')}/poi-id',
      body: {'poiId': poiId, 'entryPoisVersion': ?entryPoisVersion},
    );
  }

  /// POST /trips/:id/entries/:entryId/alternates，用搜尋結果加入備選 POI。
  Future<EntryPoisMutationResult> addEntryAlternateFromSearchResult({
    required String tripId,
    required int entryId,
    required PoiSearchResult poi,
    required String? entryPoisVersion,
  }) async {
    final responseBody = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/entries/${Uri.encodeComponent('$entryId')}/alternates',
      body: _poiSearchMutationBody(poi, entryPoisVersion: entryPoisVersion),
    );
    return EntryPoisMutationResult.fromJson(
      responseBody as Map<String, dynamic>,
    );
  }

  /// POST /trips/:id/entries/:entryId/alternates，用既有 POI id 加入備選 POI。
  Future<EntryPoisMutationResult> addEntryAlternateWithPoiId({
    required String tripId,
    required int entryId,
    required int poiId,
    required String? entryPoisVersion,
  }) async {
    final responseBody = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/entries/${Uri.encodeComponent('$entryId')}/alternates',
      body: {'poiId': poiId, 'entryPoisVersion': ?entryPoisVersion},
    );
    return EntryPoisMutationResult.fromJson(
      responseBody as Map<String, dynamic>,
    );
  }

  /// DELETE /trips/:id/entries/:entryId/alternates/:poiId。
  Future<EntryPoisMutationResult> deleteEntryAlternate({
    required String tripId,
    required int entryId,
    required int poiId,
    required String? entryPoisVersion,
  }) async {
    final responseBody = await _client.delete(
      _withOptionalQuery(
        '/trips/${Uri.encodeComponent(tripId)}/entries/${Uri.encodeComponent('$entryId')}/alternates/${Uri.encodeComponent('$poiId')}',
        {'entryPoisVersion': entryPoisVersion},
      ),
    );
    return EntryPoisMutationResult.fromJson(
      responseBody as Map<String, dynamic>,
    );
  }

  /// PATCH /trips/:id/entries/:entryId/alternates/reorder。
  Future<EntryAlternatesReorderResult> reorderEntryAlternates({
    required String tripId,
    required int entryId,
    required List<int> orderedPoiIds,
    required String? entryPoisVersion,
  }) async {
    final responseBody = await _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/entries/${Uri.encodeComponent('$entryId')}/alternates/reorder',
      body: {'order': orderedPoiIds, 'entryPoisVersion': ?entryPoisVersion},
    );
    return EntryAlternatesReorderResult.fromJson(
      responseBody as Map<String, dynamic>,
    );
  }

  /// GET /trips/:id/notes（5 區聚合）。
  Future<TripNotes> fetchNotes(String id) async {
    final responseBody = await _client.get(
      '/trips/${Uri.encodeComponent(id)}/notes',
    );
    return TripNotes.fromJson(responseBody as Map<String, dynamic>);
  }

  /// DELETE /trips/:id（限 owner/admin）。
  Future<void> deleteTrip(String id) =>
      _client.delete('/trips/${Uri.encodeComponent(id)}');

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

  /// GET /poi-favorites。
  Future<List<PoiFavorite>> fetchPoiFavorites() async {
    final responseBody = await _client.get('/poi-favorites');
    return (responseBody as List<dynamic>)
        .map(
          (favoriteJson) =>
              PoiFavorite.fromJson(favoriteJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// GET /poi-search?q=...&region=...&limit=...。
  Future<List<PoiSearchResult>> searchPois({
    required String query,
    String? region,
    int limit = 20,
  }) async {
    final trimmedQuery = query.trim();
    final trimmedRegion = region?.trim();
    final responseBody = await _client.get(
      '/poi-search',
      query: {
        'q': trimmedQuery,
        if (trimmedRegion != null && trimmedRegion.isNotEmpty)
          'region': trimmedRegion,
        'limit': '$limit',
      },
    );
    final results =
        (responseBody as Map<String, dynamic>)['results'] as List<dynamic>;
    return results
        .map(
          (resultJson) =>
              PoiSearchResult.fromJson(resultJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// POST /pois/find-or-create，回傳 POI table id。
  Future<int> findOrCreatePoi(PoiSearchResult poi) async {
    final responseBody = await _client.post(
      '/pois/find-or-create',
      body: {
        'name': poi.name,
        'type': mapPoiCategoryToType(poi.category),
        'lat': poi.lat,
        'lng': poi.lng,
        'address': poi.address ?? '',
        'category': poi.category ?? '',
        'source': 'user-explore',
        'country': poi.country,
        'place_id': poi.placeId,
      },
    );
    return ((responseBody as Map<String, dynamic>)['id'] as num).toInt();
  }

  /// POST /poi-favorites。
  Future<PoiFavorite> createPoiFavorite({
    required int poiId,
    String? note,
  }) async {
    final responseBody = await _client.post(
      '/poi-favorites',
      body: {'poiId': poiId, 'note': ?note},
    );
    return PoiFavorite.fromJson(responseBody as Map<String, dynamic>);
  }

  /// DELETE /poi-favorites/:id。
  Future<void> deletePoiFavorite(int id) =>
      _client.delete('/poi-favorites/${Uri.encodeComponent('$id')}');

  /// POST /poi-favorites/:id/add-to-trip。
  Future<PoiFavoriteAddToTripResult> addPoiFavoriteToTrip(
    int favoriteId, {
    required String tripId,
    required int dayNum,
    required String startTime,
    required String endTime,
  }) async {
    final responseBody = await _client.post(
      '/poi-favorites/${Uri.encodeComponent('$favoriteId')}/add-to-trip',
      body: {
        'tripId': tripId,
        'dayNum': dayNum,
        'startTime': startTime,
        'endTime': endTime,
      },
    );
    return PoiFavoriteAddToTripResult.fromJson(
      responseBody as Map<String, dynamic>,
    );
  }

  /// POST /trips/:id/days/:num/entries，用 Explore direct-mode POI 直建 entry。
  Future<void> createEntryFromPoiSearchResult({
    required String tripId,
    required int dayNum,
    required PoiSearchResult poi,
    required String startTime,
    required String endTime,
  }) {
    final time = startTime.trim().isNotEmpty && endTime.trim().isNotEmpty
        ? '${startTime.trim()}-${endTime.trim()}'
        : null;
    return _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/days/$dayNum/entries',
      body: {
        'name': poi.name,
        'note': ?poi.address,
        'lat': poi.lat,
        'lng': poi.lng,
        'source': 'google',
        'time': ?time,
        'poi_type': mapPoiCategoryToType(poi.category),
      },
    );
  }

  /// POST /trips/:id/days/:num/entries，用自訂地圖座標直建 entry。
  Future<void> createCustomEntry({
    required String tripId,
    required int dayNum,
    required String name,
    required String? note,
    required double lat,
    required double lng,
    required String poiType,
    required String startTime,
    required String endTime,
  }) {
    final time = startTime.trim().isNotEmpty && endTime.trim().isNotEmpty
        ? '${startTime.trim()}-${endTime.trim()}'
        : null;
    final trimmedNote = note?.trim();
    return _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/days/$dayNum/entries',
      body: {
        'name': name.trim(),
        'note': ?(trimmedNote == null || trimmedNote.isEmpty
            ? null
            : trimmedNote),
        'lat': lat,
        'lng': lng,
        'source': 'custom',
        'time': ?time,
        'poi_type': mapPoiCategoryToType(poiType),
      },
    );
  }

  /// POST /trips/:id/recompute-travel?day=N。
  Future<void> recomputeTravel(String tripId, {int? dayNum}) {
    return _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/recompute-travel',
      query: {if (dayNum != null) 'day': '$dayNum'},
    );
  }

  Map<String, dynamic> _poiSearchMutationBody(
    PoiSearchResult poi, {
    required String? entryPoisVersion,
  }) {
    return {
      'name': poi.name,
      'type': mapPoiCategoryToType(poi.category),
      'lat': poi.lat,
      'lng': poi.lng,
      'address': ?poi.address,
      'category': ?poi.category,
      'source': 'google',
      'country': ?poi.country,
      'place_id': poi.placeId,
      'entryPoisVersion': ?entryPoisVersion,
      'rating': ?poi.rating,
    };
  }

  String _withOptionalQuery(String path, Map<String, String?> query) {
    final entries = query.entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value!)}',
        )
        .toList();
    if (entries.isEmpty) return path;
    return '$path?${entries.join('&')}';
  }

  List<Map<String, dynamic>> _destinationPayload(
    List<TripDestinationInput> destinations,
  ) {
    return destinations
        .where((destination) => destination.name.trim().isNotEmpty)
        .map((destination) => destination.toJson())
        .toList();
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
