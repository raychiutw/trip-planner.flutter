import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;
import 'package:tripline/features/trips/widgets/destination_picker.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockPoiRepo extends Mock implements PoiRepository {}

void main() {
  late _MockPoiRepo poiRepo;

  setUp(() => poiRepo = _MockPoiRepo());

  void stubSearch(Future<List<PoiSearchResult>> Function() answer) {
    when(
      () => poiRepo.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<void> search(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [poiRepositoryProvider.overrideWithValue(poiRepo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DestinationPicker(
              destinations: const [],
              onAdd: (_) {},
              onRemove: (_) {},
              onReorder: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('dest-poi-search')), '東京');
    await tester.tap(find.byKey(const ValueKey('dest-poi-search-btn')));
    await tester.pumpAndSettle();
  }

  testWidgets('搜尋失敗顯示人話文案（liveRegion），不外洩例外字串', (tester) async {
    stubSearch(() async => throw Exception('SECRET-trace'));
    await search(tester);

    expect(find.text('搜尋失敗，請稍後再試'), findsOneWidget);
    expect(find.textContaining('SECRET-trace'), findsNothing);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('dest-search-status')))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
  });

  testWidgets('查無結果顯示空狀態文案；再次搜尋有結果後文案消失', (tester) async {
    var empty = true;
    stubSearch(
      () async => empty
          ? const <PoiSearchResult>[]
          : const [PoiSearchResult(placeId: 'p1', name: '東京')],
    );
    await search(tester);
    expect(find.text('找不到符合的地點'), findsOneWidget);

    empty = false;
    await tester.tap(find.byKey(const ValueKey('dest-poi-search-btn')));
    await tester.pumpAndSettle();
    expect(find.text('找不到符合的地點'), findsNothing);
    expect(find.byKey(const ValueKey('poi-result-p1')), findsOneWidget);
  });
}
