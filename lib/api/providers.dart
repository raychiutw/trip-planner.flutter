/// API 層 riverpod providers 與全域認證狀態。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'auth_repository.dart';
import 'session_store.dart';
import 'trip_repository.dart';

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(sessionStore: ref.watch(sessionStoreProvider)),
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

/// 全域認證狀態：data(null)=未登入、data(user)=已登入、error=登入失敗。
class AuthNotifier extends AsyncNotifier<UserInfo?> {
  @override
  Future<UserInfo?> build() => ref.watch(authRepositoryProvider).currentUser();

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email, password: password),
    );
  }

  /// 註冊成功後把 signup 回應轉成最小 UserInfo，讓 router 立刻視為已登入。
  Future<SignupResult?> signup({
    required String email,
    required String password,
    String? displayName,
    String? invitationToken,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .signup(
            email: email,
            password: password,
            displayName: displayName,
            invitationToken: invitationToken,
          );
      state = AsyncData(
        UserInfo(
          id: result.userId,
          email: result.email,
          emailVerified: !result.requiresVerification,
        ),
      );
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserInfo?>(
  AuthNotifier.new,
);
