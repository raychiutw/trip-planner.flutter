/// API 層 riverpod providers 與全域認證狀態。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/oauth_tokens.dart';
import '../models/user.dart';
import 'account_repository.dart';
import 'api_client.dart';
import 'auth_repository.dart';
import 'cache/cache_store.dart';
import 'collab_repository.dart';
import 'map_repository.dart';
import 'oauth/id_token.dart';
import 'oauth/oauth_config.dart';
import 'oauth/oauth_login_service.dart';
import 'oauth/oauth_token_store.dart';
import 'oauth/oauth_providers.dart';
import 'requests_repository.dart';
import 'reports_repository.dart';
import 'settings_store.dart';
import 'share_repository.dart';
import 'trip_repository.dart';

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => InMemorySettingsStore(),
);

/// 離線快取 store。預設記憶體版;app 於 main() override 成 DriftCacheStore。
final cacheStoreProvider = Provider<CacheStore>((ref) => InMemoryCacheStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    cacheStore: ref.watch(cacheStoreProvider),
    bearerSource: ref.watch(bearerTokenSourceProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(client: ref.watch(apiClientProvider)),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(client: ref.watch(apiClientProvider)),
);

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(client: ref.watch(apiClientProvider)),
);

final requestsRepositoryProvider = Provider<RequestsRepository>(
  (ref) => RequestsRepository(client: ref.watch(apiClientProvider)),
);

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(client: ref.watch(apiClientProvider)),
);

final collabRepositoryProvider = Provider<CollabRepository>(
  (ref) => CollabRepository(client: ref.watch(apiClientProvider)),
);

final mapRepositoryProvider = Provider<MapRepository>(
  (ref) => MapRepository(client: ref.watch(apiClientProvider)),
);

final shareRepositoryProvider = Provider<ShareRepository>(
  (ref) => ShareRepository(client: ref.watch(apiClientProvider)),
);

/// 受保護的登入憑證還沒解鎖(使用者取消或沒通過生物辨識)。
/// 登入畫面據此多提供「解鎖」入口。
final authLockedProvider = NotifierProvider<AuthLockedNotifier, bool>(
  AuthLockedNotifier.new,
);

class AuthLockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool locked) => state = locked;
}

/// 全域認證狀態：data(null)=未登入、data(user)=已登入、error=登入失敗。
class AuthNotifier extends AsyncNotifier<UserInfo?> {
  // 上次快取擁有者標記(存 cacheStore;隨 clear 一起清、登入後重建)。
  static const _cacheOwnerKey = '__cache_owner__';

  @override
  Future<UserInfo?> build() async {
    // refresh 被後端拒絕、憑證已清掉 → 回到未登入(離線快取保留,同一帳號重新登入還用得到)。
    final sub = ref.watch(bearerTokenSourceProvider).signedOut.listen((_) {
      if (ref.mounted) state = const AsyncData(null);
    });
    ref.onDispose(sub.cancel);

    final user = await _resolveUser();
    await _enforceCacheOwner(user);
    return user;
  }

  Future<UserInfo?> _resolveUser() async {
    final OAuthTokens? tokens;
    try {
      tokens = await ref.read(oauthTokenStoreProvider).read();
    } on TokenStoreLockedException {
      // 憑證在、但要通過生物辨識才讀得到:停在登入畫面等使用者解鎖。
      ref.read(authLockedProvider.notifier).set(true);
      return null;
    }
    ref.read(authLockedProvider.notifier).set(false);
    if (tokens == null) return null;

    // 有 id_token 就用其 claims 當身分(userinfo 不收 Bearer)。驗證未過必須落回
    // currentUser() —— id_token 是這條路徑唯一的身分來源,不驗就等於
    // 「secure storage 裡有什麼就信什麼」。
    final idToken = tokens.idToken;
    if (idToken != null) {
      final claims = verifiedIdTokenClaims(
        idToken,
        clientId: OAuthConfig.clientId,
      );
      final email = claims?['email'] as String?;
      if (claims != null && email != null) {
        return UserInfo(
          id: claims['sub'] as String? ?? '',
          email: email,
          emailVerified: claims['email_verified'] == true,
          displayName: claims['name'] as String?,
        );
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

  /// 用系統瀏覽器登入(PKCE)。使用者取消不算錯誤,維持未登入。
  Future<void> signInWithBrowser() async {
    state = const AsyncLoading();
    try {
      await ref.read(oauthLoginServiceProvider).login();
    } on OAuthLoginException catch (e, stack) {
      state = e.cancelled ? const AsyncData(null) : AsyncError(e, stack);
      return;
    }
    ref.read(authLockedProvider.notifier).set(false);
    state = await AsyncValue.guard(() async {
      final user = await _resolveUser();
      await _enforceCacheOwner(user);
      return user;
    });
  }

  /// 受保護的憑證解鎖:重新讀取一次(會跳出生物辨識)。
  Future<void> unlock() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _resolveUser();
      await _enforceCacheOwner(user);
      return user;
    });
  }

  /// PATCH /account/profile；畫面離開後仍由認證 owner 刷新帳號資料。
  Future<UserInfo> updateProfile({required String displayName}) async {
    final user = await ref
        .read(accountRepositoryProvider)
        .updateProfile(displayName: displayName);
    if (ref.mounted) ref.invalidateSelf();
    return user;
  }

  /// 登出:盡力撤銷 refresh token,再清本機憑證與離線資料。
  Future<void> logout() async {
    final store = ref.read(oauthTokenStoreProvider);
    try {
      final refresh = (await store.read())?.refreshToken;
      if (refresh != null) {
        await ref
            .read(oauthRepositoryProvider)
            .revokeToken(
              token: refresh,
              clientId: OAuthConfig.clientId,
              tokenTypeHint: 'refresh_token',
            );
      }
    } catch (_) {
      // 撤銷失敗不能擋住本機登出。
    }
    await _clearLocalAuth();
  }

  /// 帳號已由後端刪除，只清本機認證與離線資料，不再呼叫撤銷 API。
  Future<void> accountDeleted() => _clearLocalAuth();

  Future<void> _clearLocalAuth() async {
    await ref.read(oauthTokenStoreProvider).clear();
    // 清離線快取,避免帳號間資料外洩。
    await ref.read(cacheStoreProvider).clear();
    state = const AsyncData(null);
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserInfo?>(
  AuthNotifier.new,
);
