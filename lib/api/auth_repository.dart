/// 認證 repository：密碼登入拿 session cookie、登出、查目前使用者。
library;

import 'package:dio/dio.dart';

import '../models/auth.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'api_error.dart';
import 'session_store.dart';

/// 對應 `/api/oauth/*` 認證 endpoints。
class AuthRepository {
  AuthRepository({
    required ApiClient client,
    required SessionStore sessionStore,
  }) : _client = client,
       _sessionStore = sessionStore;

  final ApiClient _client;
  final SessionStore _sessionStore;

  static final _sessionCookiePattern = RegExp(
    r'(?:^|;\s*)tripline_session=([^;]+)',
  );

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

    await _writeSessionCookie(loginResponse);

    final userInfoJson = await _client.get('/oauth/userinfo');
    return UserInfo.fromJson(userInfoJson as Map<String, dynamic>);
  }

  /// POST /oauth/signup → 解析 set-cookie 寫入 store → 回 signup 結果。
  Future<SignupResult> signup({
    required String email,
    required String password,
    String? displayName,
    String? invitationToken,
  }) async {
    final body = <String, dynamic>{'email': email, 'password': password};
    final trimmedDisplayName = displayName?.trim();
    if (trimmedDisplayName != null && trimmedDisplayName.isNotEmpty) {
      body['displayName'] = trimmedDisplayName;
    }
    final trimmedInvitationToken = invitationToken?.trim();
    if (trimmedInvitationToken != null && trimmedInvitationToken.isNotEmpty) {
      body['invitationToken'] = trimmedInvitationToken;
    }

    // signup 會發 Set-Cookie；與 login 一樣必須走 raw dio 讀 response header。
    final signupResponse = await _client.dio.post<dynamic>(
      '/oauth/signup',
      data: body,
    );
    final statusCode = signupResponse.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiError.fromResponse(statusCode, signupResponse.data);
    }

    await _writeSessionCookie(signupResponse);
    return SignupResult.fromJson(_asJsonObject(signupResponse.data));
  }

  /// POST /oauth/forgot-password；後端用 generic 成功訊息避免 email enumeration。
  Future<AuthMessageResult> requestPasswordReset(String email) async {
    final responseBody = await _client.post(
      '/oauth/forgot-password',
      body: {'email': email},
    );
    return AuthMessageResult.fromJson(_asJsonObject(responseBody));
  }

  /// POST /oauth/reset-password；成功後不自動登入，使用者需回登入頁。
  Future<AuthMessageResult> resetPassword({
    required String token,
    required String password,
  }) async {
    final responseBody = await _client.post(
      '/oauth/reset-password',
      body: {'token': token, 'password': password},
    );
    return AuthMessageResult.fromJson(_asJsonObject(responseBody));
  }

  /// POST /oauth/verify，以 user gesture 送出 email verification token。
  Future<void> verifyEmail(String token) async {
    final responseBody = await _client.post(
      '/oauth/verify',
      body: {'token': token},
    );
    final json = _asJsonObject(responseBody);
    if (json['ok'] != true && json['ok'] != 1) {
      throw const ApiError(
        status: 200,
        code: 'VERIFY_EMAIL_FAILED',
        message: 'Email 驗證失敗',
      );
    }
  }

  /// POST /oauth/send-verification；重寄 email 驗證信。
  Future<AuthMessageResult> sendVerificationEmail(String email) async {
    final responseBody = await _client.post(
      '/oauth/send-verification',
      body: {'email': email},
    );
    return AuthMessageResult.fromJson(_asJsonObject(responseBody));
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

  Future<void> _writeSessionCookie(Response<dynamic> response) async {
    final statusCode = response.statusCode ?? 0;
    final setCookieHeaders = response.headers['set-cookie'] ?? const <String>[];
    String? sessionToken;
    for (final cookieHeader in setCookieHeaders) {
      final sessionCookieMatch = _sessionCookiePattern.firstMatch(cookieHeader);
      if (sessionCookieMatch != null) {
        sessionToken = sessionCookieMatch.group(1);
        break;
      }
    }
    if (sessionToken == null || sessionToken.isEmpty) {
      throw ApiError(
        status: statusCode,
        code: 'AUTH_NO_SESSION_COOKIE',
        message: '認證回應缺少 tripline_session cookie',
      );
    }
    await _sessionStore.write(sessionToken);
  }
}

Map<String, dynamic> _asJsonObject(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
