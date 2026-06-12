/// OAuth client 設定(由 --dart-define 注入;待 backend owner provision public client)。
/// 例:--dart-define=TRIPLINE_OAUTH_CLIENT_ID=tripline-mobile
///     --dart-define=TRIPLINE_OAUTH_REDIRECT_PORT=8765
library;

abstract final class OAuthConfig {
  static const clientId = String.fromEnvironment('TRIPLINE_OAUTH_CLIENT_ID');

  /// loopback 固定埠(RFC 8252);須與註冊的 redirect_uri 完全一致。
  static const redirectPort = int.fromEnvironment(
    'TRIPLINE_OAUTH_REDIRECT_PORT',
    defaultValue: 8765,
  );

  static String get redirectUri => 'http://127.0.0.1:$redirectPort';

  /// 有設定 client_id 才啟用 OAuth 登入(否則 app 維持 cookie 登入)。
  static bool get isConfigured => clientId.isNotEmpty;
}
