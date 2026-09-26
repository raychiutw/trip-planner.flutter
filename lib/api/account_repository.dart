/// 帳號自己的 repository:個人資料、通知偏好、登入裝置、已連結 app、developer
/// apps、公開行程 clone。與行程無關,只是共用同一個 [ApiClient]。
library;

import '../models/oauth.dart';
import '../models/user.dart';
import 'api_client.dart';

class AccountRepository {
  AccountRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// PATCH /account/profile（displayName 傳 null 表示清除）。
  Future<UserInfo> updateProfile({String? displayName}) async {
    final responseBody = await _client.patch(
      '/account/profile',
      body: {'displayName': displayName},
    );
    return UserInfo.fromJson(responseBody as Map<String, dynamic>);
  }

  /// GET /account/notifications，讀取通知偏好。
  Future<AccountNotificationPreferences>
  fetchAccountNotificationPreferences() async {
    final responseBody = await _client.get('/account/notifications');
    final preferencesJson =
        (responseBody as Map<String, dynamic>)['preferences']
            as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return AccountNotificationPreferences.fromJson(preferencesJson);
  }

  /// PATCH /account/notifications，更新單一或多個通知偏好。
  Future<AccountNotificationPreferences> updateAccountNotificationPreferences({
    bool? tripUpdates,
    bool? invitations,
    bool? system,
  }) async {
    final body = <String, bool>{
      'tripUpdates': ?tripUpdates,
      'invitations': ?invitations,
      'system': ?system,
    };
    if (body.isEmpty) {
      throw ArgumentError.value(body, 'body', '至少提供一個通知設定欄位');
    }
    final responseBody = await _client.patch(
      '/account/notifications',
      body: body,
    );
    final preferencesJson =
        (responseBody as Map<String, dynamic>)['preferences']
            as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return AccountNotificationPreferences.fromJson(preferencesJson);
  }

  /// GET /account/sessions，列出目前帳號登入裝置。
  Future<AccountSessionsPage> fetchAccountSessions() async {
    final responseBody = await _client.get('/account/sessions');
    return AccountSessionsPage.fromJson(responseBody as Map<String, dynamic>);
  }

  /// DELETE /account/sessions，登出其他裝置並回傳撤銷數量。
  Future<int> revokeOtherAccountSessions() async {
    final responseBody = await _client.delete('/account/sessions');
    if (responseBody is Map<String, dynamic>) {
      return (responseBody['revoked'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  /// DELETE /account/sessions/:sid，登出指定裝置。
  Future<void> revokeAccountSession(String sid) {
    return _client.delete('/account/sessions/${Uri.encodeComponent(sid)}');
  }

  /// GET /account/connected-apps，列出目前帳號授權過的 OAuth app。
  Future<List<ConnectedApp>> fetchConnectedApps() async {
    final responseBody = await _client.get('/account/connected-apps');
    final appsJson =
        (responseBody as Map<String, dynamic>)['apps'] as List<dynamic>? ??
        const [];
    return appsJson
        .map(
          (appJson) => ConnectedApp.fromJson(appJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// DELETE /account/connected-apps/:clientId，撤銷 app access/refresh token。
  Future<void> revokeConnectedApp(String clientId) {
    return _client.delete(
      '/account/connected-apps/${Uri.encodeComponent(clientId)}',
    );
  }

  /// GET /dev/apps，列出目前帳號建立的 OAuth client apps。
  Future<List<DeveloperApp>> fetchDeveloperApps() async {
    final responseBody = await _client.get('/dev/apps');
    final appsJson =
        (responseBody as Map<String, dynamic>)['apps'] as List<dynamic>? ??
        const [];
    return appsJson
        .map(
          (appJson) => DeveloperApp.fromJson(appJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// GET /dev/apps/:clientId，讀取單一 OAuth client app。
  Future<DeveloperApp> fetchDeveloperApp(String clientId) async {
    final responseBody = await _client.get(
      '/dev/apps/${Uri.encodeComponent(clientId)}',
    );
    return DeveloperApp.fromJson(responseBody as Map<String, dynamic>);
  }

  /// POST /dev/apps，建立 OAuth client app。
  Future<CreatedDeveloperApp> createDeveloperApp({
    required String appName,
    String clientType = 'public',
    required List<String> redirectUris,
    List<String> allowedScopes = const ['openid', 'profile', 'email'],
    String? appDescription,
    String? homepageUrl,
  }) async {
    final responseBody = await _client.post(
      '/dev/apps',
      body: {
        'app_name': appName.trim(),
        'client_type': clientType == 'confidential' ? 'confidential' : 'public',
        'redirect_uris': redirectUris
            .map((uri) => uri.trim())
            .where((uri) => uri.isNotEmpty)
            .toList(),
        'allowed_scopes': allowedScopes
            .where(kDeveloperAllowedScopes.contains)
            .toList(),
        'app_description': _trimmedOrNull(appDescription),
        'homepage_url': _trimmedOrNull(homepageUrl),
      },
    );
    return CreatedDeveloperApp.fromJson(responseBody as Map<String, dynamic>);
  }

  /// PATCH /dev/apps/:clientId，更新 OAuth client app metadata。
  Future<DeveloperApp> updateDeveloperApp({
    required String clientId,
    String? appName,
    String? appDescription,
    bool clearAppDescription = false,
    String? appLogoUrl,
    bool clearAppLogoUrl = false,
    String? homepageUrl,
    bool clearHomepageUrl = false,
    List<String>? redirectUris,
    List<String>? allowedScopes,
  }) async {
    final body = <String, dynamic>{
      'app_name': ?_trimmedOrNull(appName),
      if (appDescription != null || clearAppDescription)
        'app_description': clearAppDescription
            ? null
            : _trimmedOrNull(appDescription),
      if (appLogoUrl != null || clearAppLogoUrl)
        'app_logo_url': clearAppLogoUrl ? null : _trimmedOrNull(appLogoUrl),
      if (homepageUrl != null || clearHomepageUrl)
        'homepage_url': clearHomepageUrl ? null : _trimmedOrNull(homepageUrl),
      if (redirectUris != null)
        'redirect_uris': redirectUris
            .map((uri) => uri.trim())
            .where((uri) => uri.isNotEmpty)
            .toList(),
      if (allowedScopes != null)
        'allowed_scopes': allowedScopes
            .where(kDeveloperAllowedScopes.contains)
            .toList(),
    };
    if (body.isEmpty) {
      throw ArgumentError.value(body, 'body', '至少提供一個應用更新欄位');
    }
    final responseBody = await _client.patch(
      '/dev/apps/${Uri.encodeComponent(clientId)}',
      body: body,
    );
    return DeveloperApp.fromJson(responseBody as Map<String, dynamic>);
  }

  /// DELETE /dev/apps/:clientId，soft-delete 為 suspended。
  Future<String> suspendDeveloperApp(String clientId) async {
    final responseBody = await _client.delete(
      '/dev/apps/${Uri.encodeComponent(clientId)}',
    );
    if (responseBody is Map<String, dynamic>) {
      return responseBody['suspended_client_id'] as String? ?? clientId;
    }
    return clientId;
  }

  /// POST /share/:token/clone，將公開行程複製到目前登入帳號。
  Future<String> clonePublicTripShare(String token) async {
    final responseBody = await _client.post(
      '/share/${Uri.encodeComponent(token)}/clone',
      body: <String, dynamic>{},
    );
    return (responseBody as Map<String, dynamic>)['tripId'] as String;
  }
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
