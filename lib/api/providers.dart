/// API 層 riverpod providers 與全域認證狀態。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/oauth_tokens.dart';
import '../models/user.dart';
import 'account_repository.dart';
import 'ai_data_consent_repository.dart';
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
import 'oauth/stored_bearer_token_source.dart' show InvalidReason;
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
    clock: ref.watch(dpopClockProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(client: ref.watch(apiClientProvider)),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(client: ref.watch(apiClientProvider)),
);

final aiDataConsentRepositoryProvider = Provider<AiDataConsentRepository>(
  (ref) => AiDataConsentRepository(client: ref.watch(apiClientProvider)),
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

const _keptAccountKey = 'bio_login_kept_account';

/// 登出後保留的生物辨識登入所標示的帳號（顯示名稱或信箱，非機密，存偏好設定）；
/// 沒有保留則為 null。
final keptBiometricAccountProvider = FutureProvider<String?>((ref) async {
  try {
    final v = await ref.watch(settingsStoreProvider).read(_keptAccountKey);
    return (v == null || v.isEmpty) ? null : v;
  } catch (_) {
    return null;
  }
});

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

/// 保留的生物辨識登入憑證已失效，已清掉；登入頁顯示 [userMessage]。
class KeptCredentialInvalid implements Exception {
  const KeptCredentialInvalid(this.reason);
  final InvalidReason reason;

  String get userMessage => reason == InvalidReason.rejected
      ? '登入已失效，請用瀏覽器重新登入'
      : '生物辨識資料已變更，登入憑證已失效，請用瀏覽器重新登入';
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

  /// [explicit]：使用者主動登入／解鎖。冷啟動（false）遇到「登出後保留」的標記
  /// 視為已登出，不得讀憑證，否則受保護讀取會跳出驗證並悄悄把登出撤銷。
  Future<UserInfo?> _resolveUser({bool explicit = false}) async {
    if (!explicit && await _hasKeptAccount()) {
      await ref.read(bearerTokenSourceProvider).seal();
      return null;
    }
    final OAuthTokens? tokens;
    try {
      tokens = await ref.read(oauthTokenStoreProvider).read();
    } on TokenStoreLockedException {
      // 憑證在、但要通過生物辨識才讀得到:停在登入畫面等使用者解鎖。
      ref.read(authLockedProvider.notifier).set(true);
      return null;
    }
    ref.read(authLockedProvider.notifier).set(false);
    ref.read(bearerTokenSourceProvider).unseal();
    if (tokens == null) {
      await ref.read(bearerTokenSourceProvider).discardProofKey();
      return null;
    }

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
    await _setKeptAccount(null); // 已登入就不再有「保留的登入」
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
      final user = await _resolveUser(explicit: true);
      await _enforceCacheOwner(user);
      return user;
    });
  }

  /// 受保護的憑證解鎖:重新讀取一次(會跳出生物辨識)。保留的憑證若已失效
  /// （伺服器撤銷、生物特徵變更）會清掉並以 [KeptCredentialInvalid] 引導重新登入。
  Future<void> unlock() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final kept = await _hasKeptAccount();
      final user = await _resolveUser(explicit: true);
      if (kept) {
        final src = ref.read(bearerTokenSourceProvider);
        // 讀不到憑證又不是還沒解鎖：儲存層已因生物特徵變更把它清掉。
        final reason = user == null
            ? (ref.read(authLockedProvider) ? null : InvalidReason.keyLost)
            : await src.verify();
        if (reason != null) {
          await _setKeptAccount(null);
          throw KeptCredentialInvalid(reason);
        }
      }
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

  /// 登出。開啟生物辨識登入者（憑證受生物辨識保護）預設走「保留模式」：憑證與
  /// DPoP 金鑰一起留在手機上、**不呼叫伺服器端撤銷**（否則保留的憑證已失效），
  /// 登入頁改用生物辨識登入。[clear] 為 true 則一律撤銷並清掉（關閉生物辨識登入）。
  Future<void> logout({bool clear = false}) async {
    final store = ref.read(oauthTokenStoreProvider);
    final user = state.value;
    if (!clear &&
        user != null &&
        store.protection == TokenProtection.biometric) {
      await _keepForBiometricLogin(user);
      return;
    }
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

  /// 忘記這支手機：先嘗試伺服器端撤銷，不論成敗都清掉本機憑證、DPoP 金鑰與保留標記。
  /// 回傳 false 代表撤銷沒成功（離線或錯誤），呼叫端要提示使用者到網頁版確認。
  Future<bool> forgetThisPhone() async {
    var revoked = true;
    try {
      final refresh =
          (await ref.read(oauthTokenStoreProvider).read())?.refreshToken;
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
      revoked = false;
    }
    await _clearLocalAuth();
    return revoked;
  }

  Future<void> _keepForBiometricLogin(UserInfo user) async {
    try {
      await _setKeptAccount(
        user.displayName?.isNotEmpty == true ? user.displayName : user.email,
      );
      await ref.read(bearerTokenSourceProvider).seal();
      await ref.read(cacheStoreProvider).clear();
    } finally {
      state = const AsyncData(null);
    }
  }

  Future<bool> _hasKeptAccount() async {
    try {
      final v = await ref.read(settingsStoreProvider).read(_keptAccountKey);
      return v != null && v.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setKeptAccount(String? label) async {
    try {
      await ref.read(settingsStoreProvider).write(_keptAccountKey, label ?? '');
    } catch (_) {}
    if (ref.mounted) ref.invalidate(keptBiometricAccountProvider);
  }

  /// 帳號已由後端刪除，只清本機認證與離線資料，不再呼叫撤銷 API。
  Future<void> accountDeleted() => _clearLocalAuth();

  Future<void> _clearLocalAuth() async {
    unawaited(_setKeptAccount(null));
    try {
      await ref.read(bearerTokenSourceProvider).clear();
      // 清離線快取,避免帳號間資料外洩。
      await ref.read(cacheStoreProvider).clear();
    } finally {
      // 清除過程出錯也要回到未登入，不能讓使用者卡在已登入畫面。
      state = const AsyncData(null);
    }
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserInfo?>(
  AuthNotifier.new,
);

/// 這個帳號有沒有 local 密碼（沒有密碼的帳號不該顯示「變更密碼」）。
///
/// 目前**借用** `GET /account`（帳號刪除預覽）回的 `hasPassword`，後端沒有專屬端點；
/// 日後有的話只改這一處。取不到就當作沒有：呼叫端的入口列 loading／error 刻意不畫任何東西，
/// 只比對 `AsyncData(value: true)`。
///
/// 依「目前登入的使用者」重新取：登出後換另一個帳號登入，不能沿用上一個帳號的結果。
final accountHasPasswordProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(authStateProvider.select((s) => s.value?.id));
  if (userId == null) return false;
  final preview = await ref
      .watch(authRepositoryProvider)
      .fetchAccountDeletionPreview();
  return preview.hasPassword;
});
