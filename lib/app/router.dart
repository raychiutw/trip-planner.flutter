/// 全 app 路由：StatefulShellRoute 4 branches + 認證 redirect。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/providers.dart';
import '../features/auth/account_flow_screens.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/favorites/add_to_trip/add_to_trip_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/favorites/explore/explore_screen.dart';
import '../features/invite/invite_screen.dart';
import '../features/map/global_map_screen.dart';
import '../features/map/map_adapter.dart';
import '../features/share/public_share_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/invalid_link_screen.dart';
import '../features/trip_detail/entry_action_route_screen.dart';
import '../features/trip_detail/entry_add_route_screen.dart';
import '../features/trip_detail/entry_edit_route_screen.dart';
import '../features/trip_detail/entry_poi_screen.dart';
import '../features/trip_detail/trip_notes_screen.dart';
import '../features/trip_detail/trip_print_screen.dart';
import '../features/trip_detail/trip_timeline_screen.dart';
import '../features/trips/audit/trip_audit_screen.dart';
import '../features/trips/collab/collab_screen.dart';
import '../features/trips/create/create_trip_screen.dart';
import '../features/trips/edit/edit_trip_screen.dart';
import '../features/trips/health/trip_health_screen.dart';
import '../features/trips/share/share_screen.dart';
import '../features/trips/trips_list_screen.dart';
import '../models/add_to_trip.dart';
import 'auth_redirect_policy.dart';
import 'legacy_aliases.dart';

final tripMapCanvasBuilderProvider = Provider<TripMapCanvasBuilder?>((ref) {
  return null;
});

