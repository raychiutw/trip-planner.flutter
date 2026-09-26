import 'dart:async';
import 'dart:ui' show Tristate;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
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
  bool useRepositoryDays = false,
}) {
  when(
    () => repo.recomputeTravel(
      tripId: any(named: 'tripId'),
      day: any(named: 'day'),
    ),
  ).thenAnswer((_) async {});
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
  addTearDown(router.dispose);
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      tripRepositoryProvider.overrideWithValue(repo),
      if (poiRepo != null) poiRepositoryProvider.overrideWithValue(poiRepo),
      if (favoritesRepo != null)
        favoritesRepositoryProvider.overrideWithValue(favoritesRepo),
      if (!useRepositoryDays)
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

  testWidgets('Day 初載失敗顯示友善錯誤，原地重試後取得日期', (tester) async {
    final repo = _MockTripRepository();
    var reads = 0;
    when(() => repo.watchDays('trip-1')).thenAnswer((_) {
      reads++;
      return reads == 1
          ? Stream<List<TripDay>>.error(Exception('internal-day-error'))
          : Stream.value(const [
              TripDay(id: 3, dayNum: 3, date: '2026-10-03', version: 0),
            ]);
    });

    await tester.pumpWidget(
      _buildScreen(
        repo,
        initialMode: EntryAddMode.search,
        useRepositoryDays: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(reads, 1);
    expect(find.text('日期載入失敗，請檢查網路後再試'), findsOneWidget);
    expect(find.textContaining('internal-day-error'), findsNothing);
    expect(find.text('重試'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(reads, 2);
    expect(find.text('DAY 3 · 2026-10-03'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('entry-add-search-field')),
      findsOneWidget,
    );
    expect(find.text('重試'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空日期快取後載入失敗可原地重試，不誤報行程尚無日期', (tester) async {
    final repo = _MockTripRepository();
    final initial = StreamController<List<TripDay>>();
    addTearDown(initial.close);
    var reads = 0;
    when(() => repo.watchDays('trip-1')).thenAnswer((_) {
      reads++;
      return reads == 1 ? initial.stream : Stream.value(_days);
    });

    await tester.pumpWidget(_buildScreen(repo, useRepositoryDays: true));
    initial.add(const <TripDay>[]);
    await tester.pumpAndSettle();
    expect(find.text('此行程尚無日期，請先回行程頁建立日期。'), findsOneWidget);

    initial.addError(Exception('private-day-load-error'));
    await tester.pumpAndSettle();
    expect(find.text('日期載入失敗，請檢查網路後再試'), findsOneWidget);
    expect(find.text('此行程尚無日期，請先回行程頁建立日期。'), findsNothing);
    expect(find.textContaining('private-day-load-error'), findsNothing);
    expect(find.text('重試'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('DAY 2'), findsOneWidget);
    expect(find.text('日期載入失敗，請檢查網路後再試'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自訂停留點草稿切換搜尋與收藏後仍保留', (tester) async {
    final favoritesRepo = _MockFavoritesRepository();
    when(
      () => favoritesRepo.fetchFavorites(),
    ).thenAnswer((_) async => _favorites);
    await tester.pumpWidget(
      _buildScreen(_MockTripRepository(), favoritesRepo: favoritesRepo),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '未送出的自訂停留點',
    );
    await tester.pump();
    expect(find.text('未送出的自訂停留點'), findsOneWidget);

    await tester.ensureVisible(find.text('搜尋'));
    await tester.tap(find.text('搜尋'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('entry-add-search-field')),
      findsOneWidget,
    );
    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('首里城'), findsOneWidget);

    await tester.tap(find.text('自訂'));
    await tester.pumpAndSettle();
    expect(find.text('未送出的自訂停留點'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Day 更新失敗與重試保留三模式草稿及選取日期', (tester) async {
    final repo = _MockTripRepository();
    final poiRepo = _MockPoiRepository();
    final favoritesRepo = _MockFavoritesRepository();
    final source = StreamController<List<TripDay>>();
    addTearDown(source.close);
    var reads = 0;
    when(() => repo.watchDays('trip-1')).thenAnswer((_) {
      reads++;
      return reads == 1 ? source.stream : Stream.value(_days);
    });
    when(
      () => favoritesRepo.fetchFavorites(),
    ).thenAnswer((_) async => _favorites);
    when(
      () => poiRepo.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => const [PoiSearchResult(placeId: 'p1', name: '沖繩公園')],
    );
    await tester.pumpWidget(
      _buildScreen(
        repo,
        poiRepo: poiRepo,
        favoritesRepo: favoritesRepo,
        initialMode: EntryAddMode.search,
        useRepositoryDays: true,
      ),
    );
    source.add(_days);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-add-search-field')),
      '沖繩',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-add-poi-p1')));
    await tester.pump();
    expect(find.text('已選 1 個'), findsOneWidget);
    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-add-favorite-9')));
    await tester.pump();
    expect(find.text('已選 1 個'), findsOneWidget);
    await tester.tap(find.text('自訂'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '保留自訂草稿',
    );
    await tester.pump();
    source.addError(Exception('day-refresh-internal-error'));
    await tester.pumpAndSettle();
    expect(find.text('日期載入失敗，請檢查網路後再試'), findsOneWidget);
    expect(find.text('保留自訂草稿'), findsOneWidget);

    await tester.ensureVisible(find.text('重試'));
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('保留自訂草稿'), findsOneWidget);
    expect(find.text('DAY 2'), findsOneWidget);
    await tester.ensureVisible(find.text('收藏'));
    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();
    expect(find.text('已選 1 個'), findsOneWidget);
    await tester.tap(find.text('搜尋'));
    await tester.pumpAndSettle();
    expect(find.text('已選 1 個'), findsOneWidget);
    expect(find.text('沖繩'), findsWidgets);
    expect(find.text('沖繩公園'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Day 延遲重試保留草稿與等待狀態，連點只讀取一次', (tester) async {
    final repo = _MockTripRepository();
    final initial = StreamController<List<TripDay>>();
    final retry = StreamController<List<TripDay>>();
    addTearDown(() => unawaited(initial.close()));
    addTearDown(() => unawaited(retry.close()));
    var reads = 0;
    when(() => repo.watchDays('trip-1')).thenAnswer((_) {
      reads++;
      return reads == 1 ? initial.stream : retry.stream;
    });
    await tester.pumpWidget(_buildScreen(repo, useRepositoryDays: true));
    initial.add(_days);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '等待日期更新的草稿',
    );
    initial.addError(Exception('day-refresh-failed'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('重試'));
    await tester.tap(find.text('重試'));
    await tester.tap(find.text('重試'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(reads, 2);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('等待日期更新的草稿'), findsOneWidget);
    expect(find.text('DAY 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-add-loading')), findsNothing);

    retry.add(const [
      TripDay(id: 2, dayNum: 2, date: '2026-10-02', version: 0),
    ]);
    unawaited(retry.close());
    await tester.pumpAndSettle();

    expect(reads, 2);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('等待日期更新的草稿'), findsOneWidget);
    expect(find.text('DAY 2 · 2026-10-02'), findsOneWidget);
    expect(find.text('日期載入失敗，請檢查網路後再試'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('加入收藏仍在處理時連點只新增一次', (tester) async {
    final repo = _MockTripRepository();
    final favoritesRepo = _MockFavoritesRepository();
    final pending = Completer<void>();
    final submittedTitles = <String>[];
    when(
      () => favoritesRepo.fetchFavorites(),
    ).thenAnswer((_) async => _favorites);
    when(
      () => repo.addEntryToDay(
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        title: any(named: 'title'),
        note: any(named: 'note'),
        poiType: any(named: 'poiType'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((invocation) {
      submittedTitles.add(invocation.namedArguments[#title]! as String);
      return pending.future;
    });
    await tester.pumpWidget(
      _buildScreen(
        repo,
        favoritesRepo: favoritesRepo,
        initialMode: EntryAddMode.favorites,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-add-favorite-9')));
    await tester.pump();

    final confirm = find.byKey(const ValueKey('entry-add-confirm'));
    await tester.tap(confirm);
    await tester.tap(confirm);
    await tester.pump();
    expect(submittedTitles, ['首里城']);
    expect(find.text('trip trip-1'), findsNothing);

    pending.complete();
    await tester.pumpAndSettle();
    expect(submittedTitles, ['首里城']);
    expect(find.text('trip trip-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final firstSource in ['custom', 'favorite']) {
    testWidgets(
      firstSource == 'custom' ? '自訂仍在處理時切換收藏不會再送出新增' : '收藏仍在處理時切換自訂不會再送出新增',
      (tester) async {
        final repo = _MockTripRepository();
        final favoritesRepo = _MockFavoritesRepository();
        final pending = Completer<void>();
        final submittedSources = <String>[];
        when(
          () => favoritesRepo.fetchFavorites(),
        ).thenAnswer((_) async => _favorites);
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
        ).thenAnswer((invocation) {
          submittedSources.add(invocation.namedArguments[#source]! as String);
          return pending.future;
        });
        await tester.pumpWidget(
          _buildScreen(
            repo,
            favoritesRepo: favoritesRepo,
            initialMode: EntryAddMode.favorites,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('entry-add-favorite-9')));
        await tester.tap(find.text('自訂'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('entry-edit-title')),
          '自訂等待完成',
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
        if (firstSource == 'favorite') {
          await tester.ensureVisible(find.text('收藏'));
          await tester.tap(find.text('收藏'));
          await tester.pump();
        }
        await tester.tap(find.text('加入'));
        await tester.pump();
        expect(submittedSources, [firstSource]);

        final nextMode = firstSource == 'custom' ? '收藏' : '自訂';
        await tester.ensureVisible(find.text(nextMode));
        await tester.tap(find.text(nextMode));
        await tester.pump();
        await tester.tap(find.text('加入'));
        await tester.pump();
        expect(submittedSources, [firstSource]);

        pending.complete();
        await tester.pumpAndSettle();
        expect(submittedSources, [firstSource]);
        expect(find.text('trip trip-1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('320pt / 200% 字級仍完整顯示取消', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(_buildScreen(_MockTripRepository()));
    await tester.pumpAndSettle();

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('取'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('加入'), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(find.byKey(const ValueKey('account-avatar-button')), findsNothing);
    expect(find.text('DAY 2'), findsOneWidget);
    expect(find.text('搜尋'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('搜尋景點'), findsNothing);
    expect(find.text('收藏景點'), findsNothing);
    expect(find.byKey(const ValueKey('entry-add-category-list')), findsNothing);

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

    expect(find.byType(FilterChip), findsNothing);
    await tester.tap(find.byKey(const ValueKey('entry-add-day-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-add-day-2')));
    await tester.pumpAndSettle();
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

    final categoryList = tester.widget<ListView>(
      find.byKey(const ValueKey('entry-add-category-list')),
    );
    expect(categoryList.scrollDirection, Axis.horizontal);

    await tester.enterText(
      find.byKey(const ValueKey('entry-add-search-field')),
      '水族館',
    );
    expect(find.byKey(const ValueKey('entry-add-search-submit')), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-add-poi-p1')), findsOneWidget);
    expect(
      tester
          .widgetList<ListView>(find.byType(ListView))
          .any(
            (list) =>
                list.keyboardDismissBehavior ==
                ScrollViewKeyboardDismissBehavior.onDrag,
          ),
      isTrue,
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-add-search-field')),
      '',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('entry-add-poi-p1')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('entry-add-search-field')),
      '水族館',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-add-poi-p1')));
    await tester.pump();
    expect(find.text('trip trip-1'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('entry-add-confirm')));
    await tester.pumpAndSettle();

    verify(
      () => poiRepo.searchPois(q: '水族館', limit: 20, region: null),
    ).called(2);
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
    await tester.pump(const Duration(milliseconds: 300));
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
    await tester.pump(const Duration(milliseconds: 300));
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

  testWidgets('多選部分失敗只保留未送出項目，重試不重複新增已成功項目', (tester) async {
    final repo = _MockTripRepository();
    final poiRepo = _MockPoiRepository();
    final submittedTitles = <String>[];
    var marketShouldFail = true;
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
    ).thenAnswer((invocation) async {
      final title = invocation.namedArguments[#title]! as String;
      submittedTitles.add(title);
      if (title == '牧志市場' && marketShouldFail) {
        marketShouldFail = false;
        throw Exception('offline');
      }
    });
    await tester.pumpWidget(
      _buildScreen(repo, poiRepo: poiRepo, initialMode: EntryAddMode.search),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('entry-add-search-field')),
      '沖繩',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-add-poi-p1')));
    await tester.tap(find.byKey(const ValueKey('entry-add-poi-p2')));
    await tester.pump();

    final confirm = find.byKey(const ValueKey('entry-add-confirm'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(submittedTitles, ['美麗海水族館', '牧志市場']);
    expect(find.text('已選 1 個'), findsOneWidget);
    expect(find.text('加入行程失敗，請稍後再試'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('entry-add-search-field')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '沖繩',
    );

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(submittedTitles, ['美麗海水族館', '牧志市場', '牧志市場']);
    expect(find.text('trip trip-1'), findsOneWidget);
  });

  testWidgets('新增停留點地區選單標示目前選取並更新查詢', (tester) async {
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
    final semantics = tester.ensureSemantics();
    await tester.tap(find.byTooltip('切換搜尋地區'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.text('沖繩').last)
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    // 值選項只以勾選標示目前地區，其他值不配圖示。
    Finder menuItem(Finder text) =>
        find.ancestor(of: text, matching: find.byType(GlassMenuItem));
    expect(
      find.descendant(
        of: menuItem(find.text('沖繩').last),
        matching: find.byType(Icon),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: menuItem(find.text('沖繩').last),
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: menuItem(find.text('東京')),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    await tester.tap(find.text('東京'));
    await tester.pumpAndSettle();
    semantics.dispose();

    await tester.enterText(
      find.byKey(const ValueKey('entry-add-search-field')),
      '水族館',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    verify(
      () => poiRepo.searchPois(q: '水族館', limit: 20, region: '東京'),
    ).called(1);
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
    await tester.pump(const Duration(milliseconds: 300));
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
    await tester.pump(const Duration(milliseconds: 300));
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
    await tester.pump(const Duration(milliseconds: 300));
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
    await tester.pump(const Duration(milliseconds: 300));
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

    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('收藏景點'), findsNothing);
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
