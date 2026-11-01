/// OAuth 層 providers。bearerTokenSourceProvider 餵給 apiClientProvider;
/// 認證只走 PKCE 與 Bearer(ADR-0014)。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dpop/dpop_clock.dart';
import '../dpop/proof_key_store.dart';
import 'oauth_config.dart';
import 'oauth_login_service.dart';
import 'oauth_repository.dart';
import 'oauth_token_store.dart';
import 'stored_bearer_token_source.dart';

/// 預設記憶體版；App 於 main() override 成 [SecureOAuthTokenStore]。
final oauthTokenStoreProvider = Provider<OAuthTokenStore>(
  (ref) => InMemoryOAuthTokenStore(),
);

/// DPoP 金鑰的保存。預設記憶體版；App 於 main() override 成
/// [FallbackProofKeyStore]（硬體優先，退軟體，ADR-0015）。
final proofKeyStoreProvider = Provider<ProofKeyStore>(
  (ref) => InMemoryProofKeyStore(),
);

/// 手機與伺服器的時差，token 端點與 API 請求共用（DPoP proof 的 `iat`）。
final dpopClockProvider = Provider<DpopClock>((ref) => DpopClock());

final oauthRepositoryProvider = Provider<OAuthRepository>(
  (ref) => OAuthRepository(clock: ref.watch(dpopClockProvider)),
);

final bearerTokenSourceProvider = Provider<StoredBearerTokenSource>(
  (ref) => StoredBearerTokenSource(
    store: ref.watch(oauthTokenStoreProvider),
    repository: ref.watch(oauthRepositoryProvider),
    clientId: OAuthConfig.clientId,
    proofKeys: ref.watch(proofKeyStoreProvider),
  ),
);

/// 預設是不可用的啟動器；App 於 main() override 成 `WebAuthLauncher`。
final authorizationLauncherProvider = Provider<AuthorizationLauncher>(
  (ref) => const UnavailableAuthorizationLauncher(),
);

final oauthLoginServiceProvider = Provider<OAuthLoginService>(
  (ref) => OAuthLoginService(
    launcher: ref.watch(authorizationLauncherProvider),
    repository: ref.watch(oauthRepositoryProvider),
    source: ref.watch(bearerTokenSourceProvider),
    proofKeys: ref.watch(proofKeyStoreProvider),
  ),
);
