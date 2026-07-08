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
import '../features/auth/login_screen.dart';
import '../features/auth/oauth_consent_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/favorites/add_to_trip/add_to_trip_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/favorites/explore/explore_screen.dart';
import '../features/map/global_map_screen.dart';
import '../features/share/public_share_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/trip_detail/entry_poi_screen.dart';
import '../features/trip_detail/trip_map_screen.dart';
import '../features/trip_detail/trip_notes_screen.dart';
import '../features/trip_detail/trip_print_screen.dart';
import '../features/trip_detail/trip_timeline_screen.dart';
import '../features/trips/collab/collab_screen.dart';
import '../features/trips/create/create_trip_screen.dart';
import '../features/trips/edit/edit_trip_screen.dart';
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
        builder: (context, state) =>
            OAuthConsentScreen(request: OAuthConsentRequest.fromUri(state.uri)),
      ),
      GoRoute(
        path: '/s/:token',
        builder: (context, state) =>
            PublicShareScreen(token: state.pathParameters['token']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trips',
                builder: (context, state) => const TripsListScreen(),
                routes: [
                  GoRoute(
                    path: ':tripId',
                    builder: (context, state) => TripTimelineScreen(
                      tripId: state.pathParameters['tripId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'map',
                        builder: (context, state) => TripMapScreen(
                          tripId: state.pathParameters['tripId']!,
                        ),
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
                builder: (context, state) => const GlobalMapScreen(),
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
                    path: 'add-to-trip',
                    // 深連結／重整後 extra 遺失時不 crash：導回收藏頁。
                    redirect: (context, state) =>
                        state.extra is AddToTripArgs ? null : '/favorites',
                    builder: (context, state) =>
                        AddToTripScreen(args: state.extra! as AddToTripArgs),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountScreen(),
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

const _publicShellOutsideRoutes = {'/login', '/oauth/consent'};

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
