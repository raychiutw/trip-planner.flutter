import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;
import 'package:tripline/features/trips/create/create_trip_screen.dart';
import 'package:tripline/models/destination_input.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepo extends Mock implements TripRepository {}

class _MockPoiRepo extends Mock implements PoiRepository {}

const _tokyo = PoiSearchResult(
  placeId: 'p1',
  name: '東京',
  lat: 35.68,
  lng: 139.76,
  country: 'JP',
);

void main() {
  setUpAll(() => registerFallbackValue(<DestinationInput>[]));

  late _MockTripRepo tripRepo;
  late _MockPoiRepo poiRepo;

  setUp(() {
    tripRepo = _MockTripRepo();
    poiRepo = _MockPoiRepo();
    when(
      () => poiRepo.searchPois(
        q: any(named: 'q'),
        region: any(named: 'region'),
      ),
    ).thenAnswer((_) async => const [_tokyo]);
  });

  Widget buildApp() {
    final router = GoRouter(
      initialLocation: '/new-trip',
      routes: [
        GoRoute(path: '/new-trip', builder: (_, _) => const CreateTripScreen()),
        GoRoute(
          path: '/trips/:id',
          builder: (_, s) =>
              Scaffold(body: Text('TRIP ${s.pathParameters['id']}')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        poiRepositoryProvider.overrideWithValue(poiRepo),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  testWidgets('目的地空 → 送出鈕 disabled', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    final btn = tester.widget<FilledButton>(
      find.byKey(const ValueKey('create-submit')),
    );
    expect(btn.onPressed, isNull);
    expect(find.byTooltip('搜尋地點'), findsOneWidget);
  });

  testWidgets('POI 搜尋 → 點結果 → 加入目的地', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('dest-poi-search')), '東京');
    await tester.tap(find.byKey(const ValueKey('dest-poi-search-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('poi-result-p1')));
    await tester.pumpAndSettle();

    // 已加入目的地清單(「至少選 1 個」提示消失)
    expect(find.text('至少選 1 個目的地'), findsNothing);
    expect(find.text('東京'), findsWidgets);
  });

  testWidgets('切到彈性模式 → 顯示天數 stepper', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('大概時間'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-flex-count')), findsOneWidget);
  });

  testWidgets('加目的地 + 彈性日期 → 送出呼叫 createTrip + 導頁', (tester) async {
    when(
      () => tripRepo.createTrip(
        id: any(named: 'id'),
        name: any(named: 'name'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        countries: any(named: 'countries'),
        published: any(named: 'published'),
        dataSource: any(named: 'dataSource'),
        lang: any(named: 'lang'),
        destinations: any(named: 'destinations'),
      ),
    ).thenAnswer(
      (_) async => (tripId: 'tokyo-x', daysCreated: 5, destinationsCreated: 1),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // 加目的地
    await tester.enterText(find.byKey(const ValueKey('dest-poi-search')), '東京');
    await tester.tap(find.byKey(const ValueKey('dest-poi-search-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('poi-result-p1')));
    await tester.pumpAndSettle();

    // 彈性日期(自動有效)
    await tester.tap(find.text('大概時間'));
    await tester.pumpAndSettle();

    // 送出(捲到底確保可點)
    await tester.ensureVisible(find.byKey(const ValueKey('create-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-submit')));
    await tester.pumpAndSettle();

    verify(
      () => tripRepo.createTrip(
        id: any(named: 'id'),
        name: '東京',
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        countries: 'JP',
        destinations: any(named: 'destinations'),
      ),
    ).called(1);
    expect(find.text('TRIP tokyo-x'), findsOneWidget); // 已導去新行程
  });
}
