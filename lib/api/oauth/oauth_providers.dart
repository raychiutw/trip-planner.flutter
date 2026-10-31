/// OAuth 層 providers。bearerTokenSourceProvider 餵給 apiClientProvider;
/// 認證只走 PKCE 與 Bearer(ADR-0014)。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'oauth_config.dart';
import 'oauth_login_service.dart';
import 'oauth_repository.dart';
import 'oauth_token_store.dart';
import 'stored_bearer_token_source.dart';

/// 預設記憶體版；App 於 main() override 成 [SecureOAuthTokenStore]。
final oauthTokenStoreProvider = Provider<OAuthTokenStore>(
  (ref) => InMemoryOAuthTokenStore(),
);

final oauthRepositoryProvider = Provider<OAuthRepository>(
  (ref) => OAuthRepository(),
);

final bearerTokenSourceProvider = Provider<StoredBearerTokenSource>(
  (ref) => StoredBearerTokenSource(
    store: ref.watch(oauthTokenStoreProvider),
    repository: ref.watch(oauthRepositoryProvider),
    clientId: OAuthConfig.clientId,
  ),
);

final oauthLoginServiceProvider = Provider<OAuthLoginService>(
  (ref) => OAuthLoginService(
    repository: ref.watch(oauthRepositoryProvider),
    source: ref.watch(bearerTokenSourceProvider),
  ),
);
