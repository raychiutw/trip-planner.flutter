import 'package:dio/dio.dart';

import '../models/trip_route.dart';
import 'api_client.dart';

class MapRepository {
  MapRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /route?from=lng,lat&to=lng,lat -> decoded route geometry.
  Future<TripRouteResult> fetchRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    CancelToken? cancelToken,
  }) async {
    final responseBody = await _client.get(
      '/route',
      query: {
        'from': _coord(lng: fromLng, lat: fromLat),
        'to': _coord(lng: toLng, lat: toLat),
      },
      cancelToken: cancelToken,
    );
    return TripRouteResult.fromJson(responseBody as Map<String, dynamic>);
  }
}

String _coord({required double lng, required double lat}) => '$lng,$lat';
