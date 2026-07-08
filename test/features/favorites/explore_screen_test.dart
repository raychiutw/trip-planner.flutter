import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/explore_screen.dart';
import 'package:tripline/models/poi.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  const shuriSearchResult = PoiSearchResult(
    placeId: 'ChIJ-shuri',
    name: '首里城',
    address: '沖繩縣那霸市首里金城町',
    lat: 26.217,
    lng: 127.719,
    category: 'tourist_attraction',
    country: 'JP',
    rating: 4.4,
  );

  setUpAll(() {
    registerFallbackValue(shuriSearchResult);
  });

  late MockTripRepository mockTripRepository;

  setUp(() {
    mockTripRepository = MockTripRepository();
    when(
      () => mockTripRepository.fetchPoiFavorites(),
    ).thenAnswer((_) async => const <PoiFavorite>[]);
    when(
      () => mockTripRepository.searchPois(
        query: any(named: 'query'),
        region: any(named: 'region'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const [shuriSearchResult]);
    when(
      () => mockTripRepository.findOrCreatePoi(any()),
    ).thenAnswer((_) async => 501);
    when(
      () => mockTripRepository.createPoiFavorite(
        poiId: any(named: 'poiId'),
        note: any(named: 'note'),
      ),
    ).thenAnswer(
      (_) async => const PoiFavorite(
        id: 88,
        userId: 'user-1',
        poiId: 501,
        favoritedAt: '2026-07-08T12:00:00Z',
      ),
    );
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [tripRepositoryProvider.overrideWithValue(mockTripRepository)],
      child: MaterialApp(theme: AppTheme.light(), home: const ExploreScreen()),
    );
  }

  testWidgets('輸入關鍵字後搜尋並渲染結果卡', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    await tester.enterText(find.byType(TextField), '首里城');
    await tester.tap(find.byTooltip('搜尋'));
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(of: find.byType(Card), matching: find.text('首里城')),
      findsOneWidget,
    );
    expect(find.text('沖繩縣那霸市首里金城町'), findsOneWidget);
    expect(find.text('4.4'), findsOneWidget);
    verify(
      () => mockTripRepository.searchPois(
        query: '首里城',
        region: any(named: 'region'),
        limit: 20,
      ),
    ).called(1);
  });

  testWidgets('點 heart 將搜尋結果 find-or-create 後加入收藏', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    await tester.enterText(find.byType(TextField), '首里城');
    await tester.tap(find.byTooltip('搜尋'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('加入收藏'));
    await tester.pump();
    await tester.pump();

    verify(
      () => mockTripRepository.findOrCreatePoi(shuriSearchResult),
    ).called(1);
    verify(() => mockTripRepository.createPoiFavorite(poiId: 501)).called(1);
  });

  testWidgets('已收藏結果顯示已收藏 heart，點擊後取消收藏', (tester) async {
    when(() => mockTripRepository.fetchPoiFavorites()).thenAnswer(
      (_) async => const [
        PoiFavorite(
          id: 88,
          userId: 'user-1',
          poiId: 501,
          favoritedAt: '2026-07-08T12:00:00Z',
          poiName: '首里城',
          poiType: 'attraction',
        ),
      ],
    );
    when(
      () => mockTripRepository.deletePoiFavorite(any()),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pump();

    await tester.enterText(find.byType(TextField), '首里城');
    await tester.tap(find.byTooltip('搜尋'));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('取消收藏'), findsOneWidget);

    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pump();

    verify(() => mockTripRepository.deletePoiFavorite(88)).called(1);
  });
}
