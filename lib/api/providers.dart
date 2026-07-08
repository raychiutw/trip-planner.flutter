/// API 層 riverpod providers 與全域認證狀態。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'auth_repository.dart';
import 'offline_cache.dart';
import 'session_store.dart';
import 'trip_repository.dart';

/// Build-time API override.
///
/// Accepts either an origin (`http://127.0.0.1:8788`) or a full API base URL
/// (`http://127.0.0.1:8788/api`). Origin header always uses scheme/host/port.
const String kTriplineApiUrlOverride = String.fromEnvironment(
  'TRIPLINE_API_URL',
);

class ApiEndpointConfig {
  const ApiEndpointConfig({required this.origin, required this.apiBaseUrl});

  final String origin;
  final String apiBaseUrl;

  factory ApiEndpointConfig.fromApiUrl(String apiUrl) {
    final trimmed = apiUrl.trim();
    if (trimmed.isEmpty) {
      return const ApiEndpointConfig(
        origin: kTriplineOrigin,
        apiBaseUrl: '$kTriplineOrigin/api',
      );
    }

    final uri = Uri.parse(_trimTrailingSlashes(trimmed));
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(
        apiUrl,
        'apiUrl',
        'TRIPLINE_API_URL must be an absolute URL',
      );
    }
    if (uri.hasQuery || uri.hasFragment) {
      throw ArgumentError.value(
        apiUrl,
        'apiUrl',
        'TRIPLINE_API_URL must not include query or fragment',
      );
    }

    final hasPath = uri.pathSegments.any((segment) => segment.isNotEmpty);
    return ApiEndpointConfig(
      origin: uri.origin,
      apiBaseUrl: hasPath ? uri.toString() : '${uri.origin}/api',
    );
  }
}

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

final apiEndpointProvider = Provider<ApiEndpointConfig>(
  (ref) => ApiEndpointConfig.fromApiUrl(kTriplineApiUrlOverride),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final endpoint = ref.watch(apiEndpointProvider);
  return ApiClient(
    sessionStore: ref.watch(sessionStoreProvider),
    origin: endpoint.origin,
    apiBaseUrl: endpoint.apiBaseUrl,
  );
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    client: ref.watch(apiClientProvider),
    sessionStore: ref.watch(sessionStoreProvider),
  ),
);

final offlineCacheProvider = Provider<OfflineCache>(
  (ref) => FileOfflineCache(),
);

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(
    client: ref.watch(apiClientProvider),
    offlineCache: ref.watch(offlineCacheProvider),
  ),
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

  /// 更新帳號 profile，成功後同步刷新全域登入使用者狀態。
  Future<UserInfo> updateProfile({String? displayName}) async {
    final updatedUser = await ref
        .read(tripRepositoryProvider)
        .updateProfile(displayName: displayName);
    state = AsyncData(updatedUser);
    return updatedUser;
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserInfo?>(
  AuthNotifier.new,
);

String _trimTrailingSlashes(String value) {
  var end = value.length;
  while (end > 0 && value.codeUnitAt(end - 1) == 0x2f) {
    end--;
  }
  return value.substring(0, end);
}
