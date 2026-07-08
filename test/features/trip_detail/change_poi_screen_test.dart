import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/change_poi_screen.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/poi.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  const tripId = 'okinawa-trip-2026';
  const entryId = 101;
  const entry = TimelineEntry(
    id: entryId,
    dayId: 11,
    sortOrder: 0,
    startTime: '10:00',
    endTime: '11:30',
    title: '首里城公園',
    version: 7,
    entryPoisVersion: '3',
    master: EntryPoiInfo(poiId: 501, name: '首里城公園', type: 'attraction'),
  );
  const refreshedEntry = TimelineEntry(
    id: entryId,
    dayId: 11,
    sortOrder: 0,
    startTime: '10:00',
    endTime: '11:30',
    title: '首里城公園',
    version: 7,
    entryPoisVersion: '4',
    master: EntryPoiInfo(poiId: 501, name: '首里城公園', type: 'attraction'),
  );
  const searchResult = PoiSearchResult(
    placeId: 'ChIJ-tamaudun',
    name: '玉陵',
    address: '沖繩縣那霸市',
    lat: 26.219,
    lng: 127.716,
    category: 'tourist_attraction',
    rating: 4.2,
  );
  const favorite = PoiFavorite(
    id: 88,
    userId: 'user-1',
    poiId: 502,
    favoritedAt: '2026-07-08T12:00:00Z',
    poiName: '玉陵',
    poiAddress: '沖繩縣那霸市',
    poiType: 'attraction',
    poiRating: 4.2,
  );

  late MockTripRepository mockTripRepository;

  setUpAll(() {
    registerFallbackValue(searchResult);
  });

  setUp(() {
    mockTripRepository = MockTripRepository();
    when(
      () => mockTripRepository.fetchEntry(tripId, entryId),
    ).thenAnswer((_) async => entry);
    when(
      () => mockTripRepository.fetchPoiFavorites(),
    ).thenAnswer((_) async => const [favorite]);
    when(
      () => mockTripRepository.searchPois(
        query: any(named: 'query'),
        region: any(named: 'region'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const [searchResult]);
    when(
      () => mockTripRepository.replaceEntryMasterPoiFromSearchResult(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poi: any(named: 'poi'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockTripRepository.addEntryAlternateWithPoiId(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer(
      (_) async => const EntryPoisMutationResult(
        entryId: entryId,
        poiId: 502,
        sortOrder: 2,
        entryPoisVersion: '4',
      ),
    );
    when(
      () => mockTripRepository.recomputeTravel(
        any(),
        dayNum: any(named: 'dayNum'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget buildRouterApp({String mode = 'master'}) {
    final initialLocation =
        '/trips/$tripId/stop/$entryId/change-poi${mode == 'alternate' ? '?mode=alternate' : ''}';
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/trips/:tripId/stop/:entryId/change-poi',
          builder: (context, state) => ChangePoiScreen(
            tripId: state.pathParameters['tripId']!,
            entryId: int.parse(state.pathParameters['entryId']!),
            mode: state.uri.queryParameters['mode'] == 'alternate'
                ? ChangePoiMode.alternate
                : ChangePoiMode.master,
          ),
        ),
        GoRoute(
          path: '/trips/:tripId/stop/:entryId/edit',
          builder: (context, state) =>
              Scaffold(body: Text('edit:${state.pathParameters['entryId']}')),
        ),
        GoRoute(
          path: '/trips/:tripId',
          builder: (context, state) =>
              Scaffold(body: Text('trip:${state.pathParameters['tripId']}')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [tripRepositoryProvider.overrideWithValue(mockTripRepository)],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  testWidgets('搜尋結果可置換主景點並帶 entryPoisVersion', (tester) async {
    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('置換景點'), findsOneWidget);
    expect(find.text('目前：首里城公園'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('change-poi-search-input')),
      '玉陵',
    );
    await tester.tap(find.byTooltip('搜尋'));
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('change-poi-submit-search-ChIJ-tamaudun')),
    );
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.replaceEntryMasterPoiFromSearchResult(
        tripId: tripId,
        entryId: entryId,
        poi: searchResult,
        entryPoisVersion: '3',
      ),
    ).called(1);
    verify(() => mockTripRepository.recomputeTravel(tripId)).called(1);
    expect(find.text('trip:$tripId'), findsOneWidget);
  });

  testWidgets('置換主景點遇到 STALE_ENTRY 時重抓 entryPoisVersion 後 retry', (
    tester,
  ) async {
    var fetchCount = 0;
    when(() => mockTripRepository.fetchEntry(tripId, entryId)).thenAnswer((
      _,
    ) async {
      fetchCount++;
      return fetchCount == 1 ? entry : refreshedEntry;
    });
    when(
      () => mockTripRepository.replaceEntryMasterPoiFromSearchResult(
        tripId: tripId,
        entryId: entryId,
        poi: searchResult,
        entryPoisVersion: '3',
      ),
    ).thenThrow(
      const ApiError(
        status: 409,
        code: 'STALE_ENTRY',
        message: 'expected version 3, current 4',
      ),
    );
    when(
      () => mockTripRepository.replaceEntryMasterPoiFromSearchResult(
        tripId: tripId,
        entryId: entryId,
        poi: searchResult,
        entryPoisVersion: '4',
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('change-poi-search-input')),
      '玉陵',
    );
    await tester.tap(find.byTooltip('搜尋'));
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('change-poi-submit-search-ChIJ-tamaudun')),
    );
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.replaceEntryMasterPoiFromSearchResult(
        tripId: tripId,
        entryId: entryId,
        poi: searchResult,
        entryPoisVersion: '3',
      ),
    ).called(1);
    verify(
      () => mockTripRepository.replaceEntryMasterPoiFromSearchResult(
        tripId: tripId,
        entryId: entryId,
        poi: searchResult,
        entryPoisVersion: '4',
      ),
    ).called(1);
    expect(find.text('trip:$tripId'), findsOneWidget);
  });

  testWidgets('收藏可加為備選並回到 edit screen', (tester) async {
    await tester.pumpWidget(buildRouterApp(mode: 'alternate'));
    await tester.pump();
    await tester.pump();

    expect(find.text('加入備選景點'), findsOneWidget);

    await tester.tap(find.text('收藏'));
    await tester.pump();
    await tester.pump();

    expect(find.text('玉陵'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('change-poi-submit-favorite-88')),
    );
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.addEntryAlternateWithPoiId(
        tripId: tripId,
        entryId: entryId,
        poiId: 502,
        entryPoisVersion: '3',
      ),
    ).called(1);
    expect(find.text('edit:$entryId'), findsOneWidget);
  });

  testWidgets('收藏加入備選遇到 STALE_ENTRY 時重抓 entryPoisVersion 後 retry', (
    tester,
  ) async {
    var fetchCount = 0;
    when(() => mockTripRepository.fetchEntry(tripId, entryId)).thenAnswer((
      _,
    ) async {
      fetchCount++;
      return fetchCount == 1 ? entry : refreshedEntry;
    });
    when(
      () => mockTripRepository.addEntryAlternateWithPoiId(
        tripId: tripId,
        entryId: entryId,
        poiId: 502,
        entryPoisVersion: '3',
      ),
    ).thenThrow(
      const ApiError(
        status: 409,
        code: 'STALE_ENTRY',
        message: 'expected version 3, current 4',
      ),
    );
    when(
      () => mockTripRepository.addEntryAlternateWithPoiId(
        tripId: tripId,
        entryId: entryId,
        poiId: 502,
        entryPoisVersion: '4',
      ),
    ).thenAnswer(
      (_) async => const EntryPoisMutationResult(
        entryId: entryId,
        poiId: 502,
        sortOrder: 2,
        entryPoisVersion: '5',
      ),
    );

    await tester.pumpWidget(buildRouterApp(mode: 'alternate'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('收藏'));
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('change-poi-submit-favorite-88')),
    );
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.addEntryAlternateWithPoiId(
        tripId: tripId,
        entryId: entryId,
        poiId: 502,
        entryPoisVersion: '3',
      ),
    ).called(1);
    verify(
      () => mockTripRepository.addEntryAlternateWithPoiId(
        tripId: tripId,
        entryId: entryId,
        poiId: 502,
        entryPoisVersion: '4',
      ),
    ).called(1);
    expect(find.text('edit:$entryId'), findsOneWidget);
  });
}
