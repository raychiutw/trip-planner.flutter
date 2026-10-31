/// OAuth client 設定(建置時以 --dart-define 注入;預設值是 production 的 public client)。
///
/// 切換到新 api 時只改這幾個值,不改程式:
///   --dart-define=TRIPLINE_API_ORIGIN=...
///   --dart-define=TRIPLINE_OAUTH_CLIENT_ID=tripline-mobile
///   --dart-define=TRIPLINE_OAUTH_CALLBACK_HOST=...
///   --dart-define=TRIPLINE_OAUTH_CALLBACK_PATH=/oauth/callback
library;

abstract final class OAuthConfig {
  /// public client 的 id(不是機密)。
  static const clientId = String.fromEnvironment(
    'TRIPLINE_OAUTH_CLIENT_ID',
    defaultValue: 'tripline-mobile',
  );

  /// 授權回跳(Universal Link／App Link)的網域；須與後端登記的 redirect URI 一致，
  /// 且該網域要承載 apple-app-site-association 與 assetlinks.json。
  static const callbackHost = String.fromEnvironment(
    'TRIPLINE_OAUTH_CALLBACK_HOST',
    defaultValue: 'mobile-callback.trip-planner-dby.pages.dev',
  );

  static const callbackPath = String.fromEnvironment(
    'TRIPLINE_OAUTH_CALLBACK_PATH',
    defaultValue: '/oauth/callback',
  );

  static String get redirectUri => 'https://$callbackHost$callbackPath';
}
