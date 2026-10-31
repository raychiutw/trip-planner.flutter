import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/models/oauth_tokens.dart';

/// 測試用的瀏覽器登入：不開瀏覽器，直接把一組憑證交給憑證來源，
/// 之後身分由（被 mock 的）`currentUser()` 解析。
class FakeOAuthLoginService implements OAuthLoginService {
  FakeOAuthLoginService(this._source, {this.onLogin, this.error});

  final StoredBearerTokenSource _source;
  final void Function()? onLogin;
  final Object? error;
  int calls = 0;

  @override
  Future<OAuthTokens> login() async {
    calls++;
    onLogin?.call();
    if (error != null) throw error!;
    final tokens = OAuthTokens(
      accessToken: 'AT',
      refreshToken: 'RT',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
    await _source.adopt(tokens);
    return tokens;
  }
}

/// 已有登入憑證的記憶體 store（讓 AuthNotifier 把使用者視為已登入）。
InMemoryOAuthTokenStore signedInTokenStore() {
  final store = InMemoryOAuthTokenStore();
  store.write(
    OAuthTokens(
      accessToken: 'AT',
      refreshToken: 'RT',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    ),
  );
  return store;
}

/// 換掉瀏覽器登入。回傳的 overrides 可直接放進 ProviderScope／ProviderContainer。
/// [created] 會收到建立出來的 fake，方便斷言呼叫次數。
List<dynamic> fakeBrowserLoginOverrides({
  void Function(FakeOAuthLoginService service)? created,
  void Function()? onLogin,
  Object? error,
}) => [
  oauthLoginServiceProvider.overrideWith((ref) {
    final service = FakeOAuthLoginService(
      ref.watch(bearerTokenSourceProvider),
      onLogin: onLogin,
      error: error,
    );
    created?.call(service);
    return service;
  }),
];
