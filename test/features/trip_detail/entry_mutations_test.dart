import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/entry_mutations.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/segment.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockRepo extends Mock implements TripRepository {}

const _entry = TimelineEntry(
  id: 11,
  sortOrder: 0,
  title: '首里城',
  version: 1,
  entryPoisVersion: '4',
  master: EntryPoiInfo(poiId: 101, name: '目前'),
);
const _alternate = EntryPoiInfo(poiId: 102, name: '備選');

void main() {
  late _MockRepo repo;
  final builds = <String, int>{};

  ProviderContainer makeContainer() {
    builds.clear();
    int bump(String key) => builds[key] = (builds[key] ?? 0) + 1;
    final c = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        tripDetailProvider.overrideWith((ref, id) {
          bump('detail');
          return Stream.value(const Trip(id: 't', name: 't'));
        }),
        tripDaysProvider.overrideWith((ref, id) {
          bump('days');
          return Stream.value(const <TripDay>[]);
        }),
        tripSegmentsProvider.overrideWith((ref, id) {
          bump('segments');
          return Stream.value(const <TripSegment>[]);
        }),
        entryDetailProvider.overrideWith((ref, key) {
          bump('entry');
          return Stream.value(_entry);
        }),
      ],
    );
    addTearDown(c.dispose);
    for (final p in [
      tripDetailProvider('t'),
      tripDaysProvider('t'),
      tripSegmentsProvider('t'),
      entryDetailProvider((tripId: 't', entryId: 11)),
    ]) {
      c.listen(p, (_, _) {});
    }
    return c;
  }

  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
  });

  test('refreshAfter:宣告改了什麼,失效表決定重抓哪些 provider', () async {
    final c = makeContainer();
    final m = c.read(entryMutationsProvider('t').notifier);
    final before = Map.of(builds);

    m.refreshAfter({TripChange.days, TripChange.segments});
    await Future<void>.delayed(Duration.zero);
    expect(builds['days'], before['days']! + 1);
    expect(builds['segments'], before['segments']! + 1);
    expect(builds['detail'], before['detail']);
    expect(builds['entry'], before['entry']);

    m.refreshAfter({TripChange.entry}, entryId: 11);
    await Future<void>.delayed(Duration.zero);
    expect(builds['entry'], before['entry']! + 1);
  });

  test('recomputeTravel:失敗可忽略,回 false 不 throw;auto 失敗標記該日停滯,成功清掉', () async {
    when(
      () => repo.recomputeTravel(tripId: 't', day: '2'),
    ).thenThrow(const ApiError(status: 500, code: 'X', message: 'boom'));
    final c = makeContainer();
    final m = c.read(entryMutationsProvider('t').notifier);

    expect(await m.recomputeTravel(dayNum: 2), isFalse);
    expect(c.read(entryMutationsProvider('t')).stalledDays, isEmpty);

    expect(await m.recomputeTravel(dayNum: 2, auto: true), isFalse);
    expect(c.read(entryMutationsProvider('t')).stalledDays, {2});

    when(
      () => repo.recomputeTravel(tripId: 't', day: '2'),
    ).thenAnswer((_) async {});
    expect(await m.recomputeTravel(dayNum: 2, auto: true), isTrue);
    expect(c.read(entryMutationsProvider('t')).stalledDays, isEmpty);
    // 沒指定 day → 整趟。
    await m.recomputeTravel();
    verify(() => repo.recomputeTravel(tripId: 't', day: 'all')).called(1);
  });

  test('requestGapRecompute:同一組缺口只請求一次', () async {
    final c = makeContainer();
    final m = c.read(entryMutationsProvider('t').notifier);
    m.requestGapRecompute(dayNum: 1, gapKey: '11-12');
    m.requestGapRecompute(dayNum: 1, gapKey: '11-12');
    await Future<void>.delayed(Duration.zero);
    verify(() => repo.recomputeTravel(tripId: 't', day: '1')).called(1);
  });

  testWidgets('setMaster:先確認;確認後設正選、重算該日、重抓 days / segments / entry', (
    tester,
  ) async {
    when(
      () => repo.setEntryMaster(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {});
    final c = makeContainer();
    late BuildContext captured;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              captured = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    );
    final before = Map.of(builds);
    final done = c
        .read(entryMutationsProvider('t').notifier)
        .setMaster(
          captured,
          entry: _entry,
          alternate: _alternate,
          sameDayEntries: const [_entry],
          dayNum: 1,
        );
    await tester.pumpAndSettle();
    expect(find.text('設為正選？'), findsOneWidget);
    verifyNever(
      () => repo.setEntryMaster(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    );
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '設為正選'));
    await tester.pumpAndSettle();

    expect(await done, isTrue);
    verify(
      () => repo.setEntryMaster(
        tripId: 't',
        entryId: 11,
        poiId: 102,
        entryPoisVersion: '4',
      ),
    ).called(1);
    verify(() => repo.recomputeTravel(tripId: 't', day: '1')).called(1);
    expect(builds['days'], before['days']! + 1);
    expect(builds['segments'], before['segments']! + 1);
    expect(builds['entry'], before['entry']! + 1);
  });

  testWidgets('setMaster:409 → 提示已更新、重抓 entry,不重算交通', (tester) async {
    when(
      () => repo.setEntryMaster(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenThrow(const ApiError(status: 409, code: 'STALE', message: 'x'));
    final c = makeContainer();
    late BuildContext captured;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              captured = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    );
    final before = Map.of(builds);
    final done = c
        .read(entryMutationsProvider('t').notifier)
        .setMaster(
          captured,
          entry: _entry,
          alternate: _alternate,
          sameDayEntries: const [_entry],
          dayNum: 1,
        );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '設為正選'));
    await tester.pumpAndSettle();

    expect(await done, isFalse);
    expect(find.textContaining('已重新載入'), findsOneWidget);
    verifyNever(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    );
    expect(builds['entry'], before['entry']! + 1);
  });

  test('crossRegionWarning:離本日其他點超過 50km 才警告', () {
    const far = EntryPoiInfo(poiId: 9, name: '遠', lat: 35.0, lng: 139.0);
    const near = EntryPoiInfo(poiId: 9, name: '近', lat: 26.22, lng: 127.69);
    const siblings = [
      TimelineEntry(
        id: 1,
        sortOrder: 0,
        title: 'a',
        version: 0,
        master: EntryPoiInfo(poiId: 1, name: 'a', lat: 26.21, lng: 127.68),
      ),
    ];
    expect(crossRegionWarning(far, siblings, 2), contains('可能跨區'));
    expect(crossRegionWarning(near, siblings, 2), isNull);
    expect(crossRegionWarning(far, const [], 2), isNull);
  });
}
