import 'package:flutter/services.dart' show MissingPluginException;
import 'package:tripline/api/api_client.dart';
import 'package:tripline/app/app_lock.dart' show biometricAuthenticatorProvider;
import 'fake_biometric.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/models/oauth_tokens.dart';

/// 測試用的瀏覽器登入：不開瀏覽器，直接把一組憑證交給憑證來源，
/// 之後身分由（被 mock 的）`currentUser()` 解析。
class FakeOAuthLoginService implements OAuthLoginService {
  FakeOAuthLoginService(
    this._source, {
    this.onLogin,
    this.error,
    this.enableIntent = false,
  });

  final StoredBearerTokenSource _source;
  final void Function()? onLogin;
  final Object? error;

  /// 模擬 callback 帶 `biometric_intent=enable`。
  final bool enableIntent;
  int calls = 0;
  String? lastHint;

  @override
  Future<OAuthTokens> login({
    String? biometricHint,
    void Function()? onEnableIntent,
  }) async {
    calls++;
    lastHint = biometricHint;
    onLogin?.call();
    if (error != null) throw error!;
    final tokens = OAuthTokens(
      accessToken: 'AT',
      refreshToken: 'RT',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
    await _source.adopt(tokens);
    if (enableIntent) onEnableIntent?.call();
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
  bool enableIntent = false,

  /// 登入入口會先問生物辨識種類；真平台通道在 widget test 不會於 pump 內完成，
  /// 預設換成假的。測試自己已 override 時傳 false，避免重複 override。
  bool stubBiometric = true,
}) => [
  if (stubBiometric)
    biometricAuthenticatorProvider.overrideWithValue(
      FakeBiometricAuthenticator(kind: null),
    ),
  oauthLoginServiceProvider.overrideWith((ref) {
    final service = FakeOAuthLoginService(
      ref.watch(bearerTokenSourceProvider),
      onLogin: onLogin,
      error: error,
      enableIntent: enableIntent,
    );
    created?.call(service);
    return service;
  }),
];

/// 取憑證就丟例外的來源：讓「忘了 stub 的 API 呼叫」像沒有平台通道時一樣失敗，
/// 而不是真的打網路（測試環境的 HttpClient 會回 400，變成頁面上的 ApiError）。
class _ThrowingBearerSource implements BearerTokenSource {
  @override
  Future<String?> accessToken() async =>
      throw MissingPluginException('測試環境沒有 stub 這個 API 呼叫');

  @override
  Future<bool> refresh() async => false;
}

/// 預設的 ApiClient 換成「任何請求都失敗」的版本，供沒 stub 網路的畫面測試使用。
dynamic get unstubbedApiClientOverride => apiClientProvider.overrideWithValue(
  ApiClient(bearerSource: _ThrowingBearerSource()),
);

/// 不連網的 OAuthRepository：只記錄被撤銷的 token。
class RecordingOAuthRepository implements OAuthRepository {
  final revoked = <String>[];

  @override
  Future<void> revokeToken({
    required String token,
    required String clientId,
    String? tokenTypeHint,
    String? clientSecret,
  }) async => revoked.add(token);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 已登入狀態：有憑證的 store，加上不連網的 OAuthRepository。
List<dynamic> signedInOverrides({
  InMemoryOAuthTokenStore? store,
  RecordingOAuthRepository? repo,
}) => [
  oauthTokenStoreProvider.overrideWithValue(store ?? signedInTokenStore()),
  oauthRepositoryProvider.overrideWithValue(repo ?? RecordingOAuthRepository()),
];
