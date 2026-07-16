import 'package:dio/dio.dart';

import '../models/trip_route.dart';
import 'api_client.dart';
import 'api_error.dart';

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
    // 裸 cast 會在空／非物件 body 丟 TypeError（是 Error 不是 Exception），
    // 呼叫端攔不到。統一收斂成 ApiError 讓錯誤路徑可預期。
    if (responseBody is! Map<String, dynamic>) {
      throw const ApiError(
        status: 200,
        code: 'ROUTE_INVALID_BODY',
        message: '路線服務回應格式異常',
      );
    }
    return TripRouteResult.fromJson(responseBody);
  }
}

String _coord({required double lng, required double lat}) => '$lng,$lat';
