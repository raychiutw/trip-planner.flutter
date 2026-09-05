/// dio 封裝：cookie 認證、CSRF Origin、錯誤轉換、暫時性失敗 retry、204 處理。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';

import 'api_error.dart';
import 'cache/cache_keys.dart';
import 'cache/cache_read_policy.dart';
import 'cache/cache_store.dart';
import 'cache/offline_op.dart';
import 'cache/offline_sync_engine.dart';
import 'session_store.dart';

export 'cache/offline_sync_engine.dart' show FlushResult;

/// 本 build 連線的 origin。預設正式站，可用 --dart-define=TRIPLINE_API_ORIGIN
/// 覆寫（本機開發指向本機後端）。一個 origin 同時決定 base URL（`origin/api`）
/// 與 mutating request 的 CSRF Origin header。
const String kTriplineOrigin = String.fromEnvironment(
  'TRIPLINE_API_ORIGIN',
  defaultValue: 'https://trip-planner-dby.pages.dev',
);

/// 高基數 GET 的永續快取容量上限（path prefix → 最多保留幾筆）。
///
/// 這兩條路徑每個 query 都是新 key，且沒有任何 mutation 會 evict 它們 —— 快取
/// 只增不減，沒有上限就會無界成長。其他路徑靠 `evictionPrefixesFor` 在 mutation
/// 後失效，天生有界，不需要上限。
///
/// 100 對齊 web 版 `useRoute.ts` 的 IndexedDB LRU 容量。
const Map<String, int> kCacheCapacityByPathPrefix = {
  '/poi-search': 100,
  '/route': 100,
};

/// Redirect-style API response where callers need the `Location` header.
class ApiRedirectResponse {
  const ApiRedirectResponse({required this.statusCode, required this.location});

