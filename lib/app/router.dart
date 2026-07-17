/// 全 app 路由：StatefulShellRoute 5 branches + 認證 redirect。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/providers.dart';
import '../features/account/account_sessions_screen.dart';
import '../features/account/account_screen.dart';
import '../features/account/connected_apps_screen.dart';
import '../features/account/developer_apps_screen.dart';
import '../features/account/settings/appearance_screen.dart';
import '../features/account/settings/notifications_screen.dart';
import '../features/account/settings/profile_edit_screen.dart';
import '../features/auth/account_flow_screens.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/oauth_consent_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/favorites/add_to_trip/add_to_trip_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/favorites/explore/explore_screen.dart';
import '../features/invite/invite_screen.dart';
import '../features/map/global_map_screen.dart';
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

/// app 路由（redirect 讀 authStateProvider；auth 變化經 refreshListenable 重算）。
final appRouterProvider = Provider<GoRouter>((ref) {
  // 橋接 authStateProvider 變化 → GoRouter 重新評估 redirect
  final authChangeNotifier = ValueNotifier<int>(0);
  ref.onDispose(authChangeNotifier.dispose);
  ref.listen(authStateProvider, (previous, next) {
    authChangeNotifier.value++;
  });

  final router = GoRouter(
    initialLocation: '/trips',
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      // 認證狀態尚未解析時不 redirect，避免閃跳
      if (authState.isLoading) return null;

      final isLoggedIn = authState.value != null;
      final isOnLogin = state.matchedLocation == '/login';
      final isPublicRoute = _isPublicShellOutsideRoute(state);
      if (!isLoggedIn && !isOnLogin && !isPublicRoute) {
        return _loginLocationWithRedirect(state);
      }
      if (isLoggedIn && isOnLogin) return _redirectAfterLogin(state);
      return null;
    },
    routes: [
      // 登入頁在 shell 外（無底部導航）
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
      // Web route aliases retained during Flutter porting.
      GoRoute(path: '/admin', redirect: (context, state) => '/trips'),
      GoRoute(path: '/manage', redirect: (context, state) => '/chat'),
      GoRoute(path: '/trips/new', redirect: (context, state) => '/new-trip'),
      GoRoute(
        path: '/explore',
        redirect: (context, state) => '/favorites/explore',
      ),
      GoRoute(
        path: '/add-to-trip',
        redirect: (context, state) =>
            _withQuery('/favorites/add-to-trip', state),
      ),
      GoRoute(
        path: '/account/appearance',
        redirect: (context, state) => '/settings/appearance',
      ),
      GoRoute(
        path: '/account/sessions',
        redirect: (context, state) => '/settings/sessions',
      ),
      GoRoute(
        path: '/account/connected-apps',
        redirect: (context, state) => '/settings/connected-apps',
      ),
      GoRoute(
        path: '/trip/:tripId',
        redirect: (context, state) => _tripAlias(state),
      ),
      GoRoute(
        path: '/trip/:tripId/map',
        redirect: (context, state) => _tripAlias(state, '/map'),
      ),
      GoRoute(
        path: '/trip/:tripId/add-entry',
        redirect: (context, state) =>
            _newEntryAlias(state, mode: EntryAddMode.search),
      ),
      GoRoute(
        path: '/trip/:tripId/add-stop',
        redirect: (context, state) => _newEntryAlias(
          state,
          mode: _entryAddModeFromQuery(
            state.uri.queryParameters['tab'],
            fallback: EntryAddMode.search,
          ),
        ),
      ),
      GoRoute(
        path: '/trip/:tripId/add-custom-stop',
        redirect: (context, state) =>
            _newEntryAlias(state, mode: EntryAddMode.custom),
      ),
      GoRoute(
        path: '/trip/:tripId/stop/:entryId',
        redirect: (context, state) => _entryTimelineAlias(state),
      ),
      GoRoute(
        path: '/trip/:tripId/stop/:entryId/map',
        redirect: (context, state) => _entryMapAlias(state),
      ),
      GoRoute(
        path: '/trip/:tripId/stop/:entryId/edit',
        redirect: (context, state) {
          final tripId = Uri.encodeComponent(state.pathParameters['tripId']!);
          final entryId = Uri.encodeComponent(state.pathParameters['entryId']!);
          return '/trips/$tripId/entries/$entryId/edit';
        },
      ),
      GoRoute(
        path: '/trip/:tripId/stop/:entryId/change-poi',
        redirect: (context, state) {
          final tripId = Uri.encodeComponent(state.pathParameters['tripId']!);
          final entryId = Uri.encodeComponent(state.pathParameters['entryId']!);
          return '/trips/$tripId/entries/$entryId/pois';
        },
      ),
      GoRoute(
        path: '/trip/:tripId/stop/:entryId/copy',
        redirect: (context, state) {
          final tripId = Uri.encodeComponent(state.pathParameters['tripId']!);
          final entryId = Uri.encodeComponent(state.pathParameters['entryId']!);
          return '/trips/$tripId/entries/$entryId/copy';
        },
      ),
      GoRoute(
        path: '/trip/:tripId/stop/:entryId/move',
        redirect: (context, state) {
          final tripId = Uri.encodeComponent(state.pathParameters['tripId']!);
          final entryId = Uri.encodeComponent(state.pathParameters['entryId']!);
          return '/trips/$tripId/entries/$entryId/move';
        },
      ),
      GoRoute(
        path: '/trip/:tripId/notes',
        redirect: (context, state) => _tripAlias(state, '/notes'),
      ),
      GoRoute(
        path: '/trip/:tripId/print',
        redirect: (context, state) => _tripAlias(state, '/print'),
      ),
      GoRoute(
        path: '/trip/:tripId/health',
        redirect: (context, state) => _tripAlias(state, '/health'),
      ),
      GoRoute(
        path: '/trip/:tripId/audit',
        redirect: (context, state) => _tripAlias(state, '/audit'),
      ),
      GoRoute(
        path: '/trip/:tripId/collab',
        redirect: (context, state) => _outsideTripAlias(state, '/collab'),
      ),
      GoRoute(
        path: '/trip/:tripId/edit',
        redirect: (context, state) => _outsideTripAlias(state, '/edit-trip'),
      ),
      // 建立/編輯行程:shell 外全螢幕表單(避開 /trips/:tripId 衝突)
      GoRoute(
        path: '/new-trip',
        builder: (context, state) => const CreateTripScreen(),
      ),
      GoRoute(
        path: '/edit-trip/:tripId',
        builder: (context, state) =>
            EditTripScreen(tripId: state.pathParameters['tripId']!),
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
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (context, state) => const AppearanceScreen(),
      ),
      GoRoute(
        path: '/settings/profile',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/account/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings/sessions',
        builder: (context, state) => const AccountSessionsScreen(),
      ),
      GoRoute(
        path: '/settings/connected-apps',
        builder: (context, state) => const ConnectedAppsScreen(),
      ),
      GoRoute(
        path: '/settings/developer-apps',
        builder: (context, state) => const DeveloperAppsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const DeveloperAppNewScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/developer/apps',
        builder: (context, state) => const DeveloperAppsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const DeveloperAppNewScreen(),
          ),
        ],
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
          showRootTab: _isRootTabLocation(state.uri.path),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => ChatScreen(
                  key: ValueKey(state.uri.toString()),
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
                redirect: (context, state) => _selectedTripAlias(state),
                builder: (context, state) => const TripsListScreen(),
                routes: [
                  GoRoute(
                    path: ':tripId',
                    builder: (context, state) => TripTimelineScreen(
                      tripId: state.pathParameters['tripId']!,
                      initialEntryId: _entryFocusFromQuery(state.uri),
                      initialDayNum: _dayFocusFromQuery(state.uri),
                    ),
                    routes: [
                      GoRoute(
                        path: 'map',
                        redirect: (context, state) => _rootMapAlias(state),
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
                  initialEntryId: _entryFocusFromQuery(state.uri),
                  initialDayNum: _dayFocusFromQuery(state.uri),
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

const _publicShellOutsideRoutes = {
  '/login',
  '/signup',
  '/signup/check-email',
  '/login/forgot',
  '/auth/password/reset',
  '/auth/verify-email',
  '/oauth/consent',
  '/invite',
};

String _tripAlias(GoRouterState state, [String suffix = '']) {
  final tripId = Uri.encodeComponent(state.pathParameters['tripId']!);
  return '/trips/$tripId$suffix';
}

String _outsideTripAlias(GoRouterState state, String prefix) {
  final tripId = Uri.encodeComponent(state.pathParameters['tripId']!);
  return '$prefix/$tripId';
}

String _newEntryAlias(GoRouterState state, {required EntryAddMode mode}) {
  final tripId = Uri.encodeComponent(state.pathParameters['tripId']!);
  final query = Map<String, String>.from(state.uri.queryParameters)
    ..remove('tab');
  query['mode'] = mode.name;
  return Uri(
    path: '/trips/$tripId/entries/new',
    queryParameters: query,
  ).toString();
}

String _entryMapAlias(GoRouterState state) {
  final tripId = Uri.encodeComponent(state.pathParameters['tripId']!);
  final query = Map<String, String>.from(state.uri.queryParameters);
  query['entry'] = state.pathParameters['entryId']!;
  return Uri(path: '/trips/$tripId/map', queryParameters: query).toString();
}

String _rootMapAlias(GoRouterState state) {
  final query = Map<String, String>.from(state.uri.queryParameters);
  query['tripId'] = state.pathParameters['tripId']!;
  return Uri(path: '/map', queryParameters: query).toString();
}

String _entryTimelineAlias(GoRouterState state) {
  final tripId = Uri.encodeComponent(state.pathParameters['tripId']!);
  final query = Map<String, String>.from(state.uri.queryParameters);
  query['entry'] = state.pathParameters['entryId']!;
  return Uri(path: '/trips/$tripId', queryParameters: query).toString();
}

String? _selectedTripAlias(GoRouterState state) {
  final selected = state.uri.queryParameters['selected'];
  if (selected == null || !RegExp(r'^[\w-]+$').hasMatch(selected)) {
    return null;
  }
  final query = Map<String, String>.from(state.uri.queryParameters)
    ..remove('selected');
  final focus = query.remove('focus');
  if (focus != null && int.tryParse(focus) != null) {
    query['entry'] = focus;
  }
  return Uri(
    path: '/trips/${Uri.encodeComponent(selected)}',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

int? _entryFocusFromQuery(Uri uri) {
  return int.tryParse(uri.queryParameters['entry'] ?? '');
}

int? _dayFocusFromQuery(Uri uri) {
  return int.tryParse(uri.queryParameters['day'] ?? '');
}

EntryAddMode _entryAddModeFromQuery(
  String? value, {
  EntryAddMode fallback = EntryAddMode.custom,
}) {
  for (final mode in EntryAddMode.values) {
    if (value == mode.name) return mode;
  }
  return fallback;
}

String _withQuery(String path, GoRouterState state) {
  final query = state.uri.query;
  return query.isEmpty ? path : '$path?$query';
}

String _loginLocationWithRedirect(GoRouterState state) {
  final requestedLocation = state.uri.toString();
  if (requestedLocation == '/trips') return '/login';
  return '/login?redirect_after=${Uri.encodeComponent(requestedLocation)}';
}

String _redirectAfterLogin(GoRouterState state) {
  final rawRedirect = state.uri.queryParameters['redirect_after'];
  if (rawRedirect == null) return '/trips';

  final redirectUri = Uri.tryParse(rawRedirect);
  if (redirectUri == null ||
      redirectUri.hasScheme ||
      redirectUri.hasAuthority ||
      !rawRedirect.startsWith('/') ||
      rawRedirect.startsWith('//') ||
      redirectUri.path == '/login') {
    return '/trips';
  }
  return redirectUri.toString();
}

bool _isPublicShellOutsideRoute(GoRouterState state) {
  if (_publicShellOutsideRoutes.contains(state.matchedLocation)) return true;
  final pathSegments = state.uri.pathSegments;
  return pathSegments.length == 2 && pathSegments.first == 's';
}

bool _isRootTabLocation(String path) {
  if (path == '/chat' ||
      path == '/trips' ||
      path == '/map' ||
      path == '/favorites') {
    return true;
  }
  final segments = Uri.parse(path).pathSegments;
  return segments.length == 2 && segments.first == 'trips';
}
