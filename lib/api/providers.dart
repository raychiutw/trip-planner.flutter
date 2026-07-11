/// API 層 riverpod providers 與全域認證狀態。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import 'api_client.dart';
import 'auth_repository.dart';
import 'cache/cache_store.dart';
import 'collab_repository.dart';
import 'oauth/id_token.dart';
import 'oauth/oauth_config.dart';
import 'oauth/oauth_providers.dart';
import 'requests_repository.dart';
import 'route_repository.dart';
import 'session_store.dart';
import 'settings_store.dart';
import 'share_repository.dart';
import 'trip_repository.dart';

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SecureSettingsStore(),
);

/// 離線快取 store。預設記憶體版;app 於 main() override 成 SembastCacheStore。
final cacheStoreProvider = Provider<CacheStore>((ref) => InMemoryCacheStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    sessionStore: ref.watch(sessionStoreProvider),
    cacheStore: ref.watch(cacheStoreProvider),
    // 有設定 OAuth client 才走 Bearer(無 token 時 source 回 null → 仍 cookie);
    // 未設定則完全不接 → 維持 cookie 登入,零破壞。
    bearerSource: OAuthConfig.isConfigured
        ? ref.watch(bearerTokenSourceProvider)
        : null,
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    client: ref.watch(apiClientProvider),
    sessionStore: ref.watch(sessionStoreProvider),
  ),
);

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(client: ref.watch(apiClientProvider)),
);

/// 地圖道路折線查詢(`GET /api/route`)。
final routeRepositoryProvider = Provider<RouteRepository>(
  (ref) => RouteRepository(client: ref.watch(apiClientProvider)),
);

final requestsRepositoryProvider = Provider<RequestsRepository>(
  (ref) => RequestsRepository(client: ref.watch(apiClientProvider)),
);

final collabRepositoryProvider = Provider<CollabRepository>(
  (ref) => CollabRepository(client: ref.watch(apiClientProvider)),
);

final shareRepositoryProvider = Provider<ShareRepository>(
  (ref) => ShareRepository(client: ref.watch(apiClientProvider)),
);

/// 全域認證狀態：data(null)=未登入、data(user)=已登入、error=登入失敗。
class AuthNotifier extends AsyncNotifier<UserInfo?> {
  // 上次快取擁有者標記(存 cacheStore;隨 clear 一起清、登入後重建)。
  static const _cacheOwnerKey = '__cache_owner__';

  @override
  Future<UserInfo?> build() async {
    final user = await _resolveUser();
    await _enforceCacheOwner(user);
    return user;
  }

  Future<UserInfo?> _resolveUser() async {
    // OAuth 模式:有 id_token 就用其 claims 當身分(userinfo 不收 Bearer)。
    if (OAuthConfig.isConfigured) {
      final idToken =
          (await ref.watch(oauthTokenStoreProvider).read())?.idToken;
      if (idToken != null) {
        final claims = decodeIdTokenClaims(idToken);
        final email = claims['email'] as String?;
        if (email != null) {
          return UserInfo(
            id: claims['sub'] as String? ?? '',
            email: email,
            emailVerified: claims['email_verified'] == true,
            displayName: claims['name'] as String?,
          );
        }
      }
    }
    return ref.watch(authRepositoryProvider).currentUser();
  }

  /// 身分與上次快取擁有者不同(同裝置換帳號)→ 清離線快取 + 佇列,避免跨帳號外洩。
  /// 同一帳號(含重新登入)則保留快取與待同步佇列。登出的清除由 logout() 負責。
  Future<void> _enforceCacheOwner(UserInfo? user) async {
    if (user == null) return;
    final cache = ref.read(cacheStoreProvider);
    final ownerId = '${user.id}|${user.email}';
    final prev = (await cache.readResponse(_cacheOwnerKey))?.data;
    if (prev != null && prev != ownerId) {
      await cache.clear();
    }
    await cache.writeResponse(_cacheOwnerKey, ownerId);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email, password: password),
    );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    if (OAuthConfig.isConfigured) {
      await ref.read(oauthTokenStoreProvider).clear();
    }
    // 清離線快取,避免帳號間資料外洩。
    await ref.read(cacheStoreProvider).clear();
    state = const AsyncData(null);
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserInfo?>(
  AuthNotifier.new,
);
