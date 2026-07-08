/// dio 封裝：cookie 認證、CSRF Origin、錯誤轉換、429 retry、204 處理。
library;

import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';

import 'api_error.dart';
import 'session_store.dart';

/// CSRF Origin allowlist 要求的正式站 origin。
const String kTriplineOrigin = 'https://trip-planner-dby.pages.dev';

/// Redirect-style API response where callers need the `Location` header.
class ApiRedirectResponse {
  const ApiRedirectResponse({required this.statusCode, required this.location});

  final int statusCode;
  final String? location;
}

/// Tripline API client，base = `<origin>/api`。
class ApiClient {
  ApiClient({
    required SessionStore sessionStore,
    Dio? dio,
    String origin = kTriplineOrigin,
    String? apiBaseUrl,
  }) : _sessionStore = sessionStore,
       _origin = origin,
       _dio = dio ?? Dio() {
    _dio.options.baseUrl = apiBaseUrl ?? '$origin/api';
    // 全收所有 status code，由 _send 自行判斷丟 ApiError
    _dio.options.validateStatus = (_) => true;
  }

  final SessionStore _sessionStore;
  final String _origin;
  final Dio _dio;

  /// 供 AuthRepository 直接讀 response headers（set-cookie）用。
  Dio get dio => _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) => _send('POST', path, query: query, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<ApiRedirectResponse> postForRedirect(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final response = await _request(
      'POST',
      path,
      query: query,
      body: body,
      followRedirects: false,
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 400) {
      throw ApiError.fromResponse(statusCode, response.data);
    }
    return ApiRedirectResponse(
      statusCode: statusCode,
      location: response.headers.value('location'),
    );
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
    bool isRetryAttempt = false,
  }) async {
    final response = await _request(method, path, query: query, body: body);

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
        isRetryAttempt: true,
      );
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

  Future<Response<dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool followRedirects = true,
  }) async {
    final requestHeaders = <String, dynamic>{};
    final sessionToken = await _sessionStore.read();
    if (sessionToken != null && sessionToken.isNotEmpty) {
      requestHeaders['Cookie'] = 'tripline_session=$sessionToken';
    }
    final isMutation = method != 'GET' && method != 'HEAD';
    if (isMutation) {
      // cookie 認證的 mutating request 必帶 Origin（後端 CSRF 檢查）
      requestHeaders['Origin'] = _origin;
    }

    return _dio.request<dynamic>(
      path,
      queryParameters: query,
      data: body,
      options: Options(
        method: method,
        headers: requestHeaders,
        followRedirects: followRedirects,
      ),
    );
  }
}
