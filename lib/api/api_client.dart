/// dio 封裝：cookie 認證、CSRF Origin、錯誤轉換、429 retry、204 處理。
library;

import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';

import 'api_error.dart';
import 'cache/cache_keys.dart';
import 'cache/cache_store.dart';
import 'session_store.dart';

/// 本 build 連線的 origin。預設正式站，可用 --dart-define=TRIPLINE_API_ORIGIN
/// 覆寫（本機開發指向本機後端）。一個 origin 同時決定 base URL（`origin/api`）
/// 與 mutating request 的 CSRF Origin header。
const String kTriplineOrigin = String.fromEnvironment(
  'TRIPLINE_API_ORIGIN',
  defaultValue: 'https://trip-planner-dby.pages.dev',
);

/// 提供 Bearer access token 與 refresh 能力(OAuth 模式)。
/// 注入 ApiClient 後,有 token 即走 Bearer(不送 Cookie/Origin);null/無 token → cookie 模式。
abstract class BearerTokenSource {
  Future<String?> accessToken();

  /// 嘗試用 refresh token 換新 access token;成功(有新 token 可用)回 true。
  Future<bool> refresh();
}

/// Tripline API client，base = `<origin>/api`。
class ApiClient {
  ApiClient({
    required SessionStore sessionStore,
    Dio? dio,
    String origin = kTriplineOrigin,
    BearerTokenSource? bearerSource,
    CacheStore? cacheStore,
  }) : _sessionStore = sessionStore,
       _origin = origin,
       _bearerSource = bearerSource,
       _cacheStore = cacheStore,
       _dio = dio ?? Dio() {
    _dio.options.baseUrl = '$origin/api';
    // 全收所有 status code，由 _send 自行判斷丟 ApiError
    _dio.options.validateStatus = (_) => true;
  }

  final SessionStore _sessionStore;
  final String _origin;
  final BearerTokenSource? _bearerSource;
  final CacheStore? _cacheStore;
  final Dio _dio;

  /// 供 AuthRepository 直接讀 response headers（set-cookie）用。
  Dio get dio => _dio;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _send('GET', path, query: query, cancelToken: cancelToken);

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Map<String, dynamic>? query}) =>
      _send('DELETE', path, query: query);

  /// SWR 讀取:先 emit 本機快取(stale,若有),再 emit `get()`(fresh / 離線回退 / 或 throw)。
  /// 重用 get() 的 auth / 429 retry / write-through / 離線回退邏輯,故無需額外 try/catch:
  /// 線上 HTTP 錯誤與「無快取離線」都會讓 stream 自然 emit error。
  Stream<dynamic> getStream(String path, {Map<String, dynamic>? query}) async* {
    final store = _cacheStore;
    if (store != null) {
      final cached = await store.readResponse(cacheKeyFor('GET', path, query));
      if (cached != null) yield cached.data;
    }
    yield await get(path, query: query);
  }

  /// 解析 Retry-After（delta-seconds 或 HTTP-date），cap 30 秒；無效值回 1。
  static int parseRetryAfterSeconds(String? headerValue) {
    const maxWaitSeconds = 30;
    const defaultWaitSeconds = 1;
    final trimmedValue = headerValue?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return defaultWaitSeconds;
    }
    final deltaSeconds = int.tryParse(trimmedValue);
    if (deltaSeconds != null) {
      return deltaSeconds.clamp(0, maxWaitSeconds).toInt();
    }
    try {
      final retryAt = HttpDate.parse(trimmedValue);
      final secondsUntilRetry = retryAt.difference(DateTime.now()).inSeconds;
      return secondsUntilRetry.clamp(0, maxWaitSeconds).toInt();
    } on Exception {
      return defaultWaitSeconds;
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    CancelToken? cancelToken,
    bool isRetryAttempt = false,
  }) async {
    final requestHeaders = <String, dynamic>{};
    final bearer = await _bearerSource?.accessToken();
    final useBearer = bearer != null && bearer.isNotEmpty;
    if (useBearer) {
      // Bearer 模式:帶 token,不送 Cookie/Origin
      //（後端對「有 Bearer 且無 Origin」的 request 跳過 CSRF 檢查）。
      requestHeaders['Authorization'] = 'Bearer $bearer';
    } else {
      final sessionToken = await _sessionStore.read();
      if (sessionToken != null && sessionToken.isNotEmpty) {
        requestHeaders['Cookie'] = 'tripline_session=$sessionToken';
      }
      final isMutation = method != 'GET' && method != 'HEAD';
      if (isMutation) {
        // cookie 認證的 mutating request 必帶 Origin（後端 CSRF 檢查）
        requestHeaders['Origin'] = _origin;
      }
    }

    final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        queryParameters: query,
        data: body,
        options: Options(method: method, headers: requestHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      // 連線層失敗(離線/逾時):GET 嘗試回退本機快取
      final store = _cacheStore;
      if (method == 'GET' && store != null && _isOfflineError(e)) {
        final cached = await store.readResponse(
          cacheKeyFor('GET', path, query),
        );
        if (cached != null) return cached.data;
      }
      rethrow;
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 429 && method == 'GET' && !isRetryAttempt) {
      final waitSeconds = parseRetryAfterSeconds(
        response.headers.value('retry-after'),
      );
      await Future<void>.delayed(Duration(seconds: waitSeconds));
      return _send(
        method,
        path,
        query: query,
        body: body,
        cancelToken: cancelToken,
        isRetryAttempt: true,
      );
    }
    // Bearer 模式遇 401 → 嘗試 refresh 後重試一次
    if (statusCode == 401 &&
        useBearer &&
        !isRetryAttempt &&
        _bearerSource != null &&
        await _bearerSource.refresh()) {
      return _send(
        method,
        path,
        query: query,
        body: body,
        cancelToken: cancelToken,
        isRetryAttempt: true,
      );
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiError.fromResponse(statusCode, response.data);
    }
    if (statusCode == 204) {
      await _evictForMutation(method, path, body);
      return null;
    }
    final responseData = response.data;
    final isEmpty =
        responseData == null ||
        (responseData is String && responseData.isEmpty);
    if (method == 'GET') {
      if (!isEmpty && _isCacheableGet(path)) {
        await _cacheStore?.writeResponse(
          cacheKeyFor('GET', path, query),
          responseData,
        );
      }
    } else {
      await _evictForMutation(method, path, body);
    }
    return isEmpty ? null : responseData;
  }

  /// /poi-search 為離線非目標,且每個 query 是不同 key、無人 evict → 跳過快取避免無限增長。
  bool _isCacheableGet(String path) => !path.startsWith('/poi-search');

  /// 連線層錯誤(離線/逾時/無回應)→ 可回退快取;HTTP 4xx/5xx 不算(server 有回)。
  bool _isOfflineError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      default:
        return e.type == DioExceptionType.unknown && e.response == null;
    }
  }

  /// mutation 成功後,依失效表移除受影響的 GET 快取(body 供 add-to-trip 取 tripId)。
  Future<void> _evictForMutation(
    String method,
    String path,
    Object? body,
  ) async {
    final store = _cacheStore;
    if (store == null) return;
    for (final prefix in evictionPrefixesFor(method, path, body)) {
      await store.evictByPrefix(prefix);
    }
  }
}
