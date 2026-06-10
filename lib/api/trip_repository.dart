/// 行程資料 repository：my-trips / trips / days / notes / stats / profile。
library;

import '../models/day.dart';
import '../models/notes.dart';
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
