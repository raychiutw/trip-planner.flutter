/// 認證 repository：密碼登入拿 session cookie、登出、查目前使用者。
library;

import '../models/user.dart';
import 'api_client.dart';
import 'api_error.dart';
import 'session_store.dart';

/// 對應 `/api/oauth/*` 認證 endpoints。
class AuthRepository {
  AuthRepository({required ApiClient client, required SessionStore sessionStore})
      : _client = client,
        _sessionStore = sessionStore;

  final ApiClient _client;
  final SessionStore _sessionStore;

  static final _sessionCookiePattern =
      RegExp(r'(?:^|;\s*)tripline_session=([^;]+)');

  /// POST /oauth/login → 解析 set-cookie 的 tripline_session 寫入 store →
  /// GET /oauth/userinfo 回 UserInfo。
  Future<UserInfo> login({
    required String email,
    required String password,
  }) async {
    // 走 raw dio 才能讀 response headers（set-cookie）
    final loginResponse = await _client.dio.post<dynamic>(
      '/oauth/login',
      data: {'email': email, 'password': password},
    );

    final statusCode = loginResponse.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiError.fromResponse(statusCode, loginResponse.data);
    }

    final setCookieHeaders =
        loginResponse.headers['set-cookie'] ?? const <String>[];
    String? sessionToken;
    for (final cookieHeader in setCookieHeaders) {
      final sessionCookieMatch =
          _sessionCookiePattern.firstMatch(cookieHeader);
      if (sessionCookieMatch != null) {
        sessionToken = sessionCookieMatch.group(1);
        break;
      }
    }
    if (sessionToken == null || sessionToken.isEmpty) {
      throw ApiError(
        status: statusCode,
        code: 'AUTH_NO_SESSION_COOKIE',
        message: '登入回應缺少 tripline_session cookie',
      );
    }
    await _sessionStore.write(sessionToken);

    final userInfoJson = await _client.get('/oauth/userinfo');
    return UserInfo.fromJson(userInfoJson as Map<String, dynamic>);
  }

  /// POST /oauth/logout（忽略失敗）+ 清空本機 session。
  Future<void> logout() async {
    try {
      await _client.post('/oauth/logout');
    } catch (_) {
      // server 端登出失敗不影響本機清除
    } finally {
      await _sessionStore.clear();
    }
  }

  /// GET /oauth/userinfo；401（未登入/過期）回 null，不 throw。
  Future<UserInfo?> currentUser() async {
    try {
      final userInfoJson = await _client.get('/oauth/userinfo');
      return UserInfo.fromJson(userInfoJson as Map<String, dynamic>);
    } on ApiError catch (apiError) {
      if (apiError.status == 401) return null;
      rethrow;
    }
  }
}
