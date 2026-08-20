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

final tripMapCanvasBuilderProvider = Provider<TripMapCanvasBuilder?>((ref) {
  return null;
});

/// app 路由（redirect 讀 authStateProvider；auth 變化經 refreshListenable 重算）。
final appRouterProvider = Provider<GoRouter>((ref) {
  final mapBuilder = ref.watch(tripMapCanvasBuilderProvider);
  var accountSheetOrigin = '/trips';
  String accountSheetAlias(GoRouterState state, String page) =>
      _accountSheetLocation(accountSheetOrigin, state, page);
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
      if (_isShellContentLocation(state.uri.path) &&
          !state.uri.queryParameters.containsKey('account')) {
        accountSheetOrigin = state.uri.toString();
      }
      final authState = ref.read(authStateProvider);
      // 認證狀態尚未解析時不 redirect，避免閃跳
      if (authState.isLoading) return null;

      final isLoggedIn = authState.value != null;
      final isOnLogin = state.matchedLocation == '/login';
      final isOnWelcome = state.matchedLocation == '/welcome';
      final isPublicRoute = _isPublicShellOutsideRoute(state);
      if (!isLoggedIn && !isOnLogin && !isPublicRoute) {
        return _welcomeLocationWithRedirect(state);
      }
      if (isLoggedIn && (isOnLogin || isOnWelcome)) {
        return _redirectAfterLogin(state);
      }
      return null;
    },
    routes: [
      // 登入頁在 shell 外（無底部導航）
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => WelcomeScreen(
          onLogin: () => context.go(_loginLocationFromWelcome(state)),
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
        path: '/account',
        redirect: (context, state) => accountSheetAlias(state, 'root'),
      ),
      GoRoute(
        path: '/account/appearance',
        redirect: (context, state) => accountSheetAlias(state, 'appearance'),
      ),
      GoRoute(
        path: '/account/sessions',
        redirect: (context, state) => accountSheetAlias(state, 'sessions'),
      ),
      GoRoute(
        path: '/account/connected-apps',
        redirect: (context, state) =>
            accountSheetAlias(state, 'connected-apps'),
      ),
      GoRoute(
        path: '/account/notifications',
        redirect: (context, state) => accountSheetAlias(state, 'notifications'),
      ),
      GoRoute(
        path: '/settings/appearance',
        redirect: (context, state) => accountSheetAlias(state, 'appearance'),
      ),
      GoRoute(
        path: '/settings/profile',
        redirect: (context, state) => accountSheetAlias(state, 'profile'),
      ),
      GoRoute(
        path: '/settings/notifications',
        redirect: (context, state) => accountSheetAlias(state, 'notifications'),
      ),
      GoRoute(
        path: '/settings/sessions',
        redirect: (context, state) => accountSheetAlias(state, 'sessions'),
      ),
      GoRoute(
        path: '/settings/connected-apps',
        redirect: (context, state) =>
            accountSheetAlias(state, 'connected-apps'),
      ),
      GoRoute(
        path: '/settings/developer-apps',
        redirect: (context, state) =>
            accountSheetAlias(state, 'developer-apps'),
      ),
      GoRoute(
        path: '/settings/developer-apps/new',
        redirect: (context, state) =>
            accountSheetAlias(state, 'developer-apps/new'),
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
        path: '/developer/apps',
        redirect: (context, state) =>
            accountSheetAlias(state, 'developer-apps'),
      ),
      GoRoute(
        path: '/developer/apps/new',
        redirect: (context, state) =>
            accountSheetAlias(state, 'developer-apps/new'),
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
          showRootTab: _isShellContentLocation(state.uri.path),
          accountPage: state.uri.queryParameters['account'],
          accountReturnLocation: _withoutAccount(state.uri),
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
                redirect: (context, state) => _selectedTripAlias(state),
                builder: (context, state) => const TripsListScreen(),
                routes: [
                  GoRoute(
                    path: ':tripId',
                    builder: (context, state) => AdaptiveTripDetail(
                      selectedTripId: state.pathParameters['tripId']!,
                      child: TripTimelineScreen(
                        tripId: state.pathParameters['tripId']!,
                        initialEntryId: _entryFocusFromQuery(state.uri),
                        initialDayNum: _dayFocusFromQuery(state.uri),
                      ),
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

const _publicShellOutsideRoutes = {
  '/welcome',
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

String _accountSheetLocation(
  String originLocation,
  GoRouterState state,
  String page,
) {
  final origin = Uri.parse(originLocation);
  final query = <String, String>{
    ...origin.queryParameters,
    ...state.uri.queryParameters,
  };
  query['account'] = page;
  return origin.replace(queryParameters: query).toString();
}

String _withoutAccount(Uri uri) {
  final query = Map<String, String>.from(uri.queryParameters)
    ..remove('account');
  return Uri(
    path: uri.path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

String _welcomeLocationWithRedirect(GoRouterState state) {
  final requestedLocation = state.uri.toString();
  if (requestedLocation == '/trips') return '/welcome';
  return '/welcome?redirect_after=${Uri.encodeComponent(requestedLocation)}';
}

String _loginLocationFromWelcome(GoRouterState state) {
  final redirectAfter = _redirectAfterLogin(state);
  if (redirectAfter == '/trips') return '/login';
  return '/login?redirect_after=${Uri.encodeComponent(redirectAfter)}';
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
      redirectUri.path == '/login' ||
      redirectUri.path == '/welcome') {
    return '/trips';
  }
  return redirectUri.toString();
}

bool _isPublicShellOutsideRoute(GoRouterState state) {
  if (_publicShellOutsideRoutes.contains(state.matchedLocation)) return true;
  final pathSegments = state.uri.pathSegments;
  return pathSegments.length == 2 && pathSegments.first == 's';
}

bool _isShellContentLocation(String path) =>
    path == '/chat' ||
    path == '/map' ||
    path == '/trips' ||
    path == '/favorites' ||
    (path.startsWith('/trips/') && path != '/trips/new') ||
    path.startsWith('/favorites/');
