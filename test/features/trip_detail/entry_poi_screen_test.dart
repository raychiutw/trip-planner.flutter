import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart';
import 'package:tripline/features/trip_detail/entry_poi_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

class _MockPoiRepository extends Mock implements PoiRepository {}

const _entry = TimelineEntry(
  id: 11,
  sortOrder: 0,
  title: '首里城',
  version: 2,
  entryPoisVersion: '4',
  master: EntryPoiInfo(
    poiId: 501,
    name: '首里城公園',
    type: 'attraction',
    rating: 4.4,
    note: '世界遺產',
  ),
  alternates: [
    EntryPoiInfo(poiId: 502, name: '玉陵', type: 'attraction', sortOrder: 2),
    EntryPoiInfo(poiId: 503, name: '識名園', type: 'attraction', sortOrder: 3),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  _MockTripRepository repo, {
  _MockPoiRepository? poiRepo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        entryDetailProvider((
          tripId: 't1',
          entryId: 11,
        )).overrideWith((ref) => Stream.value(_entry)),
        tripDaysProvider(
          't1',
        ).overrideWith((ref) => Stream.value(const <TripDay>[])),
        if (poiRepo != null) poiRepositoryProvider.overrideWithValue(poiRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const EntryPoiScreen(tripId: 't1', entryId: 11),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(
    () => registerFallbackValue(const PoiSearchResult(placeId: 'x', name: 'x')),
  );

  testWidgets('顯示正選 + 備選 + 加入備選鈕', (tester) async {
    await _pump(tester, _MockTripRepository());
    expect(find.text('首里城公園'), findsOneWidget);
    expect(find.text('玉陵'), findsOneWidget);
    expect(find.text('識名園'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-alternate')), findsOneWidget);
  });

  testWidgets('設為正選 → setEntryMaster(poiId, entryPoisVersion)', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.setEntryMaster(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {});
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('alt-setmaster-502')));
    await tester.pumpAndSettle();

    verify(
      () => repo.setEntryMaster(
        tripId: 't1',
        entryId: 11,
        poiId: 502,
        entryPoisVersion: '4',
      ),
    ).called(1);
  });

  testWidgets('移除備選 → removeEntryAlternate', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.removeEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {});
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('alt-remove-502')));
    await tester.pumpAndSettle();

    verify(
      () => repo.removeEntryAlternate(
        tripId: 't1',
        entryId: 11,
        poiId: 502,
        entryPoisVersion: '4',
      ),
    ).called(1);
  });

  testWidgets('編輯資訊 → 改備註 → 儲存呼叫 updateEntryPoi', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.updateEntryPoi(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        note: any(named: 'note'),
        poiType: any(named: 'poiType'),
        reservation: any(named: 'reservation'),
      ),
    ).thenAnswer((_) async {});
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('poi-edit-master')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('poi-note')), '記得拍照');
    await tester.tap(find.byKey(const ValueKey('poi-save')));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateEntryPoi(
        tripId: 't1',
        entryId: 11,
        poiId: 501,
        note: '記得拍照',
        poiType: 'attraction',
        reservation: any(named: 'reservation'),
      ),
    ).called(1);
  });

  testWidgets('加入備選 → 搜尋選結果 → addEntryAlternate', (tester) async {
    final repo = _MockTripRepository();
    final poiRepo = _MockPoiRepository();
    when(
      () => repo.addEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poi: any(named: 'poi'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => poiRepo.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => const [PoiSearchResult(placeId: 'p9', name: '通堂拉麵')],
    );
    await _pump(tester, repo, poiRepo: poiRepo);

    await tester.tap(find.byKey(const ValueKey('add-alternate')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('alt-search-field')),
      '拉麵',
    );
    await tester.tap(find.byKey(const ValueKey('alt-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alt-result-p9')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryAlternate(
        tripId: 't1',
        entryId: 11,
        poi: any(named: 'poi'),
        entryPoisVersion: '4',
      ),
    ).called(1);
  });
}
