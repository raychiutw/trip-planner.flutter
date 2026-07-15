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
import 'package:tripline/models/place_details.dart';
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

const _mixedFavorites = [
  PoiFavorite(
    id: 10,
    userId: 'user-1',
    poiId: 101,
    favoritedAt: '2026-07-01T00:00:00.000Z',
    poiName: '牧志市場',
    poiAddress: '沖繩縣那霸市松尾',
    poiType: 'restaurant',
  ),
  PoiFavorite(
    id: 11,
    userId: 'user-1',
    poiId: 102,
    favoritedAt: '2026-07-02T00:00:00.000Z',
    poiName: '那霸飯店',
    poiAddress: '沖繩縣那霸市',
    poiType: 'hotel',
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

void _stubResolvePlace(
  _MockPoiRepository poiRepo, {
  PlaceDetails Function(String placeId)? detailsFor,
}) {
  when(() => poiRepo.resolvePlace(any())).thenAnswer((invocation) async {
    final placeId = invocation.positionalArguments.first as String;
    return detailsFor?.call(placeId) ?? PlaceDetails(placeId: placeId);
  });
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
    expect(find.text('DAY 2'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '自由活動',
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-lat')),
      '26.21',
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-lng')),
      '127.68',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '自由活動',
        description: any(named: 'description'),
        poiType: 'attraction',
        lat: 26.21,
        lng: 127.68,
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

    await tester.tap(find.byKey(const ValueKey('entry-add-day-2')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '晚餐',
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-lat')),
      '26.22',
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-lng')),
      '127.69',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '晚餐',
        description: any(named: 'description'),
        poiType: 'attraction',
        lat: 26.22,
        lng: 127.69,
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
    _stubResolvePlace(
      poiRepo,
      detailsFor: (placeId) => PlaceDetails(
        placeId: placeId,
        hours:
            '星期一: 08:30-18:30 星期二: 08:30-18:30 星期三: 08:30-18:30 星期四: 08:30-18:30 星期五: 08:30-18:30 星期六: 08:30-18:30 星期日: 08:30-18:30',
        priceLevel: 'PRICE_LEVEL_MODERATE',
      ),
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
    await tester.pump();
    expect(find.text('trip trip-1'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('entry-add-confirm')));
    await tester.pumpAndSettle();

    verify(
      () => poiRepo.searchPois(q: '水族館', limit: 20, region: null),
    ).called(1);
    verify(() => poiRepo.resolvePlace('p1')).called(1);
    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '美麗海水族館',
        note: '營業 08:30-18:30\n消費 ￥￥\n沖繩縣國頭郡本部町',
        poiType: any(named: 'poiType'),
        lat: 26.694,
        lng: 127.878,
        source: 'google',
      ),
    ).called(1);
    expect(find.text('trip trip-1'), findsOneWidget);
  });

  testWidgets('搜尋 POI 加入時 resolve 失敗會保留地址備註', (tester) async {
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
      () => poiRepo.resolvePlace('p1'),
    ).thenThrow(Exception('resolve failed'));
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
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('entry-add-confirm')));
    await tester.pumpAndSettle();

    verify(() => poiRepo.resolvePlace('p1')).called(1);
    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '美麗海水族館',
        note: '沖繩縣國頭郡本部町',
        poiType: any(named: 'poiType'),
        lat: 26.694,
        lng: 127.878,
        source: 'google',
      ),
    ).called(1);
    expect(find.text('trip trip-1'), findsOneWidget);
  });

  testWidgets('搜尋模式可多選後一次加入指定 day', (tester) async {
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
        PoiSearchResult(
          placeId: 'p2',
          name: '牧志市場',
          address: '沖繩縣那霸市松尾',
          lat: 26.215,
          lng: 127.687,
          category: 'restaurant',
        ),
      ],
    );
    _stubResolvePlace(poiRepo);
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
      '沖繩',
    );
    await tester.tap(find.byKey(const ValueKey('entry-add-search-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-add-poi-p1')));
    await tester.tap(find.byKey(const ValueKey('entry-add-poi-p2')));
    await tester.pump();

    expect(find.text('已選 2 個'), findsOneWidget);

    final confirm = find.byKey(const ValueKey('entry-add-confirm'));
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '美麗海水族館',
        note: '沖繩縣國頭郡本部町',
        poiType: any(named: 'poiType'),
        lat: 26.694,
        lng: 127.878,
        source: 'google',
      ),
    ).called(1);
    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '牧志市場',
        note: '沖繩縣那霸市松尾',
        poiType: any(named: 'poiType'),
        lat: 26.215,
        lng: 127.687,
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

  testWidgets('搜尋模式可用類別篩選結果', (tester) async {
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
          placeId: 'food-1',
          name: '牧志市場',
          address: '沖繩縣那霸市松尾',
          category: 'restaurant',
        ),
        PoiSearchResult(
          placeId: 'hotel-1',
          name: '那霸飯店',
          address: '沖繩縣那霸市',
          category: 'hotel',
        ),
      ],
    );
    _stubResolvePlace(poiRepo);
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
      '沖繩',
    );
    await tester.tap(find.byKey(const ValueKey('entry-add-search-submit')));
    await tester.pumpAndSettle();

    expect(find.text('牧志市場'), findsOneWidget);
    expect(find.text('那霸飯店'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, '美食'));
    await tester.pumpAndSettle();

    expect(find.text('牧志市場'), findsOneWidget);
    expect(find.text('那霸飯店'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('entry-add-poi-food-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-add-confirm')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '牧志市場',
        description: any(named: 'description'),
        note: '沖繩縣那霸市松尾',
        poiType: 'restaurant',
        lat: 0.0,
        lng: 0.0,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'google',
      ),
    ).called(1);
  });

  testWidgets('搜尋模式選取後可覆寫單筆 POI 分類', (tester) async {
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
          name: '牧志市場',
          address: '沖繩縣那霸市松尾',
          category: 'restaurant',
        ),
      ],
    );
    _stubResolvePlace(poiRepo);
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
      '市場',
    );
    await tester.tap(find.byKey(const ValueKey('entry-add-search-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-add-poi-p1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-add-poi-type-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('飯店').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-add-confirm')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '牧志市場',
        description: any(named: 'description'),
        note: '沖繩縣那霸市松尾',
        poiType: 'hotel',
        lat: 0.0,
        lng: 0.0,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'google',
      ),
    ).called(1);
  });

  testWidgets('搜尋模式取消選取會清除 POI 分類覆寫', (tester) async {
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
          name: '牧志市場',
          address: '沖繩縣那霸市松尾',
          category: 'restaurant',
        ),
      ],
    );
    _stubResolvePlace(poiRepo);
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
      '市場',
    );
    await tester.tap(find.byKey(const ValueKey('entry-add-search-submit')));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('entry-add-poi-p1'));
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-add-poi-type-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('飯店').last);
    await tester.pumpAndSettle();

    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-add-confirm')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '牧志市場',
        description: any(named: 'description'),
        note: '沖繩縣那霸市松尾',
        poiType: 'restaurant',
        lat: 0.0,
        lng: 0.0,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'google',
      ),
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
    await tester.pump();
    expect(find.text('trip trip-1'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('entry-add-confirm')));
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

  testWidgets('收藏模式可多選後一次加入指定 day', (tester) async {
    final repo = _MockTripRepository();
    final favoritesRepo = _MockFavoritesRepository();
    when(favoritesRepo.fetchFavorites).thenAnswer((_) async => _mixedFavorites);
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

    await tester.tap(find.byKey(const ValueKey('entry-add-favorite-10')));
    await tester.tap(find.byKey(const ValueKey('entry-add-favorite-11')));
    await tester.pump();

    expect(find.text('已選 2 個'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-add-confirm')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '牧志市場',
        note: '沖繩縣那霸市松尾',
        poiType: 'restaurant',
        source: 'favorite',
      ),
    ).called(1);
    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '那霸飯店',
        note: '沖繩縣那霸市',
        poiType: 'hotel',
        source: 'favorite',
      ),
    ).called(1);
    expect(find.text('trip trip-1'), findsOneWidget);
  });

  testWidgets('收藏模式可用類別篩選清單', (tester) async {
    final repo = _MockTripRepository();
    final favoritesRepo = _MockFavoritesRepository();
    when(favoritesRepo.fetchFavorites).thenAnswer((_) async => _mixedFavorites);

    await tester.pumpWidget(
      _buildScreen(
        repo,
        favoritesRepo: favoritesRepo,
        initialMode: EntryAddMode.favorites,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('牧志市場'), findsOneWidget);
    expect(find.text('那霸飯店'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, '住宿'));
    await tester.pumpAndSettle();

    expect(find.text('牧志市場'), findsNothing);
    expect(find.text('那霸飯店'), findsOneWidget);
  });
}
