/// 全 app 路由：StatefulShellRoute 5 branches + 認證 redirect。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/providers.dart';
import '../features/account/account_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/collab/collab_screen.dart';
import '../features/favorites/add_poi_favorite_to_trip_screen.dart';
import '../features/favorites/explore_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/invite/invite_screen.dart';
import '../features/map/global_map_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/trip_detail/add_entry_screen.dart';
import '../features/trip_detail/change_poi_screen.dart';
import '../features/trip_detail/edit_entry_screen.dart';
import '../features/trip_detail/entry_action_screen.dart';
import '../features/trip_detail/trip_map_screen.dart';
import '../features/trip_detail/trip_notes_screen.dart';
import '../features/trip_detail/trip_timeline_screen.dart';
import '../models/poi.dart';
import '../features/trips/trip_form_screen.dart';
import '../features/trips/trips_list_screen.dart';

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
      final isOnInvite = state.matchedLocation == '/invite';
      if (!isLoggedIn && !isOnLogin && !isOnInvite) return '/login';
      if (isLoggedIn && isOnLogin) return '/trips';
      return null;
    },
    routes: [
      // 登入頁在 shell 外（無底部導航）
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/invite',
        builder: (context, state) =>
            InviteScreen(token: state.uri.queryParameters['token']),
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
                    path: 'new',
                    builder: (context, state) => const TripFormScreen.create(),
                  ),
                  GoRoute(
                    path: ':tripId',
                    builder: (context, state) => TripTimelineScreen(
                      tripId: state.pathParameters['tripId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => TripFormScreen.edit(
                          tripId: state.pathParameters['tripId']!,
                        ),
                      ),
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
                        path: 'collab',
                        builder: (context, state) => CollabScreen(
                          tripId: state.pathParameters['tripId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'add-entry',
                        builder: (context, state) => AddEntryScreen(
                          tripId: state.pathParameters['tripId']!,
                          initialDayNum: _dayNumFromQuery(state),
                          initialSource: _entrySourceFromQuery(state),
                        ),
                      ),
                      GoRoute(
                        path: 'add-stop',
                        builder: (context, state) => AddEntryScreen(
                          tripId: state.pathParameters['tripId']!,
                          initialDayNum: _dayNumFromQuery(state),
                          initialSource: _entrySourceFromQuery(state),
                        ),
                      ),
                      GoRoute(
                        path: 'add-custom-stop',
                        builder: (context, state) => AddEntryScreen(
                          tripId: state.pathParameters['tripId']!,
                          initialDayNum: _dayNumFromQuery(state),
                          initialSource: 'custom',
                        ),
                      ),
                      GoRoute(
                        path: 'stop/:entryId/edit',
                        builder: (context, state) => EditEntryScreen(
                          tripId: state.pathParameters['tripId']!,
                          entryId:
                              int.tryParse(
                                state.pathParameters['entryId'] ?? '',
                              ) ??
                              -1,
                        ),
                      ),
                      GoRoute(
                        path: 'stop/:entryId/change-poi',
                        builder: (context, state) => ChangePoiScreen(
                          tripId: state.pathParameters['tripId']!,
                          entryId:
                              int.tryParse(
                                state.pathParameters['entryId'] ?? '',
                              ) ??
                              -1,
                          mode: state.uri.queryParameters['mode'] == 'alternate'
                              ? ChangePoiMode.alternate
                              : ChangePoiMode.master,
                        ),
                      ),
                      GoRoute(
                        path: 'stop/:entryId/copy',
                        builder: (context, state) => EntryActionScreen(
                          tripId: state.pathParameters['tripId']!,
                          entryId:
                              int.tryParse(
                                state.pathParameters['entryId'] ?? '',
                              ) ??
                              -1,
                          action: EntryActionKind.copy,
                        ),
                      ),
                      GoRoute(
                        path: 'stop/:entryId/move',
                        builder: (context, state) => EntryActionScreen(
                          tripId: state.pathParameters['tripId']!,
                          entryId:
                              int.tryParse(
                                state.pathParameters['entryId'] ?? '',
                              ) ??
                              -1,
                          action: EntryActionKind.move,
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
                    path: ':favoriteId/add-to-trip',
                    builder: (context, state) => AddPoiFavoriteToTripScreen(
                      favoriteId:
                          int.tryParse(state.pathParameters['favoriteId']!) ??
                          -1,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/explore',
                builder: (context, state) => const ExploreScreen(),
              ),
              GoRoute(
                path: '/add-to-trip',
                builder: (context, state) => AddPoiFavoriteToTripScreen(
                  directPoi: _poiSearchResultFromQuery(
                    state.uri.queryParameters,
                  ),
                ),
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

PoiSearchResult? _poiSearchResultFromQuery(Map<String, String> query) {
  final placeId = _nonEmptyQueryValue(query, 'place_id');
  final name = _nonEmptyQueryValue(query, 'name');
  final lat = double.tryParse(query['lat'] ?? '');
  final lng = double.tryParse(query['lng'] ?? '');
  if (placeId == null || name == null || lat == null || lng == null) {
    return null;
  }
  return PoiSearchResult(
    placeId: placeId,
    name: name,
    address: _nonEmptyQueryValue(query, 'address'),
    lat: lat,
    lng: lng,
    category: _nonEmptyQueryValue(query, 'category'),
    country: _nonEmptyQueryValue(query, 'country'),
    countryName: _nonEmptyQueryValue(query, 'country_name'),
    rating: double.tryParse(query['rating'] ?? ''),
    businessStatus: _nonEmptyQueryValue(query, 'business_status'),
  );
}

String? _nonEmptyQueryValue(Map<String, String> query, String key) {
  final value = query[key]?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

int? _dayNumFromQuery(GoRouterState state) {
  return int.tryParse(state.uri.queryParameters['day'] ?? '');
}

String? _entrySourceFromQuery(GoRouterState state) {
  final tab = state.uri.queryParameters['tab']?.trim();
  return switch (tab) {
    'search' || 'favorites' || 'custom' => tab,
    _ => null,
  };
}
