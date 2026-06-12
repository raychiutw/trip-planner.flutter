/// dio 封裝：cookie 認證、CSRF Origin、錯誤轉換、429 retry、204 處理。
library;

import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';

import 'api_error.dart';
import 'cache/cache_keys.dart';
import 'cache/cache_store.dart';
import 'cache/offline_op.dart';
import 'cache/optimistic_patchers.dart';
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

/// flushQueue 的結果:成功同步筆數 + 上報的衝突(已從佇列移除)。
class FlushResult {
  const FlushResult({required this.synced, required this.conflicts});
  final int synced;
  final List<QueuedMutation> conflicts;
  static const empty = FlushResult(synced: 0, conflicts: <QueuedMutation>[]);
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
  int _mutationCounter = 0;
  bool _flushing = false;

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

  /// SWR 讀取:先 emit 本機快取(stale),再抓網路;fresh 到達後套用尚未 flush 的
  /// 樂觀 patch(維持「快取 = server 真相 + pending patch」不變式)再 emit。
  /// 離線且已 emit 過 stale → 收斂不報錯;離線且無快取 → emit error。
  Stream<dynamic> getStream(String path, {Map<String, dynamic>? query}) async* {
    final store = _cacheStore;
    final key = cacheKeyFor('GET', path, query);
    var yieldedStale = false;
    if (store != null) {
      final cached = await store.readResponse(key);
      if (cached != null) {
        yield cached.data;
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
        fallbackToCache: false,
      );
      if (store == null) {
        yield fresh;
      } else {
        final patched = await _applyPendingPatches(store, key, fresh);
        if (!identical(patched, fresh)) {
          await store.writeResponse(key, patched);
        }
        yield patched;
      }
    } on DioException catch (e) {
      // 離線且已顯示 stale → 收斂;否則(無快取可顯示)讓 stream emit error。
      if (!_isOfflineError(e) || !yieldedStale) rethrow;
    }
  }

  /// 寫入:線上直送(成功即依失效表 evict);離線且帶 [optimistic] → 入持久化佇列
  /// + 對 op.cacheKey 套樂觀 patch + 回 null(樂觀成功)。無 optimistic 或非離線 → rethrow。
  Future<dynamic> sendMutation(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    OfflineOp? optimistic,
  }) async {
    try {
      return await _send(method, path, body: body, query: query);
    } on DioException catch (e) {
      final store = _cacheStore;
      if (optimistic != null && store != null && _isOfflineError(e)) {
        final now = DateTime.now();
        final seq = _mutationCounter++;
        final id = '${now.microsecondsSinceEpoch}-$seq';
        // 穩定臨時 id:由「微秒×1000 + seq」導出唯一負值,存進 args 一次 →
        // 入佇列當下與日後 getStream 重播讀同一值(冪等);連續離線新增不碰撞、
        // 跨重啟單調遞減。已帶 tempId(測試)則尊重之。
        final args = optimistic.args.containsKey('tempId')
            ? optimistic.args
            : {
                ...optimistic.args,
                'tempId': -(now.microsecondsSinceEpoch * 1000 + (seq % 1000)),
              };
        await store.appendMutation(
          QueuedMutation(
            id: id,
            method: method,
            path: path,
            query: query,
            body: body,
            type: optimistic.type,
            cacheKey: optimistic.cacheKey,
            args: args,
            createdAt: now.toIso8601String(),
          ),
        );
        final current = await store.readResponse(optimistic.cacheKey);
        final patched = applyOptimisticPatch(
          optimistic.type,
          current?.data,
          args,
        );
        // null 代表無 base 可 patch(該資源未快取)→ 不寫,僅留佇列待 flush。
        if (patched != null) {
          await store.writeResponse(optimistic.cacheKey, patched);
        }
        return null;
      }
      rethrow;
    }
  }

  /// 重連後依序重播離線佇列。成功 → 移除(_send 已 evict 受影響快取);
  /// HTTP 錯誤(含 409 衝突)→ 上報並移除(v1 不 rebase,列 PR-4b);
  /// 連線錯誤 → 中止並保留剩餘佇列(下次再試)。重入時直接回 empty。
  Future<FlushResult> flushQueue() async {
    final store = _cacheStore;
    if (store == null || _flushing) return FlushResult.empty;
    _flushing = true;
    try {
      final conflicts = <QueuedMutation>[];
      var synced = 0;
      for (final m in await store.readQueue()) {
        try {
          await _send(m.method, m.path, body: m.body, query: m.query);
          await store.removeMutation(m.id);
          synced++;
        } on ApiError catch (e) {
          // 5xx 視為暫時失敗 → 中止保留佇列、下次再試(避免永久遺失離線編輯);
          // 4xx(含 409 衝突)→ 上報並移除。
          if (e.status >= 500) break;
          conflicts.add(m);
          await store.removeMutation(m.id);
        } on DioException catch (e) {
          if (_isOfflineError(e)) break;
          rethrow;
        }
      }
      return FlushResult(synced: synced, conflicts: conflicts);
    } finally {
      _flushing = false;
    }
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
    bool fallbackToCache = true,
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
      // 連線層失敗(離線/逾時):GET 嘗試回退本機快取(getStream 的網路 leg 關閉此回退)
      final store = _cacheStore;
      if (fallbackToCache &&
          method == 'GET' &&
          store != null &&
          _isOfflineError(e)) {
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
        fallbackToCache: fallbackToCache,
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
        fallbackToCache: fallbackToCache,
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

  /// 對某 key 依佇列順序套用所有 cacheKey 命中的待 flush 樂觀 patch(維持不變式)。
  Future<Object?> _applyPendingPatches(
    CacheStore store,
    String key,
    Object? base,
  ) async {
    final queue = await store.readQueue();
    var result = base;
    for (final m in queue) {
      if (m.cacheKey == key) {
        result = applyOptimisticPatch(m.type, result, m.args);
      }
    }
    return result;
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
