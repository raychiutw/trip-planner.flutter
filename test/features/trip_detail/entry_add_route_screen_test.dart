import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;
import 'package:tripline/features/trip_detail/entry_add_route_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

class _MockPoiRepository extends Mock implements PoiRepository {}

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

const _days = [
  TripDay(id: 1, dayNum: 1, title: '抵達', version: 0),
  TripDay(id: 2, dayNum: 2, title: '市區', version: 0),
];

const _favorites = [
  PoiFavorite(
    id: 9,
    userId: 'user-1',
    poiId: 91,
    favoritedAt: '2026-07-01T00:00:00.000Z',
    poiName: '首里城',
    poiAddress: '沖繩縣那霸市首里金城町',
    poiType: 'tourist_attraction',
    poiLat: 26.217,
    poiLng: 127.719,
  ),
];

Widget _buildScreen(
  _MockTripRepository repo, {
  _MockPoiRepository? poiRepo,
  _MockFavoritesRepository? favoritesRepo,
  int initialDayNum = 2,
  EntryAddMode initialMode = EntryAddMode.custom,
  String? initialRegion,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => EntryAddRouteScreen(
          tripId: 'trip-1',
          initialDayNum: initialDayNum,
          initialMode: initialMode,
          initialRegion: initialRegion,
        ),
      ),
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) =>
            Scaffold(body: Text('trip ${state.pathParameters['tripId']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      tripRepositoryProvider.overrideWithValue(repo),
      if (poiRepo != null) poiRepositoryProvider.overrideWithValue(poiRepo),
      if (favoritesRepo != null)
        favoritesRepositoryProvider.overrideWithValue(favoritesRepo),
      tripDaysProvider('trip-1').overrideWith((ref) => Stream.value(_days)),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  setUpAll(
    () => registerFallbackValue(const PoiSearchResult(placeId: 'x', name: 'x')),
  );

  testWidgets('送出自訂停留點會使用 query day 並回行程頁', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.addEntryToDay(
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        poiType: any(named: 'poiType'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildScreen(repo));
    await tester.pumpAndSettle();

    expect(find.text('新增停留點'), findsWidgets);
    expect(find.text('DAY 2 · 市區'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '自由活動',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '自由活動',
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'custom',
      ),
    ).called(1);
    expect(find.text('trip trip-1'), findsOneWidget);
  });

  testWidgets('可切換要新增到哪一天', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.addEntryToDay(
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        poiType: any(named: 'poiType'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildScreen(repo, initialDayNum: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DAY 2 · 市區'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '晚餐',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '晚餐',
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'custom',
      ),
    ).called(1);
  });

  testWidgets('搜尋 POI 後可加入指定 day', (tester) async {
    final repo = _MockTripRepository();
    final poiRepo = _MockPoiRepository();
    when(
      () => poiRepo.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => const [
        PoiSearchResult(
          placeId: 'p1',
          name: '美麗海水族館',
          address: '沖繩縣國頭郡本部町',
          lat: 26.694,
          lng: 127.878,
          category: 'aquarium',
        ),
      ],
    );
    when(
      () => repo.addEntryToDay(
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        note: any(named: 'note'),
        poiType: any(named: 'poiType'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      _buildScreen(repo, poiRepo: poiRepo, initialMode: EntryAddMode.search),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('entry-add-search-field')),
      '水族館',
    );
    await tester.tap(find.byKey(const ValueKey('entry-add-search-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-add-poi-p1')));
    await tester.pumpAndSettle();

    verify(
      () => poiRepo.searchPois(q: '水族館', limit: 20, region: null),
    ).called(1);
    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '美麗海水族館',
        note: any(named: 'note'),
        poiType: any(named: 'poiType'),
        lat: 26.694,
        lng: 127.878,
        source: 'google',
      ),
    ).called(1);
    expect(find.text('trip trip-1'), findsOneWidget);
  });

  testWidgets('搜尋 POI 時會沿用初始地區', (tester) async {
    final repo = _MockTripRepository();
    final poiRepo = _MockPoiRepository();
    when(
      () => poiRepo.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const []);

    await tester.pumpWidget(
      _buildScreen(
        repo,
        poiRepo: poiRepo,
        initialMode: EntryAddMode.search,
        initialRegion: '沖繩',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('沖繩'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('entry-add-search-field')),
      '水族館',
    );
    await tester.tap(find.byKey(const ValueKey('entry-add-search-submit')));
    await tester.pumpAndSettle();

    verify(
      () => poiRepo.searchPois(q: '水族館', limit: 20, region: '沖繩'),
    ).called(1);
  });

  testWidgets('收藏模式可把已收藏景點加入指定 day', (tester) async {
    final repo = _MockTripRepository();
    final favoritesRepo = _MockFavoritesRepository();
    when(favoritesRepo.fetchFavorites).thenAnswer((_) async => _favorites);
    when(
      () => repo.addEntryToDay(
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        note: any(named: 'note'),
        poiType: any(named: 'poiType'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      _buildScreen(
        repo,
        favoritesRepo: favoritesRepo,
        initialMode: EntryAddMode.favorites,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('收藏景點'), findsWidgets);
    expect(find.text('首里城'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('entry-add-favorite-9')));
    await tester.pumpAndSettle();

    verify(favoritesRepo.fetchFavorites).called(1);
    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '首里城',
        note: '沖繩縣那霸市首里金城町',
        poiType: 'attraction',
        lat: 26.217,
        lng: 127.719,
        source: 'favorite',
      ),
    ).called(1);
    expect(find.text('trip trip-1'), findsOneWidget);
  });
}
