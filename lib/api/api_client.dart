/// dio 封裝：cookie 認證、CSRF Origin、錯誤轉換、429 retry、204 處理。
library;

import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';

import 'api_error.dart';
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
  })  : _sessionStore = sessionStore,
        _origin = origin,
        _bearerSource = bearerSource,
        _dio = dio ?? Dio() {
    _dio.options.baseUrl = '$origin/api';
    // 全收所有 status code，由 _send 自行判斷丟 ApiError
    _dio.options.validateStatus = (_) => true;
  }

  final SessionStore _sessionStore;
  final String _origin;
  final BearerTokenSource? _bearerSource;
  final Dio _dio;

  /// 供 AuthRepository 直接讀 response headers（set-cookie）用。
  Dio get dio => _dio;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) =>
      _send('GET', path, query: query, cancelToken: cancelToken);

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Map<String, dynamic>? query}) =>
      _send('DELETE', path, query: query);

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

    final response = await _dio.request<dynamic>(
      path,
      queryParameters: query,
      data: body,
      options: Options(method: method, headers: requestHeaders),
      cancelToken: cancelToken,
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 429 && method == 'GET' && !isRetryAttempt) {
      final waitSeconds =
          parseRetryAfterSeconds(response.headers.value('retry-after'));
      await Future<void>.delayed(Duration(seconds: waitSeconds));
      return _send(method, path,
          query: query,
          body: body,
          cancelToken: cancelToken,
          isRetryAttempt: true);
    }
    // Bearer 模式遇 401 → 嘗試 refresh 後重試一次
    if (statusCode == 401 &&
        useBearer &&
        !isRetryAttempt &&
        _bearerSource != null &&
        await _bearerSource.refresh()) {
      return _send(method, path,
          query: query,
          body: body,
          cancelToken: cancelToken,
          isRetryAttempt: true);
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiError.fromResponse(statusCode, response.data);
    }
    if (statusCode == 204) return null;
    final responseData = response.data;
    if (responseData == null ||
        (responseData is String && responseData.isEmpty)) {
      return null;
    }
    return responseData;
  }
}