  final int statusCode;
  final String? location;
}

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
    Map<String, int> cacheCapacityByPathPrefix = kCacheCapacityByPathPrefix,
  }) : _sessionStore = sessionStore,
       _origin = origin,
       _bearerSource = bearerSource,
       _cacheStore = cacheStore,
       _cacheCapacityByPathPrefix = cacheCapacityByPathPrefix,
       _dio = dio ?? Dio() {
    _dio.options.baseUrl = '$origin/api';
    // 全收所有 status code，由 _send 自行判斷丟 ApiError
    _dio.options.validateStatus = (_) => true;
  }

  final SessionStore _sessionStore;
  final String _origin;
  final BearerTokenSource? _bearerSource;
  final CacheStore? _cacheStore;
  final Map<String, int> _cacheCapacityByPathPrefix;
  final Dio _dio;

  /// 離線佇列引擎:只認 [_sendForOffline] 與 [CacheStore],沒有快取就沒有引擎。
  late final OfflineSyncEngine? _offline = _cacheStore == null
      ? null
      : OfflineSyncEngine(send: _sendForOffline, store: _cacheStore);

  Future<Object?> _sendForOffline(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CacheReadPolicy policy = CacheReadPolicy.cached,
    bool evictMutationCache = true,
  }) => _send(
    method,
    path,
    body: body,
    query: query,
    policy: policy,
    evictMutationCache: evictMutationCache,
  );

  String get baseUrl => _dio.options.baseUrl;

  /// 新寫入排在 idle queue 後時通知同步層；由同步層統一處理結果、錯誤與 provider refresh。
  Stream<void> get queueFlushRequests =>
      _offline?.queueFlushRequests ?? const Stream<void>.empty();

  /// 寫入:線上直送(成功即依失效表 evict);離線且帶 [optimistic] → 入持久化佇列
  /// + 樂觀 patch + 回 null(樂觀成功)。細節在 [OfflineSyncEngine.sendMutation]。
  Future<dynamic> sendMutation(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    OfflineOp? optimistic,
  }) {
    final offline = _offline;
    if (offline == null || optimistic == null) {
      return _send(method, path, body: body, query: query);
    }
    return offline.sendMutation(
      method,
      path,
      body: body,
      query: query,
      optimistic: optimistic,
    );
  }

  /// 重連後依序重播離線佇列;細節在 [OfflineSyncEngine.flushQueue]。
  Future<FlushResult> flushQueue() =>
      _offline?.flushQueue() ?? Future.value(FlushResult.empty);

  Future<void> resolveConflictKeepOurs(ConflictRecord c) =>
      _offline!.resolveConflictKeepOurs(c);

  Future<void> resolveConflictKeepTheirs(ConflictRecord c) =>
      _offline!.resolveConflictKeepTheirs(c);

  /// POST 並保留完整 response（例如 AuthRepository 需要讀 set-cookie）。
  ///
  /// 仍統一套用 Cookie／Bearer／Origin，避免需要 response headers 的流程繞過
  /// [ApiClient] 的認證與 CSRF 規則。
  Future<Response<dynamic>> postForResponse(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool followRedirects = true,
  }) async {
    final auth = await _authHeadersFor('POST');
    return _dio.request<dynamic>(
      path,
      queryParameters: query,
      data: body,
      options: Options(
        method: 'POST',
        headers: auth.headers,
        followRedirects: followRedirects,
      ),
    );
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    CacheReadPolicy policy = CacheReadPolicy.cached,
  }) => _send(
    'GET',
    path,
    query: query,
    cancelToken: cancelToken,
    policy: policy,
  );

  Future<dynamic> head(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _send('HEAD', path, query: query, cancelToken: cancelToken);

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _send('DELETE', path, body: body, query: query);

  /// POST that preserves 3xx redirect response instead of following it.
  Future<ApiRedirectResponse> postForRedirect(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final response = await postForResponse(
      path,
      body: body,
      query: query,
      followRedirects: false,
    );
    final statusCode = response.statusCode ?? 0;
    if (_isEdgeBlockPage(response)) {
      throw _upstreamUnavailable(statusCode);
    }
    if (statusCode < 200 || statusCode >= 400) {
      throw ApiError.fromResponse(statusCode, response.data);
    }
    return ApiRedirectResponse(
      statusCode: statusCode,
      location: response.headers.value('location'),
    );
  }

  /// SWR 讀取:先 emit 本機快取(stale),再抓網路;fresh 到達後套用尚未 flush 的
  /// 樂觀 patch(維持「快取 = server 真相 + pending patch」不變式)再 emit。
  /// 離線且已 emit 過 stale → 收斂不報錯;離線且無快取 → emit error。
  Stream<dynamic> getStream(String path, {Map<String, dynamic>? query}) async* {
    final store = _cacheStore;
    final key = cacheKeyFor('GET', path, query);
    var yieldedStale = false;
    if (store != null) {
      Object? stale;
      var foundStale = false;
      await _offline!.withQueueLock(() async {
        final cached = await store.readResponse(key);
        if (cached == null) return;
        stale = await _offline.applyPendingPatches(key, cached.data);
        if (!identical(stale, cached.data)) {
          // 當機可能發生在 queue 已落盤、樂觀 patch 尚未寫回之間。讀 queue、
          // 重播與寫回必須和 flush completion 共用臨界區，避免 queue 已移除後
          // 又把沒有對應 pending record 的 optimistic cache 復活。
          await store.writeResponse(key, stale, cachedAt: cached.cachedAt);
        }
        foundStale = true;
      });
      if (foundStale) {
        yield stale;
        yieldedStale = true;
      }
    }
    try {
      // 網路 leg 不走 get() 的離線回退(回退已由上面的 stale 處理),才能把 fresh
      // 當「server 真相」套 pending patch,不會對已 patch 的快取重複套用。
      final fresh = await _send(
        'GET',
        path,
        query: query,
        policy: CacheReadPolicy.noStore,
      );
      if (store == null) {
        yield fresh;
      } else {
        Object? patched;
        await _offline!.withQueueLock(() async {
          final patchedValue = await _offline.applyPendingPatches(key, fresh);
          patched = patchedValue;
          final isEmpty =
              patchedValue == null ||
              (patchedValue is String && patchedValue.isEmpty);
          if (!isEmpty) {
            await store.writeResponse(key, patchedValue);
            final capacity = _capacityFor(path);
            if (capacity != null) {
              await store.enforceCapacity(
                'GET ${capacity.key}',
                capacity.value,
              );
            }
          }
        });
        yield patched;
      }
    } on DioException catch (e) {
      // 離線且已顯示 stale → 收斂;否則(無快取可顯示)讓 stream emit error。
      if (!isOfflineError(e) || !yieldedStale) rethrow;
    }
  }

  /// Authenticated streaming GET for text-based long-lived responses such as
  /// `text/event-stream`. This intentionally bypasses cache/SWR handling.
  Stream<String> getTextStream(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _getTextStream(path, query: query, cancelToken: cancelToken);

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

  static bool _isEdgeBlockPage(Response<dynamic> response) {
    final statusCode = response.statusCode ?? 0;
    return statusCode >= 200 &&
        statusCode < 300 &&
        statusCode != 204 &&
        (response.headers
                .value(Headers.contentTypeHeader)
                ?.toLowerCase()
                .contains('text/html') ??
            false);
  }

  static ApiError _upstreamUnavailable(int statusCode) => ApiError(
    status: statusCode,
    code: 'SYS_UPSTREAM_UNAVAILABLE',
    message: '伺服器暫時無法回應，請稍後重試',
  );

  static Future<void> _waitForRetry(
    int seconds,
    CancelToken? cancelToken,
  ) async {
    final initialError = cancelToken?.cancelError;
    if (initialError != null) throw initialError;
    if (seconds <= 0) return;
    final delay = Future<void>.delayed(Duration(seconds: seconds));
    if (cancelToken == null) return delay;
    await Future.any<void>([delay, cancelToken.whenCancel.then<void>((_) {})]);
    final cancelError = cancelToken.cancelError;
    if (cancelError != null) throw cancelError;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    CancelToken? cancelToken,
    bool isRetryAttempt = false,
    CacheReadPolicy policy = CacheReadPolicy.cached,
    bool evictMutationCache = true,
  }) async {
    final auth = await _authHeadersFor(method);

    final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        queryParameters: query,
        data: body,
        options: Options(method: method, headers: auth.headers),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      // 連線層失敗(離線/逾時):GET 嘗試回退本機快取(getStream 的網路 leg 關閉此回退)
      final store = _cacheStore;
      if (policy.readsCache &&
          method == 'GET' &&
          store != null &&
          isOfflineError(e)) {
        final cached = await store.readResponse(
          cacheKeyFor('GET', path, query),
        );
        if (cached != null) return cached.data;
      }
      rethrow;
    }

    final statusCode = response.statusCode ?? 0;
    final isEdgeBlockPage = _isEdgeBlockPage(response);
    final isRetryableMethod = method == 'GET' || method == 'HEAD';
    // 429、edge block page、401 Bearer-refresh 共用「同參數重送一次」。
    Future<dynamic> retry() => _send(
      method,
      path,
      query: query,
      body: body,
      cancelToken: cancelToken,
      isRetryAttempt: true,
      policy: policy,
      evictMutationCache: evictMutationCache,
    );
    if ((statusCode == 429 || isEdgeBlockPage) &&
        isRetryableMethod &&
        !isRetryAttempt) {
      final waitSeconds = parseRetryAfterSeconds(
        response.headers.value('retry-after'),
      );
      await _waitForRetry(waitSeconds, cancelToken);
      return retry();
    }
    // Bearer 模式遇 401 → 嘗試 refresh 後重試一次
    if (statusCode == 401 &&
        auth.useBearer &&
        !isRetryAttempt &&
        _bearerSource != null &&
        await _bearerSource.refresh()) {
      return retry();
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiError.fromResponse(statusCode, response.data);
    }
    if (isEdgeBlockPage) {
      throw _upstreamUnavailable(statusCode);
    }
    if (statusCode == 204) {
      if (evictMutationCache && _cacheStore != null) {
        await evictForMutation(_cacheStore, method, path, body);
      }
      return null;
    }
    final responseData = response.data;
    final isEmpty =
        responseData == null ||
        (responseData is String && responseData.isEmpty);
    if (method == 'GET') {
      if (policy.writesCache && !isEmpty) {
        final store = _cacheStore;
        if (store != null) {
          await store.writeResponse(
            cacheKeyFor('GET', path, query),
            responseData,
          );
          // 高基數 GET(POI 搜尋、路線)沒有 mutation 會 evict 它們,只增不減 →
          // 每次寫入後就地修剪,不讓它無界成長。
          final capacity = _capacityFor(path);
          if (capacity != null) {
            await store.enforceCapacity('GET ${capacity.key}', capacity.value);
          }
        }
      }
    } else {
      if (evictMutationCache && _cacheStore != null) {
        await evictForMutation(_cacheStore, method, path, body);
      }
    }
    return isEmpty ? null : responseData;
  }

  Stream<String> _getTextStream(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    bool isRetryAttempt = false,
  }) async* {
    final auth = await _authHeadersFor('GET');
    final response = await _dio.request<ResponseBody>(
      path,
      queryParameters: query,
      options: Options(
        method: 'GET',
        responseType: ResponseType.stream,
        headers: {...auth.headers, Headers.acceptHeader: 'text/event-stream'},
      ),
      cancelToken: cancelToken,
    );

    final statusCode = response.statusCode ?? 0;
    final isEdgeBlockPage = _isEdgeBlockPage(response);
    if ((statusCode == 429 || isEdgeBlockPage) && !isRetryAttempt) {
      final waitSeconds = parseRetryAfterSeconds(
        response.headers.value('retry-after'),
      );
      await response.data?.stream.drain<void>();
      await _waitForRetry(waitSeconds, cancelToken);
      yield* _getTextStream(
        path,
        query: query,
        cancelToken: cancelToken,
        isRetryAttempt: true,
      );
      return;
    }
    if (statusCode == 401 &&
        auth.useBearer &&
        !isRetryAttempt &&
        _bearerSource != null &&
        await _bearerSource.refresh()) {
      await response.data?.stream.drain<void>();
      yield* _getTextStream(
        path,
        query: query,
        cancelToken: cancelToken,
        isRetryAttempt: true,
      );
      return;
    }
    if (statusCode < 200 || statusCode >= 300) {
      final body = await _decodeStreamBody(response.data);
      throw ApiError.fromResponse(statusCode, body);
    }
    if (isEdgeBlockPage) {
      await response.data?.stream.drain<void>();
      throw _upstreamUnavailable(statusCode);
    }

    final body = response.data;
    if (body == null) return;
    yield* body.stream.cast<List<int>>().transform(utf8.decoder);
  }

  Future<Object?> _decodeStreamBody(ResponseBody? body) async {
    final text =
        await body?.stream.cast<List<int>>().transform(utf8.decoder).join() ??
        '';
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  /// 命中 [_cacheCapacityByPathPrefix] 的 path → 回傳該前綴的快取上限。
  MapEntry<String, int>? _capacityFor(String path) {
    for (final entry in _cacheCapacityByPathPrefix.entries) {
      if (path.startsWith(entry.key)) return entry;
    }
    return null;
  }

  Future<({Map<String, dynamic> headers, bool useBearer})> _authHeadersFor(
    String method,
  ) async {
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
    return (headers: requestHeaders, useBearer: useBearer);
  }
}