/// app 路由（redirect 讀 authStateProvider；auth 變化經 refreshListenable 重算）。
final appRouterProvider = Provider<GoRouter>((ref) {
  final mapBuilder = ref.watch(tripMapCanvasBuilderProvider);
  // 橋接 authStateProvider 變化 → GoRouter 重新評估 redirect
  final authChangeNotifier = ValueNotifier<int>(0);
  ref.onDispose(authChangeNotifier.dispose);
  ref.listen(authStateProvider, (previous, next) {
    authChangeNotifier.value++;
  });

  final router = GoRouter(
    initialLocation: '/trips',
    errorBuilder: (context, state) => const InvalidLinkScreen(),
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      return authRedirect(
        isLoading: authState.isLoading,
        isLoggedIn: authState.value != null,
        uri: state.uri,
      );
    },
    routes: [
      // 登入頁在 shell 外（無底部導航）
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => WelcomeScreen(
          onLogin: () => context.go(loginLocationFromWelcome(state.uri)),
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignupScreen(
          invitationToken: state.uri.queryParameters['invitation'],
        ),
      ),
      GoRoute(
        path: '/signup/check-email',
        builder: (context, state) => EmailVerifyPendingScreen(
          email: state.uri.queryParameters['email'] ?? '',
          invitationError: state.uri.queryParameters['invitationError'],
        ),
      ),
      GoRoute(
        path: '/login/forgot',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/password/reset',
        builder: (context, state) => ResetPasswordScreen(
          key: ValueKey(state.uri.queryParameters['token'] ?? ''),
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/auth/verify-email',
        builder: (context, state) => VerifyEmailScreen(
          key: ValueKey(state.uri.queryParameters['token'] ?? ''),
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      // Web 舊路徑由一張表產生，帳號 sheet 來源由 query 指定。
      ...legacyAliasRoutes(),
      // 建立/編輯行程:shell 外全螢幕表單(避開 /trips/:tripId 衝突)
      GoRoute(
        path: '/new-trip',
        pageBuilder: (context, state) => const MaterialPage<void>(
          fullscreenDialog: true,
          child: CreateTripScreen(),
        ),
      ),
      GoRoute(
        path: '/edit-trip/:tripId',
        pageBuilder: (context, state) => MaterialPage<void>(
          fullscreenDialog: true,
          child: EditTripScreen(tripId: state.pathParameters['tripId']!),
        ),
      ),
      GoRoute(
        path: '/collab/:tripId',
        builder: (context, state) =>
            CollabScreen(tripId: state.pathParameters['tripId']!),
      ),
      GoRoute(
        path: '/share-trip/:tripId',
        builder: (context, state) =>
            ShareScreen(tripId: state.pathParameters['tripId']!),
      ),
      GoRoute(
        path: '/oauth/consent',
        builder: (context, state) =>
            const InvalidLinkScreen(message: '請返回原本的瀏覽器，從該處重新完成授權。'),
      ),
      GoRoute(
        path: '/invite',
        builder: (context, state) =>
            InviteScreen(token: state.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(
        path: '/s/:token',
        builder: (context, state) =>
            PublicShareScreen(token: state.pathParameters['token']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          showRootTab: isShellContentLocation(state.uri.path),
          accountPage: state.uri.queryParameters['account'],
          accountReturnLocation: withoutAccount(state.uri),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => ChatScreen(
                  key: const ValueKey('chat-root'),
                  initialTripId: state.uri.queryParameters['tripId'],
                  initialPrefill: state.uri.queryParameters['prefill'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trips',
                redirect: (context, state) => selectedTripAlias(state.uri),
                builder: (context, state) => const TripsListScreen(),
                routes: [
                  GoRoute(
                    path: ':tripId',
                    builder: (context, state) => AdaptiveTripDetail(
                      selectedTripId: state.pathParameters['tripId']!,
                      child: TripTimelineScreen(
                        tripId: state.pathParameters['tripId']!,
                        initialEntryId: entryFocusFromQuery(state.uri),
                        initialDayNum: dayFocusFromQuery(state.uri),
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'map',
                        redirect: (context, state) =>
                            rootMapAlias(state.pathParameters, state.uri),
                      ),
                      GoRoute(
                        path: 'notes',
                        builder: (context, state) => TripNotesScreen(
                          tripId: state.pathParameters['tripId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'print',
                        builder: (context, state) => TripPrintScreen(
                          tripId: state.pathParameters['tripId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'health',
                        builder: (context, state) => TripHealthScreen(
                          tripId: state.pathParameters['tripId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'audit',
                        builder: (context, state) => TripAuditScreen(
                          tripId: state.pathParameters['tripId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'entries/new',
                        builder: (context, state) => EntryAddRouteScreen(
                          tripId: state.pathParameters['tripId']!,
                          initialDayNum: int.tryParse(
                            state.uri.queryParameters['day'] ?? '',
                          ),
                          initialMode: _entryAddModeFromQuery(
                            state.uri.queryParameters['mode'],
                          ),
                          initialRegion: state.uri.queryParameters['region'],
                        ),
                      ),
                      GoRoute(
                        path: 'entries/:eid/edit',
                        builder: (context, state) => _entryRoute(
                          state,
                          (tripId, entryId) => EntryEditRouteScreen(
                            tripId: tripId,
                            entryId: entryId,
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'entries/:eid/copy',
                        builder: (context, state) => _entryRoute(
                          state,
                          (tripId, entryId) => EntryActionRouteScreen(
                            tripId: tripId,
                            entryId: entryId,
                            action: EntryRouteAction.copy,
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'entries/:eid/move',
                        builder: (context, state) => _entryRoute(
                          state,
                          (tripId, entryId) => EntryActionRouteScreen(
                            tripId: tripId,
                            entryId: entryId,
                            action: EntryRouteAction.move,
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'entries/:eid/pois',
                        builder: (context, state) => _entryRoute(
                          state,
                          (tripId, entryId) =>
                              EntryPoiScreen(tripId: tripId, entryId: entryId),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => GlobalMapScreen(
                  initialTripId: state.uri.queryParameters['tripId'],
                  initialEntryId: entryFocusFromQuery(state.uri),
                  initialDayNum: dayFocusFromQuery(state.uri),
                  mapBuilder: mapBuilder,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesScreen(),
                routes: [
                  GoRoute(
                    path: 'explore',
                    builder: (context, state) => const ExploreScreen(),
                  ),
                  GoRoute(
                    path: ':favoriteId/add-to-trip',
                    builder: (context, state) => AddToTripRouteScreen(
                      favoriteMode: true,
                      favoriteId: int.tryParse(
                        state.pathParameters['favoriteId'] ?? '',
                      ),
                      uri: state.uri,
                    ),
                  ),
                  GoRoute(
                    path: 'add-to-trip',
                    builder: (context, state) => AddToTripRouteScreen(
                      args: state.extra is AddToTripArgs
                          ? state.extra! as AddToTripArgs
                          : null,
                      uri: state.uri,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

EntryAddMode _entryAddModeFromQuery(
  String? value, {
  EntryAddMode fallback = EntryAddMode.custom,
}) {
  for (final mode in EntryAddMode.values) {
    if (value == mode.name) return mode;
  }
  return fallback;
}

/// 所有停留點操作共用的外部 ID 解析；無效值不進入資料畫面。
Widget _entryRoute(
  GoRouterState state,
  Widget Function(String tripId, int entryId) build,
) {
  final rawId = state.pathParameters['eid'];
  final entryId = rawId != null && RegExp(r'^[0-9]+$').hasMatch(rawId)
      ? int.tryParse(rawId)
      : null;
  if (entryId == null || entryId <= 0) return const InvalidLinkScreen();
  return build(state.pathParameters['tripId']!, entryId);
}
