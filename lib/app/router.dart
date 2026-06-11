/// 全 app 路由：StatefulShellRoute 5 branches + 認證 redirect。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/providers.dart';
import '../features/account/account_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/favorites/add_to_trip/add_to_trip_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/favorites/explore/explore_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/trip_detail/entry_poi_screen.dart';
import '../features/trip_detail/trip_map_screen.dart';
import '../features/trip_detail/trip_notes_screen.dart';
import '../features/trip_detail/trip_timeline_screen.dart';
import '../features/trips/trips_list_screen.dart';
import '../models/add_to_trip.dart';

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
      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/trips';
      return null;
    },
    routes: [
      // 登入頁在 shell 外（無底部導航）
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
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
                builder: (context, state) =>
                    const PlaceholderScreen(title: '全域地圖'),
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
