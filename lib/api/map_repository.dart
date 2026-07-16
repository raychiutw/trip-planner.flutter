import 'package:dio/dio.dart';

import '../models/trip_route.dart';
import 'api_client.dart';
import 'api_error.dart';

class MapRepository {
  MapRepository({required ApiClient client, int cacheCapacity = 100})
    : _client = client,
      _cacheCapacity = cacheCapacity;

  final ApiClient _client;

  /// 後端 `/route` 限額 100 次／24 小時、超過鎖 1 小時（走付費 Google Routes
  /// API）。同一趟行程反覆開圖／切 tab 會重打同幾段，in-memory LRU 讓同 session
  /// 內不重複燒配額。對齊 web 的 IndexedDB 100 筆 LRU（web 另有跨 reload 持久化，
  /// app 端暫不做）。
  final int _cacheCapacity;
  final Map<String, TripRouteResult> _cache = {};

  /// GET /route?from=lng,lat&to=lng,lat -> decoded route geometry.
  Future<TripRouteResult> fetchRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    CancelToken? cancelToken,
  }) async {
    final key = _cacheKey(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
    );
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // 命中：搬到尾端維持 LRU 順序。
      return cached;
    }

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
    final result = TripRouteResult.fromJson(responseBody);
    // 只快取成功結果 —— 失敗（含上面 throw）不進 cache，下次仍會重試。
    _cache[key] = result;
    if (_cache.length > _cacheCapacity) {
      _cache.remove(_cache.keys.first); // 淘汰最久未用。
    }
    return result;
  }

  /// 座標四捨五入到 5 位（約 1 公尺）當 key，容忍浮點誤差、對齊 web cacheKey。
  String _cacheKey({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    String round(double value) => value.toStringAsFixed(5);
    return 'v1:${round(fromLat)},${round(fromLng)}->${round(toLat)},${round(toLng)}';
  }
}

String _coord({required double lng, required double lat}) => '$lng,$lat';
