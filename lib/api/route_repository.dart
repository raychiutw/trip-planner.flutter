import '../models/route_result.dart';
import 'api_client.dart';
import 'api_error.dart';

/// 單段行車路線查詢(`GET /api/route`),供地圖畫真實道路折線。
class RouteRepository {
  RouteRepository({required this.client});

  final ApiClient client;

  /// 取兩點間道路折線。query 為 `from=lng,lat&to=lng,lat`(注意 lng 在前)。
  ///
  /// 失敗(502 `MAPS_UPSTREAM_FAILED` / 503 `MAPS_LOCKED`)→ 回 `null`;對齊 web:
  /// 隱藏該段折線,**不**退化成直線(Haversine)。GET 會走 ApiClient 透明快取。
  Future<RouteResult?> fetchRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final data = await client.get(
        '/route',
        query: {'from': '$fromLng,$fromLat', 'to': '$toLng,$toLat'},
      );
      if (data is! Map) return null;
      return RouteResult.fromJson(Map<String, dynamic>.from(data));
    } on ApiError {
      return null;
    }
  }
}
