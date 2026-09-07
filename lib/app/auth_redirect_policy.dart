/// 認證 redirect 政策:一個純函式,輸入登入狀態與 URI,輸出目標 location 或 null。
///
/// 公開路由清單只在這裡;`/s/:token` 是唯一不在清單、用路徑段判斷的公開頁。
library;

const publicShellOutsideRoutes = {
  '/welcome',
  '/login',
  '/signup',
  '/signup/check-email',
  '/login/forgot',
  '/auth/password/reset',
  '/auth/verify-email',
  '/oauth/consent',
  '/invite',
};

bool isPublicShellOutsideRoute({
  required String matchedLocation,
  required Uri uri,
}) {
  if (publicShellOutsideRoutes.contains(matchedLocation)) return true;
  final segments = uri.pathSegments;
  return segments.length == 2 && segments.first == 's';
}

/// 四個 root 與行程 / 收藏子頁;`/trips/new` 是 shell 外表單。
bool isShellContentLocation(String path) =>
    path == '/chat' ||
    path == '/map' ||
    path == '/trips' ||
    path == '/favorites' ||
    (path.startsWith('/trips/') && path != '/trips/new') ||
    path.startsWith('/favorites/');

/// GoRouter 全域 redirect 的唯一決策。
String? authRedirect({
  required bool isLoading,
  required bool isLoggedIn,
  required Uri uri,
  required String matchedLocation,
}) {
  // 認證狀態尚未解析時不 redirect,避免閃跳
  if (isLoading) return null;
  final isOnLogin = matchedLocation == '/login';
  final isOnWelcome = matchedLocation == '/welcome';
  if (!isLoggedIn &&
      !isOnLogin &&
      !isPublicShellOutsideRoute(matchedLocation: matchedLocation, uri: uri)) {
    return welcomeLocationWithRedirect(uri);
  }
  if (isLoggedIn && (isOnLogin || isOnWelcome)) {
    return redirectAfterLogin(uri);
  }
  return null;
}

String welcomeLocationWithRedirect(Uri uri) {
  final requestedLocation = uri.toString();
  if (requestedLocation == '/trips') return '/welcome';
  return '/welcome?redirect_after=${Uri.encodeComponent(requestedLocation)}';
}

String loginLocationFromWelcome(Uri uri) {
  final redirectAfter = redirectAfterLogin(uri);
  if (redirectAfter == '/trips') return '/login';
  return '/login?redirect_after=${Uri.encodeComponent(redirectAfter)}';
}

/// 登入後只跳站內路徑:拒絕 scheme / authority / `//` 與登入頁本身。
String redirectAfterLogin(Uri uri) {
  final rawRedirect = uri.queryParameters['redirect_after'];
  if (rawRedirect == null) return '/trips';

  final redirectUri = Uri.tryParse(rawRedirect);
  if (redirectUri == null ||
      redirectUri.hasScheme ||
      redirectUri.hasAuthority ||
      !rawRedirect.startsWith('/') ||
      rawRedirect.startsWith('//') ||
      redirectUri.path == '/login' ||
      redirectUri.path == '/welcome') {
    return '/trips';
  }
  return redirectUri.toString();
}
