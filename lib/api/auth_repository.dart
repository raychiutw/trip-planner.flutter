/// 認證 repository：註冊、密碼重設、驗證信、帳號刪除與查目前使用者。
/// 登入與登出走 OAuth（PKCE），不在這裡。
library;

import '../models/user.dart';
import '../models/public_config.dart';
import 'api_client.dart';
import 'api_error.dart';
import 'cache_read_policy.dart';

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

class AccountDeletionPreview {
  const AccountDeletionPreview({
    required this.hasPassword,
    required this.tripsOwned,
    required this.collaboratorsAffected,
  });

  final bool hasPassword;
  final int tripsOwned;
  final int collaboratorsAffected;

  factory AccountDeletionPreview.fromJson(Map<String, dynamic> json) =>
      AccountDeletionPreview(
        hasPassword: json['hasPassword'] as bool,
        tripsOwned: (json['tripsOwned'] as num).toInt(),
        collaboratorsAffected: (json['collaboratorsAffected'] as num).toInt(),
      );
}

/// 對應 `/api/oauth/*` 認證 endpoints。
class AuthRepository {
  AuthRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /public-config → login/signup feature flags available pre-auth.
  Future<PublicConfig> fetchPublicConfig() async {
    final body = await _client.get('/public-config');
    return PublicConfig.fromJson(body as Map<String, dynamic>);
  }

  /// POST /oauth/signup。註冊後不會自動登入，使用者要再用瀏覽器登入。
  Future<SignupResult> signup({
    required String email,
    required String password,
    required bool privacyConsent,
    String? displayName,
    String? invitationToken,
  }) async {
    final body = await _client.post(
      '/oauth/signup',
      body: {
        'email': email.trim(),
        'password': password,
        'privacyConsent': privacyConsent,
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName.trim(),
        if (invitationToken != null && invitationToken.trim().isNotEmpty)
          'invitationToken': invitationToken.trim(),
      },
    );
    return SignupResult.fromJson(body as Map<String, dynamic>);
  }

  /// GET /account：刪除前顯示會受影響的行程與共編者。
  Future<AccountDeletionPreview> fetchAccountDeletionPreview() async {
    final body = await _client.get('/account', policy: CacheReadPolicy.noStore);
    return AccountDeletionPreview.fromJson(body as Map<String, dynamic>);
  }

  /// DELETE /account：有密碼的帳號送 password，純 OAuth 帳號送 DELETE。
  Future<void> deleteAccount({
    required bool hasPassword,
    required String confirmation,
  }) async {
    await _client.delete(
      '/account',
      body: hasPassword
          ? {'password': confirmation}
          : {'confirm': confirmation},
    );
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

  /// GET /oauth/userinfo；401（未登入/過期）回 null，不 throw。
  ///
  /// 離線快取(刻意行為):userinfo 走 ApiClient 透明快取,離線開機時 GET 連線失敗
  /// 會回退最後一次成功的身分,讓使用者離線仍保持登入、能讀已快取行程。
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

  /// GET /account/ai-authorization。
  Future<bool> fetchAiAuthorization() async {
    final body = await _client.get(
      '/account/ai-authorization',
      policy: CacheReadPolicy.noStore,
    );
    return body is Map && body['authorized'] == true;
  }

  /// POST /account/ai-authorization。
  Future<bool> authorizeAi() async {
    final body = await _client.post('/account/ai-authorization');
    return body is Map && body['authorized'] == true;
  }

  String? _messageFrom(Object? body) {
    if (body is Map) return body['message']?.toString();
    return null;
  }
}
