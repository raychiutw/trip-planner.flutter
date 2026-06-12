/// API 層 riverpod providers 與全域認證狀態。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import 'api_client.dart';
import 'auth_repository.dart';
import 'collab_repository.dart';
import 'oauth/id_token.dart';
import 'oauth/oauth_config.dart';
import 'oauth/oauth_providers.dart';
import 'requests_repository.dart';
import 'session_store.dart';
import 'share_repository.dart';
import 'trip_repository.dart';

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    sessionStore: ref.watch(sessionStoreProvider),
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
  @override
  Future<UserInfo?> build() async {
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
    state = const AsyncData(null);
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserInfo?>(
  AuthNotifier.new,
);
