/// 認證 repository：密碼登入拿 session cookie、登出、查目前使用者。
library;

import 'package:dio/dio.dart';

import '../models/user.dart';
import '../models/oauth.dart';
import '../models/public_config.dart';
import 'api_client.dart';
import 'api_error.dart';
import 'session_store.dart';

class SignupJoinedTrip {
  const SignupJoinedTrip({required this.id, required this.title});

  final String id;
  final String title;

  factory SignupJoinedTrip.fromJson(Map<String, dynamic> json) =>
      SignupJoinedTrip(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
      );
}

class SignupResult {
  const SignupResult({
    required this.userId,
    required this.email,
    required this.requiresVerification,
    this.joinedTrip,
    this.invitationError,
  });

  final String userId;
  final String email;
  final bool requiresVerification;
  final SignupJoinedTrip? joinedTrip;
  final String? invitationError;

  factory SignupResult.fromJson(Map<String, dynamic> json) {
    final joinedTripJson = json['joinedTrip'];
    return SignupResult(
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      requiresVerification: json['requiresVerification'] == true,
      joinedTrip: joinedTripJson is Map
          ? SignupJoinedTrip.fromJson(joinedTripJson.cast<String, dynamic>())
          : null,
      invitationError: json['invitationError']?.toString(),
    );
  }
}

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

  /// GET /public-config → login/signup feature flags available pre-auth.
  Future<PublicConfig> fetchPublicConfig() async {
    final body = await _client.get('/public-config');
    return PublicConfig.fromJson(body as Map<String, dynamic>);
  }

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

    final sessionToken = _sessionTokenFrom(loginResponse.headers);
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

  /// POST /oauth/signup → 解析 set-cookie 的 tripline_session 寫入 store。
  Future<SignupResult> signup({
    required String email,
    required String password,
    String? displayName,
    String? invitationToken,
  }) async {
    final signupResponse = await _client.dio.post<dynamic>(
      '/oauth/signup',
      data: {
        'email': email.trim(),
        'password': password,
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName.trim(),
        if (invitationToken != null && invitationToken.trim().isNotEmpty)
          'invitationToken': invitationToken.trim(),
      },
    );

    final statusCode = signupResponse.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiError.fromResponse(statusCode, signupResponse.data);
    }

    final sessionToken = _sessionTokenFrom(signupResponse.headers);
    if (sessionToken == null || sessionToken.isEmpty) {
      throw ApiError(
        status: statusCode,
        code: 'AUTH_NO_SESSION_COOKIE',
        message: '註冊回應缺少 tripline_session cookie',
      );
    }
    await _sessionStore.write(sessionToken);

    return SignupResult.fromJson(signupResponse.data as Map<String, dynamic>);
  }

  /// POST /oauth/forgot-password；後端固定 generic response，避免帳號列舉。
  Future<String?> requestPasswordReset(String email) async {
    final body = await _client.post(
      '/oauth/forgot-password',
      body: {'email': email.trim()},
    );
    return _messageFrom(body);
  }

  /// POST /oauth/reset-password。
  Future<String?> resetPassword({
    required String token,
    required String password,
  }) async {
    final body = await _client.post(
      '/oauth/reset-password',
      body: {'token': token.trim(), 'password': password},
    );
    return _messageFrom(body);
  }

  /// POST /oauth/verify。
  Future<bool> verifyEmail(String token) async {
    final body = await _client.post(
      '/oauth/verify',
      body: {'token': token.trim()},
    );
    return body is Map && body['ok'] == true;
  }

  /// POST /oauth/send-verification；後端固定 generic response。
  Future<String?> sendVerificationEmail(String email) async {
    final body = await _client.post(
      '/oauth/send-verification',
      body: {'email': email.trim()},
    );
    return _messageFrom(body);
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
  ///
  /// 離線快取(刻意行為):userinfo 走 ApiClient 透明快取,離線開機時 GET 連線失敗
  /// 會回退最後一次成功的身分,讓 cookie 模式使用者離線仍保持登入、能讀已快取行程。
  /// 登出會清快取(避免跨帳號外洩);無快取時離線仍 throw(等同本快取功能前的行為)。
  Future<UserInfo?> currentUser() async {
    try {
      final userInfoJson = await _client.get('/oauth/userinfo');
      return UserInfo.fromJson(userInfoJson as Map<String, dynamic>);
    } on ApiError catch (apiError) {
      if (apiError.status == 401) return null;
      rethrow;
    }
  }

  /// POST /oauth/consent；後端以 302 Location 表示後續 authorize/deny 目的地。
  Future<OAuthConsentResult> submitOAuthConsent(
    OAuthConsentRequest request, {
    required String decision,
  }) async {
    final response = await _client.postForRedirect(
      '/oauth/consent',
      body: request.toBody(decision),
    );
    return OAuthConsentResult(
      statusCode: response.statusCode,
      redirectLocation: response.location,
    );
  }

  String? _sessionTokenFrom(Headers headers) {
    final setCookieHeaders = headers['set-cookie'] ?? const <String>[];
    for (final cookieHeader in setCookieHeaders) {
      final sessionCookieMatch = _sessionCookiePattern.firstMatch(cookieHeader);
      if (sessionCookieMatch != null) {
        return sessionCookieMatch.group(1);
      }
    }
    return null;
  }

  String? _messageFrom(Object? body) {
    if (body is Map) return body['message']?.toString();
    return null;
  }
}
