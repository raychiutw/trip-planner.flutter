import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trip_detail/widgets/entry_edit_sheet.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

class _MockPoiRepository extends Mock implements PoiRepository {}

const _entry = TimelineEntry(
  id: 11,
  sortOrder: 0,
  startTime: '09:00',
  endTime: '10:00',
  title: '首里城',
  description: '世界遺產',
  version: 2,
);

TripDay _day(int dayNum, String date) =>
    TripDay(id: dayNum, dayNum: dayNum, date: date, version: 0);

Future<void> _open(
  WidgetTester tester,
  _MockTripRepository repo,
  EntryEditArgs args, {
  PoiRepository? poiRepo,
  List<PoiFavorite> favorites = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        tripDaysProvider(
          't1',
        ).overrideWith((ref) => Stream.value(const <TripDay>[])),
        favoritesProvider.overrideWith((ref) => Stream.value(favorites)),
        if (poiRepo != null) poiRepositoryProvider.overrideWithValue(poiRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showEntryEditSheet(context, tripId: 't1', args: args),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  group('entryTimeRangeValid', () {
    test('皆 null / 任一 null → true', () {
      expect(entryTimeRangeValid(null, null), isTrue);
      expect(
        entryTimeRangeValid(const TimeOfDay(hour: 9, minute: 0), null),
        isTrue,
      );
      expect(
        entryTimeRangeValid(null, const TimeOfDay(hour: 9, minute: 0)),
        isTrue,
      );
    });
    test('end > start → true；end <= start → false', () {
      expect(
        entryTimeRangeValid(
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 10, minute: 0),
        ),
        isTrue,
      );
      expect(
        entryTimeRangeValid(
          const TimeOfDay(hour: 10, minute: 0),
          const TimeOfDay(hour: 10, minute: 0),
        ),
        isFalse,
      );
      expect(
        entryTimeRangeValid(
          const TimeOfDay(hour: 11, minute: 0),
          const TimeOfDay(hour: 10, minute: 0),
        ),
        isFalse,
      );
    });
  });

  testWidgets('編輯模式：不顯示 legacy 標題欄 + 送出呼叫 updateEntry', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.recomputeTravel(tripId: 't1')).thenAnswer((_) async {});

    await _open(tester, repo, const EntryEditExisting(_entry));
    expect(find.byKey(const ValueKey('entry-edit-title')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateEntry(
        tripId: 't1',
        entryId: 11,
        expectedVersion: 2,
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).called(1);
    verify(() => repo.recomputeTravel(tripId: 't1')).called(1);
  });

  testWidgets('編輯模式：起訖時間在描述欄上方', (tester) async {
    final repo = _MockTripRepository();
    await _open(tester, repo, const EntryEditExisting(_entry));

    final startTop = tester
        .getTopLeft(find.byKey(const ValueKey('entry-edit-start')))
        .dy;
    final endTop = tester
        .getTopLeft(find.byKey(const ValueKey('entry-edit-end')))
        .dy;
    final descTop = tester
        .getTopLeft(find.byKey(const ValueKey('entry-edit-desc')))
        .dy;

    expect(startTop, lessThan(descTop));
    expect(endTop, lessThan(descTop));
  });

  testWidgets('新增模式：送出呼叫 addEntryToDay(source custom)', (tester) async {
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
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});

    await _open(tester, repo, const EntryEditNew(2));
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '自由活動',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 't1',
        dayNum: 2,
        title: '自由活動',
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'custom',
      ),
    ).called(1);
    verify(() => repo.recomputeTravel(tripId: 't1', day: '2')).called(1);
  });

  testWidgets('新增模式：搜尋 → 選 POI → 送出帶座標(source user-explore)', (tester) async {
    final repo = _MockTripRepository();
    final poiRepo = _MockPoiRepository();
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
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => poiRepo.searchPois(
        q: any(named: 'q'),
        region: any(named: 'region'),
      ),
    ).thenAnswer(
      (_) async => const [
        PoiSearchResult(
          placeId: 'p1',
          name: '沖繩美麗海水族館',
          address: '沖縄県国頭郡本部町',
          lat: 26.6942,
          lng: 127.8778,
          category: '景點',
          rating: 4.6,
        ),
      ],
    );

    await _open(tester, repo, const EntryEditNew(2), poiRepo: poiRepo);
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '美麗海',
    );
    await tester.tap(find.byKey(const ValueKey('entry-poi-search-btn')));
    await tester.pumpAndSettle();
    // 結果清單出現 → 點選帶入
    await tester.tap(find.byKey(const ValueKey('poi-result-p1')));
    await tester.pumpAndSettle();
    // 收合成已選地點卡
    expect(find.byKey(const ValueKey('entry-poi-selected')), findsOneWidget);
    expect(find.text('已帶入座標'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 't1',
        dayNum: 2,
        title: '沖繩美麗海水族館',
        description: any(named: 'description'),
        lat: 26.6942,
        lng: 127.8778,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'user-explore',
      ),
    ).called(1);
  });

  testWidgets('新增模式：從收藏(有座標)選取 → 送出帶座標', (tester) async {
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
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});

    await _open(
      tester,
      repo,
      const EntryEditNew(2),
      favorites: const [
        // 有座標 → 應列出且可選
        PoiFavorite(
          id: 5,
          userId: 'u1',
          poiId: 500,
          favoritedAt: '2026-01-01',
          poiName: '古宇利島',
          poiAddress: '沖縄県今帰仁村',
          poiType: '景點',
          poiLat: 26.7028,
          poiLng: 128.0158,
        ),
        // 無座標 → 不應列出
        PoiFavorite(
          id: 6,
          userId: 'u1',
          poiId: 600,
          favoritedAt: '2026-01-02',
          poiName: '無座標地點',
        ),
      ],
    );

    // 有座標的收藏可選,無座標的不出現
    expect(find.byKey(const ValueKey('fav-result-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('fav-result-6')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('fav-result-5')));
    await tester.pumpAndSettle();
    // 收合成已選地點卡
    expect(find.byKey(const ValueKey('entry-poi-selected')), findsOneWidget);
    expect(find.text('已帶入座標'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 't1',
        dayNum: 2,
        title: '古宇利島',
        description: any(named: 'description'),
        lat: 26.7028,
        lng: 128.0158,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'user-explore',
      ),
    ).called(1);
  });

  testWidgets('新增模式：可切換加入日期', (tester) async {
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
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});

    await _open(
      tester,
      repo,
      EntryEditNew(1, days: [_day(1, '2026-07-01'), _day(3, '2026-07-03')]),
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '自由活動',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAY 3 · 2026-07-03').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 't1',
        dayNum: 3,
        title: '自由活動',
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'custom',
      ),
    ).called(1);
    verify(() => repo.recomputeTravel(tripId: 't1', day: '3')).called(1);
  });

  testWidgets('標題清空 → 送出鈕 disabled', (tester) async {
    final repo = _MockTripRepository();
    await _open(tester, repo, const EntryEditNew(1));
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('entry-edit-submit')),
    );
    expect(button.onPressed, isNull);
  });
}
