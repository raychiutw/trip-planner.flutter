/// 行程資料 repository：my-trips / trips / days / notes / stats / profile。
library;

import '../models/day.dart';
import '../models/entry.dart';
import '../models/chat.dart';
import '../models/collab.dart';
import '../models/health.dart';
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

  /// GET /trips/:id/health-check，讀取最新 AI 健檢報告。
  Future<TripHealthReport?> fetchTripHealthReport(String tripId) async {
    final responseBody = await _client.get(
      '/trips/${Uri.encodeComponent(tripId)}/health-check',
    );
    final reportJson = (responseBody as Map<String, dynamic>)['report'];
    if (reportJson == null) return null;
    return TripHealthReport.fromJson(reportJson as Map<String, dynamic>);
  }

  /// POST /trips/:id/health-check，觸發新一輪 AI 健檢。
  Future<TripHealthReport> startTripHealthCheck(String tripId) async {
    final responseBody = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/health-check',
      body: <String, dynamic>{},
    );
    final reportJson = (responseBody as Map<String, dynamic>)['report'];
    if (reportJson is! Map<String, dynamic>) {
      throw StateError('health-check response missing report');
    }
    return TripHealthReport.fromJson(reportJson);
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

  /// PATCH /permissions/:id，更新既有成員角色（member ↔ viewer）。
  Future<PermissionRoleUpdateResult> updateTripPermissionRole({
    required int permissionId,
    required String role,
  }) async {
    final responseBody = await _client.patch(
      '/permissions/${Uri.encodeComponent('$permissionId')}',
      body: {'role': role == 'viewer' ? 'viewer' : 'member'},
    );
    return PermissionRoleUpdateResult.fromJson(
      responseBody as Map<String, dynamic>,
    );
  }

  /// DELETE /permissions/:id，移除既有非 owner 成員權限。
  Future<void> deleteTripPermission(int permissionId) {
    return _client.delete(
      '/permissions/${Uri.encodeComponent('$permissionId')}',
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

  /// POST /trips/:id/notes/flights，新增航班筆記 row。
  Future<TripFlight> createTripFlight({
    required String tripId,
    String? airline,
    String? flightNo,
    String? cabinClass,
    String? departAirport,
    String? arriveAirport,
    String? departAt,
    String? arriveAt,
    String? note,
  }) {
    return _createNoteRow(
      tripId: tripId,
      section: TripNoteSection.flights,
      body: {
        'airline': ?airline?.trim(),
        'flight_no': ?flightNo?.trim(),
        'cabin_class': ?cabinClass?.trim(),
        'depart_airport': ?departAirport?.trim(),
        'arrive_airport': ?arriveAirport?.trim(),
        'depart_at': ?departAt?.trim(),
        'arrive_at': ?arriveAt?.trim(),
        'note': ?note?.trim(),
      },
      fromJson: TripFlight.fromJson,
    );
  }

  /// PATCH /trips/:id/notes/flights/:rowId，更新航班並帶 OCC。
  Future<TripFlight> updateTripFlight({
    required String tripId,
    required int rowId,
    required int expectedVersion,
    String? airline,
    String? flightNo,
    String? cabinClass,
    String? departAirport,
    String? arriveAirport,
    String? departAt,
    String? arriveAt,
    String? note,
  }) {
    return _updateNoteRow(
      tripId: tripId,
      section: TripNoteSection.flights,
      rowId: rowId,
      expectedVersion: expectedVersion,
      body: {
        'airline': ?airline?.trim(),
        'flight_no': ?flightNo?.trim(),
        'cabin_class': ?cabinClass?.trim(),
        'depart_airport': ?departAirport?.trim(),
        'arrive_airport': ?arriveAirport?.trim(),
        'depart_at': ?departAt?.trim(),
        'arrive_at': ?arriveAt?.trim(),
        'note': ?note?.trim(),
      },
      fromJson: TripFlight.fromJson,
    );
  }

  /// POST /trips/:id/notes/lodgings，新增住宿筆記 row。
  Future<TripLodging> createTripLodging({
    required String tripId,
    String? name,
    String? address,
    String? checkInAt,
    String? checkOutAt,
    String? bookingNo,
    String? phone,
    String? note,
  }) {
    return _createNoteRow(
      tripId: tripId,
      section: TripNoteSection.lodgings,
      body: {
        'name': ?name?.trim(),
        'address': ?address?.trim(),
        'check_in_at': ?checkInAt?.trim(),
        'check_out_at': ?checkOutAt?.trim(),
        'booking_no': ?bookingNo?.trim(),
        'phone': ?phone?.trim(),
        'note': ?note?.trim(),
      },
      fromJson: TripLodging.fromJson,
    );
  }

  /// PATCH /trips/:id/notes/lodgings/:rowId，更新住宿並帶 OCC。
  Future<TripLodging> updateTripLodging({
    required String tripId,
    required int rowId,
    required int expectedVersion,
    String? name,
    String? address,
    String? checkInAt,
    String? checkOutAt,
    String? bookingNo,
    String? phone,
    String? note,
  }) {
    return _updateNoteRow(
      tripId: tripId,
      section: TripNoteSection.lodgings,
      rowId: rowId,
      expectedVersion: expectedVersion,
      body: {
        'name': ?name?.trim(),
        'address': ?address?.trim(),
        'check_in_at': ?checkInAt?.trim(),
        'check_out_at': ?checkOutAt?.trim(),
        'booking_no': ?bookingNo?.trim(),
        'phone': ?phone?.trim(),
        'note': ?note?.trim(),
      },
      fromJson: TripLodging.fromJson,
    );
  }

  /// POST /trips/:id/notes/reservations，新增預訂筆記 row。
  Future<TripReservation> createTripReservation({
    required String tripId,
    String? kind,
    String? title,
    String? reservedAt,
    int? partySize,
    String? reservationNo,
    String? phone,
    String? note,
  }) {
    return _createNoteRow(
      tripId: tripId,
      section: TripNoteSection.reservations,
      body: {
        'kind': ?kind?.trim(),
        'title': ?title?.trim(),
        'reserved_at': ?reservedAt?.trim(),
        'party_size': ?partySize,
        'reservation_no': ?reservationNo?.trim(),
        'phone': ?phone?.trim(),
        'note': ?note?.trim(),
      },
      fromJson: TripReservation.fromJson,
    );
  }

  /// PATCH /trips/:id/notes/reservations/:rowId，更新預訂並帶 OCC。
  Future<TripReservation> updateTripReservation({
    required String tripId,
    required int rowId,
    required int expectedVersion,
    String? kind,
    String? title,
    String? reservedAt,
    int? partySize,
    String? reservationNo,
    String? phone,
    String? note,
  }) {
    return _updateNoteRow(
      tripId: tripId,
      section: TripNoteSection.reservations,
      rowId: rowId,
      expectedVersion: expectedVersion,
      body: {
        'kind': ?kind?.trim(),
        'title': ?title?.trim(),
        'reserved_at': ?reservedAt?.trim(),
        'party_size': ?partySize,
        'reservation_no': ?reservationNo?.trim(),
        'phone': ?phone?.trim(),
        'note': ?note?.trim(),
      },
      fromJson: TripReservation.fromJson,
    );
  }

  /// POST /trips/:id/notes/pretrip，新增行前須知 row。
  Future<TripPretripNote> createTripPretripNote({
    required String tripId,
    String? section,
    String? title,
    String? content,
  }) {
    return _createNoteRow(
      tripId: tripId,
      section: TripNoteSection.pretrip,
      body: {
        'section': ?section?.trim(),
        'title': ?title?.trim(),
        'content': ?content?.trim(),
      },
      fromJson: TripPretripNote.fromJson,
    );
  }

  /// PATCH /trips/:id/notes/pretrip/:rowId，更新行前須知並帶 OCC。
  Future<TripPretripNote> updateTripPretripNote({
    required String tripId,
    required int rowId,
    required int expectedVersion,
    String? section,
    String? title,
    String? content,
  }) {
    return _updateNoteRow(
      tripId: tripId,
      section: TripNoteSection.pretrip,
      rowId: rowId,
      expectedVersion: expectedVersion,
      body: {
        'section': ?section?.trim(),
        'title': ?title?.trim(),
        'content': ?content?.trim(),
      },
      fromJson: TripPretripNote.fromJson,
    );
  }

  /// POST /trips/:id/notes/emergency，新增緊急聯絡 row。
  Future<TripEmergencyContact> createTripEmergencyContact({
    required String tripId,
    String? name,
    String? relationship,
    String? phone,
    String? email,
    String? kind,
  }) {
    return _createNoteRow(
      tripId: tripId,
      section: TripNoteSection.emergency,
      body: {
        'name': ?name?.trim(),
        'relationship': ?relationship?.trim(),
        'phone': ?phone?.trim(),
        'email': ?email?.trim(),
        'kind': ?kind?.trim(),
      },
      fromJson: TripEmergencyContact.fromJson,
    );
  }

  /// PATCH /trips/:id/notes/emergency/:rowId，更新緊急聯絡並帶 OCC。
  Future<TripEmergencyContact> updateTripEmergencyContact({
    required String tripId,
    required int rowId,
    required int expectedVersion,
    String? name,
    String? relationship,
    String? phone,
    String? email,
    String? kind,
  }) {
    return _updateNoteRow(
      tripId: tripId,
      section: TripNoteSection.emergency,
      rowId: rowId,
      expectedVersion: expectedVersion,
      body: {
        'name': ?name?.trim(),
        'relationship': ?relationship?.trim(),
        'phone': ?phone?.trim(),
        'email': ?email?.trim(),
        'kind': ?kind?.trim(),
      },
      fromJson: TripEmergencyContact.fromJson,
    );
  }

  /// DELETE /trips/:id/notes/:section/:rowId。
  Future<void> deleteTripNoteRow({
    required String tripId,
    required TripNoteSection section,
    required int rowId,
  }) {
    return _client.delete(
      '${_noteSectionPath(tripId, section)}/${Uri.encodeComponent('$rowId')}',
    );
  }

  /// POST /trips/:id/notes/:docType/generate，觸發 AI 生成筆記。
  Future<TripNoteAiGenerationJob> generateTripNotes({
    required String tripId,
    required String docType,
  }) async {
    final responseBody = await _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/notes/${Uri.encodeComponent(docType)}/generate',
      body: <String, dynamic>{},
    );
    return TripNoteAiGenerationJob.fromJson(
      responseBody as Map<String, dynamic>,
    );
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

  String _noteSectionPath(String tripId, TripNoteSection section) {
    return '/trips/${Uri.encodeComponent(tripId)}/notes/${section.pathSegment}';
  }

  Future<T> _createNoteRow<T>({
    required String tripId,
    required TripNoteSection section,
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    final responseBody = await _client.post(
      _noteSectionPath(tripId, section),
      body: body,
    );
    return fromJson(responseBody as Map<String, dynamic>);
  }

  Future<T> _updateNoteRow<T>({
    required String tripId,
    required TripNoteSection section,
    required int rowId,
    required int expectedVersion,
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    final responseBody = await _client.patch(
      '${_noteSectionPath(tripId, section)}/${Uri.encodeComponent('$rowId')}',
      body: {...body, 'expectedVersion': expectedVersion},
    );
    return fromJson(responseBody as Map<String, dynamic>);
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
