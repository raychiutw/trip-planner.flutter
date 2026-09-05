/// 全 app 路由：StatefulShellRoute 4 branches + 認證 redirect。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/providers.dart';
import '../features/auth/account_flow_screens.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/oauth_consent_screen.dart';
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
import '../models/oauth.dart';
import 'auth_redirect_policy.dart';
import 'legacy_aliases.dart';

final tripMapCanvasBuilderProvider = Provider<TripMapCanvasBuilder?>((ref) {
  return null;
});

/// app 路由（redirect 讀 authStateProvider；auth 變化經 refreshListenable 重算）。
final appRouterProvider = Provider<GoRouter>((ref) {
  final mapBuilder = ref.watch(tripMapCanvasBuilderProvider);
  late final GoRouter router;
  // 帳號 sheet 掛在「redirect 當下所在的 shell 內容頁」上;來源由目前 URL 決定,
  // 不靠 redirect 途中改寫的變數。
  String accountSheetOrigin() {
    final current = router.routerDelegate.currentConfiguration.uri;
    return isShellContentLocation(current.path)
        ? withoutAccount(current)
        : '/trips';
  }

  // 橋接 authStateProvider 變化 → GoRouter 重新評估 redirect
  final authChangeNotifier = ValueNotifier<int>(0);
  ref.onDispose(authChangeNotifier.dispose);
  ref.listen(authStateProvider, (previous, next) {
    authChangeNotifier.value++;
  });

  router = GoRouter(
    initialLocation: '/trips',
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      return authRedirect(
        isLoading: authState.isLoading,
        isLoggedIn: authState.value != null,
        uri: state.uri,
        matchedLocation: state.matchedLocation,
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
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/auth/verify-email',
        builder: (context, state) =>
            VerifyEmailScreen(token: state.uri.queryParameters['token'] ?? ''),
      ),
      // Web route aliases retained during Flutter porting.(表在 legacy_aliases.dart)
      ...legacyAliasRoutes(accountSheetOrigin: accountSheetOrigin),
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
        builder: (context, state) => OAuthConsentScreen(
          key: ValueKey(state.uri.toString()),
          request: OAuthConsentRequest.fromUri(state.uri),
        ),
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
                          initialMode: _entryAddMode(
                            state.uri.queryParameters['mode'],
                          ),
                          initialRegion: state.uri.queryParameters['region'],
                        ),
                      ),
                      GoRoute(
                        path: 'entries/:eid/edit',
                        builder: (context, state) => EntryEditRouteScreen(
                          tripId: state.pathParameters['tripId']!,
                          entryId: int.parse(state.pathParameters['eid']!),
                        ),
                      ),
                      GoRoute(
                        path: 'entries/:eid/copy',
                        builder: (context, state) => EntryActionRouteScreen(
                          tripId: state.pathParameters['tripId']!,
                          entryId: int.parse(state.pathParameters['eid']!),
                          action: EntryRouteAction.copy,
                        ),
                      ),
                      GoRoute(
                        path: 'entries/:eid/move',
                        builder: (context, state) => EntryActionRouteScreen(
                          tripId: state.pathParameters['tripId']!,
                          entryId: int.parse(state.pathParameters['eid']!),
                          action: EntryRouteAction.move,
                        ),
                      ),
                      GoRoute(
                        path: 'entries/:eid/pois',
                        builder: (context, state) => EntryPoiScreen(
                          tripId: state.pathParameters['tripId']!,
                          entryId: int.parse(state.pathParameters['eid']!),
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

/// query 的 mode 字串 → 畫面的 enum;不合法回 custom(與 alias 表的字串集合同步)。
EntryAddMode _entryAddMode(String? value) => EntryAddMode.values.firstWhere(
  (mode) => mode.name == value,
  orElse: () => EntryAddMode.custom,
);
