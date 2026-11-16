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

/// 舊版留下的「登出後保留」標記；讀不到視為沒有。
Future<bool> _hasLegacyKeptMarker(Ref ref) async {
  try {
    return await ref.read(oauthTokenStoreProvider).hasLegacyKeptMarker();
  } catch (_) {
    return false;
  }
}

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

/// 「登入憑證剛通過一次系統驗證」的事件（每發一次加 1）。**只有 [AuthNotifier] 寫入**，
/// 訂閱者（App 鎖）收到就不必再要求第二次驗證；不要另外推斷時序。
/// 計數器永不歸零：只在 App 鎖建立與非同步載入設定時讀（見 `AppLockController`）；
/// 登出時 App 鎖會被關掉，所以不會沿用到下一次登入。`appLockProvider` 目前不會被重建，
/// 若日後改成 autoDispose 或 invalidate，這個假設要重新檢查。
final credentialVerifiedProvider =
    NotifierProvider<CredentialVerifiedNotifier, int>(
      CredentialVerifiedNotifier.new,
    );

class CredentialVerifiedNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void emit() => state++;
}

/// 全域認證狀態：data(null)=未登入、data(user)=已登入、error=登入失敗。
class AuthNotifier extends AsyncNotifier<UserInfo?> {
  // 上次快取擁有者標記(存 cacheStore;隨 clear 一起清、登入後重建)。
  static const _cacheOwnerKey = '__cache_owner__';

  // 冷啟動只有第一次 build 算；自己記，不靠 AsyncNotifier 重建時保留舊值的語意
  //（build 失敗重試、state 被設成 AsyncLoading 都會讓 state.hasValue 誤判）。
  bool _coldStartDone = false;

  /// 這次還原或解鎖時發現憑證不能用而清掉的原因（給 [unlock] 回報）。
  InvalidReason? _invalid;

  @override
  Future<UserInfo?> build() async {
    // refresh 被後端拒絕、憑證已清掉 → 回到未登入(離線快取保留,同一帳號重新登入還用得到)。
    final sub = ref.watch(bearerTokenSourceProvider).signedOut.listen((_) {
      if (ref.mounted) state = const AsyncData(null);
    });
    ref.onDispose(sub.cancel);

    // 第一次 build 才是冷啟動；之後 invalidate 重建時憑證在快取裡，不會有新的系統驗證。
    final coldStart = !_coldStartDone;
    _coldStartDone = true;
    final user = await _resolveUser(coldStart: coldStart);
    await _enforceCacheOwner(user);
    return user;
  }

