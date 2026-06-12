/// OAuth 層 providers。bearerTokenSourceProvider 餵給 apiClientProvider(僅在
/// OAuthConfig.isConfigured 時啟用 → 否則 app 維持 cookie 登入,零破壞)。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart' show BearerTokenSource;
import 'oauth_config.dart';
import 'oauth_login_service.dart';
import 'oauth_repository.dart';
import 'oauth_token_store.dart';
import 'stored_bearer_token_source.dart';

/// OAuth 登入是否啟用(預設依 dart-define 的 client_id;測試可 override)。
final oauthEnabledProvider = Provider<bool>((ref) => OAuthConfig.isConfigured);

final oauthTokenStoreProvider = Provider<OAuthTokenStore>(
  (ref) => SecureOAuthTokenStore(),
);

final oauthRepositoryProvider = Provider<OAuthRepository>(
  (ref) => OAuthRepository(),
);

final bearerTokenSourceProvider = Provider<BearerTokenSource>(
  (ref) => StoredBearerTokenSource(
    store: ref.watch(oauthTokenStoreProvider),
    repository: ref.watch(oauthRepositoryProvider),
    clientId: OAuthConfig.clientId,
  ),
);

final oauthLoginServiceProvider = Provider<OAuthLoginService>(
  (ref) => OAuthLoginService(
    repository: ref.watch(oauthRepositoryProvider),
    store: ref.watch(oauthTokenStoreProvider),
  ),
);