  /// [explicit]：使用者主動登入／解鎖。[coldStart]：冷啟動第一次還原。
  Future<UserInfo?> _resolveUser({
    bool explicit = false,
    bool coldStart = false,
  }) async {
    // 舊版登出後保留的憑證（ADR-0019 遷移）：不讀（會跳生物辨識）、不撤銷，直接刪掉
    // 憑證、DPoP 金鑰與標記，回到未登入。伺服器端那份最多 30 天後自行失效。
    if (!explicit && await _hasLegacyKeptMarker(ref)) {
      try {
        await ref.read(bearerTokenSourceProvider).clear();
      } catch (_) {}
      return null;
    }
    final wasLocked = ref.read(authLockedProvider);
    final OAuthTokens? tokens;
    try {
      tokens = await ref.read(oauthTokenStoreProvider).read();
    } on TokenStoreLockedException {
      // 憑證在、但要通過生物辨識才讀得到:停在登入畫面等使用者解鎖。
      ref.read(authLockedProvider.notifier).set(true);
      return null;
    }
    ref.read(authLockedProvider.notifier).set(false);
    if (tokens == null) {
      // 剛才還鎖著（憑證在）卻讀出空的：受保護讀取時系統回報項目失效（生物特徵變更），
      // 儲存層已自行清掉。
      if (wasLocked) _invalid = InvalidReason.keyLost;
      await ref.read(bearerTokenSourceProvider).discardProofKey();
      return null;
    }
    // 剛解開的憑證必然剛通過一次系統驗證：從鎖定解開，或冷啟動讀取生物辨識保護的憑證。
    // 一定要有憑證才發：沒有憑證時沒有東西被驗證過。
    if (wasLocked ||
        (coldStart &&
            ref.read(oauthTokenStoreProvider).protection ==
                TokenProtection.biometric)) {
      // 先發事件再 refresh：App 鎖不必等網路，也不會在 refresh 期間再跳一次驗證。
      ref.read(credentialVerifiedProvider.notifier).emit();
      // 通過即 refresh（ADR-0019）：憑證不能用就在這裡清掉，不先進「我的行程」再被踢出。
      final invalid = await _verifyCredential();
      if (invalid != null) {
        _invalid = invalid;
        return null;
      }
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

  /// 立刻 refresh 一次，回傳憑證是否因此失效並被清掉。其他錯誤（網路、非預期）
  /// 一律當暫時性：保留憑證照常登入，之後的請求會再試。
  Future<InvalidReason?> _verifyCredential() async {
    try {
      return await ref.read(bearerTokenSourceProvider).verify();
    } catch (_) {
      return null;
    }
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
  /// 回傳 callback 是否要求開啟生物辨識登入（由呼叫端決定如何處理）。
  Future<bool> signInWithBrowser({String? biometricHint}) async {
    state = const AsyncLoading();
    final OAuthLoginResult result;
    try {
      result = await ref
          .read(oauthLoginServiceProvider)
          .login(biometricHint: biometricHint);
    } on OAuthLoginException catch (e, stack) {
      state = e.cancelled ? const AsyncData(null) : AsyncError(e, stack);
      return false;
    }
    ref.read(authLockedProvider.notifier).set(false);
    state = await AsyncValue.guard(() async {
      final user = await _resolveUser(explicit: true);
      await _enforceCacheOwner(user);
      return user;
    });
    return result.enableBiometric;
  }

  /// 受保護的憑證解鎖:重新讀取一次(會跳出生物辨識)，通過即 refresh。
  /// 回傳非 null 代表憑證已失效（refresh 被拒、生物特徵變更）並已清掉，
  /// 呼叫端要改走 web 登入（ADR-0019）；取消或失敗回 null，憑證仍在。
  Future<InvalidReason?> unlock() async {
    _invalid = null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _resolveUser(explicit: true);
      await _enforceCacheOwner(user);
      return user;
    });
    return _invalid;
  }

  /// PATCH /account/profile；畫面離開後仍由認證 owner 刷新帳號資料。
  Future<UserInfo> updateProfile({required String displayName}) async {
    final user = await ref
        .read(accountRepositoryProvider)
        .updateProfile(displayName: displayName);
    if (ref.mounted) ref.invalidateSelf();
    return user;
  }

  /// 登出：不論有沒有開啟生物辨識登入，都先嘗試伺服器端撤銷，再清掉本機憑證、
  /// DPoP 金鑰與離線快取（ADR-0019）。撤銷失敗（離線、伺服器錯誤）不能擋住本機登出。
  Future<void> logout() async {
    await _tryRevoke();
    await _clearLocalAuth();
  }

  Future<bool> _tryRevoke() =>
      _revokeRefreshToken().then((_) => true, onError: (_) => false);

  /// 伺服器端撤銷目前的 refresh token（沒有憑證就什麼都不做）；失敗丟例外。
  Future<void> _revokeRefreshToken() async {
    final refresh =
        (await ref.read(oauthTokenStoreProvider).read())?.refreshToken;
    if (refresh == null) return;
    await ref
        .read(oauthRepositoryProvider)
        .revokeToken(
          token: refresh,
          clientId: OAuthConfig.clientId,
          tokenTypeHint: 'refresh_token',
        );
  }

  /// 帳號已由後端刪除，只清本機認證與離線資料，不再呼叫撤銷 API。
  Future<void> accountDeleted() => _clearLocalAuth();

  Future<void> _clearLocalAuth() async {
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
