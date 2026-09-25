import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/entry_action_route_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

const _days = [
  TripDay(
    id: 1,
    dayNum: 1,
    title: '抵達',
    version: 0,
    timeline: [
      TimelineEntry(id: 11, sortOrder: 0, title: '首里城', version: 1),
      TimelineEntry(id: 12, sortOrder: 1, title: '午餐', version: 1),
    ],
  ),
  TripDay(
    id: 2,
    dayNum: 2,
    title: '市區',
    version: 0,
    timeline: [TimelineEntry(id: 21, sortOrder: 0, title: '市場', version: 1)],
  ),
];

Widget _buildScreen(
  _MockTripRepository repo,
  EntryRouteAction action, {
  bool useRepositoryDays = false,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => EntryActionRouteScreen(
          tripId: 'trip-1',
          entryId: 11,
          action: action,
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
      if (!useRepositoryDays)
        tripDaysProvider('trip-1').overrideWith((ref) => Stream.value(_days)),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  setUpAll(
    () => registerFallbackValue(<({int id, int sortOrder, int? dayId})>[]),
  );

  testWidgets('複製初載失敗可原地重試並選擇目的 Day', (tester) async {
    final repo = _MockTripRepository();
    var loads = 0;
    when(() => repo.watchDays('trip-1')).thenAnswer((_) {
      loads++;
      return loads == 1
          ? Stream<List<TripDay>>.error(Exception('private network detail'))
          : Stream.value(_days);
    });
    when(
      () => repo.copyEntry(tripId: 'trip-1', entryId: 11, targetDayId: 2),
    ).thenAnswer((_) async => 99);
    await tester.pumpWidget(
      _buildScreen(repo, EntryRouteAction.copy, useRepositoryDays: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('無法載入日期，請稍後再試'), findsOneWidget);
    expect(find.textContaining('private network detail'), findsNothing);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(loads, 2);
    await tester.tap(find.byKey(const ValueKey('entry-action-day-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-action-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.copyEntry(tripId: 'trip-1', entryId: 11, targetDayId: 2),
    ).called(1);
    expect(find.text('trip trip-1'), findsOneWidget);
  });

  testWidgets('移動日期背景失敗與重試期間保留有效選擇', (tester) async {
    final repo = _MockTripRepository();
    final first = StreamController<List<TripDay>>.broadcast();
    final retry = StreamController<List<TripDay>>.broadcast();
    addTearDown(() {
      unawaited(first.close());
    });
    addTearDown(() {
      unawaited(retry.close());
    });
    var loads = 0;
    when(
      () => repo.watchDays('trip-1'),
    ).thenAnswer((_) => ++loads == 1 ? first.stream : retry.stream);
    await tester.pumpWidget(
      _buildScreen(repo, EntryRouteAction.move, useRepositoryDays: true),
    );
    first.add(_days);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-action-day-2')));
    await tester.pump();
    first.addError(Exception('network'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('entry-action-day-2')))
          .selected,
      isTrue,
    );
    await tester.tap(find.text('重試'));
    await tester.pump();
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('entry-action-day-2')))
          .selected,
      isTrue,
    );
    retry.add(_days);
    unawaited(retry.close());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('entry-action-day-2')))
          .selected,
      isTrue,
    );
    expect(find.text('無法載入日期，請稍後再試'), findsNothing);
  });

  testWidgets('只有來源 Day 時說明無其他目的日期且不可送出', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.watchDays('trip-1'),
    ).thenAnswer((_) => Stream.value([_days.first]));
    await tester.pumpWidget(
      _buildScreen(repo, EntryRouteAction.copy, useRepositoryDays: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('目前行程只有一天，無法使用'), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-action-day-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('entry-action-submit')));
    await tester.pump();
    verifyNever(
      () => repo.copyEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        targetDayId: any(named: 'targetDayId'),
      ),
    );
  });

  testWidgets('目的 Day 已消失時不可複製且重新出現不恢復失效選擇', (tester) async {
    final repo = _MockTripRepository();
    final days = StreamController<List<TripDay>>.broadcast();
    addTearDown(() {
      unawaited(days.close());
    });
    when(() => repo.watchDays('trip-1')).thenAnswer((_) => days.stream);
    when(
      () => repo.copyEntry(tripId: 'trip-1', entryId: 11, targetDayId: 2),
    ).thenAnswer((_) async => 99);
    await tester.pumpWidget(
      _buildScreen(repo, EntryRouteAction.copy, useRepositoryDays: true),
    );
    days.add(_days);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-action-day-2')));
    await tester.pump();
    days.add([_days.first]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-action-submit')));
    await tester.pumpAndSettle();
    verifyNever(
      () => repo.copyEntry(tripId: 'trip-1', entryId: 11, targetDayId: 2),
    );
    days.add(_days);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('entry-action-day-2')))
          .selected,
      isFalse,
    );
  });

  testWidgets('移動依最新停留點位置送出兩 Day 且失敗重試保留兩 Day', (tester) async {
    final repo = _MockTripRepository();
    final days = StreamController<List<TripDay>>.broadcast();
    addTearDown(() {
      unawaited(days.close());
    });
    when(() => repo.watchDays('trip-1')).thenAnswer((_) => days.stream);
    var attempts = 0;
    when(
      () => repo.reorderEntries(
        tripId: 'trip-1',
        updates: any(named: 'updates'),
      ),
    ).thenAnswer((_) async {
      if (++attempts == 1) throw Exception('offline');
    });
    await tester.pumpWidget(
      _buildScreen(repo, EntryRouteAction.move, useRepositoryDays: true),
    );
    days.add(_days);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-action-day-2')));
    await tester.pump();
    days.add([
      TripDay(
        id: 1,
        dayNum: 1,
        version: 1,
        timeline: [_days.first.timeline[1], _days.first.timeline[0]],
      ),
      _days.last,
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-action-submit')));
    await tester.pumpAndSettle();
    expect(find.text('移動失敗，請稍後再試'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('entry-action-day-2')))
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('entry-action-submit')));
    await tester.pumpAndSettle();
    verify(
      () => repo.reorderEntries(
        tripId: 'trip-1',
        updates: [
          (id: 12, sortOrder: 0, dayId: 1),
          (id: 21, sortOrder: 0, dayId: 2),
          (id: 11, sortOrder: 1, dayId: 2),
        ],
      ),
    ).called(2);
    expect(find.text('trip trip-1'), findsOneWidget);
  });

  testWidgets('空日期快取後載入失敗仍可重試', (tester) async {
    final repo = _MockTripRepository();
    var loads = 0;
    when(() => repo.watchDays('trip-1')).thenAnswer((_) async* {
      if (++loads == 1) {
        yield [];
        throw Exception('offline');
      }
      yield _days;
    });
    await tester.pumpWidget(
      _buildScreen(repo, EntryRouteAction.copy, useRepositoryDays: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('無法載入日期，請稍後再試'), findsOneWidget);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-action-day-2')), findsOneWidget);
  });

  testWidgets('move route uses the same Move To Day wording', (tester) async {
    final repo = _MockTripRepository();
    await tester.pumpWidget(_buildScreen(repo, EntryRouteAction.move));
    await tester.pumpAndSettle();
    expect(find.text('移到其他 Day'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('移動'), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(find.text('移動停留點'), findsNothing);
    expect(find.text('移動行程'), findsNothing);
  });

  testWidgets('copy：選目標 day 後呼叫 copyEntry 並回行程頁', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.copyEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        targetDayId: any(named: 'targetDayId'),
      ),
    ).thenAnswer((_) async => 99);

    await tester.pumpWidget(_buildScreen(repo, EntryRouteAction.copy));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DAY 2'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-action-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.copyEntry(tripId: 'trip-1', entryId: 11, targetDayId: 2),
    ).called(1);
    expect(find.text('trip trip-1'), findsOneWidget);
  });

  testWidgets('move：選目標 day 後以單次 batch 同步來源與目的 Day', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.moveEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        targetDayId: any(named: 'targetDayId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.reorderEntries(
        tripId: any(named: 'tripId'),
        updates: any(named: 'updates'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildScreen(repo, EntryRouteAction.move));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DAY 2'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-action-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.reorderEntries(
        tripId: 'trip-1',
        updates: [
          (id: 12, sortOrder: 0, dayId: 1),
          (id: 21, sortOrder: 0, dayId: 2),
          (id: 11, sortOrder: 1, dayId: 2),
        ],
      ),
    ).called(1);
    verifyNever(
      () => repo.moveEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        targetDayId: any(named: 'targetDayId'),
      ),
    );
    expect(find.text('trip trip-1'), findsOneWidget);
  });

  testWidgets('copy await 期間頁面卸載，不操作已 dispose 的 ref', (tester) async {
    final repo = _MockTripRepository();
    final pending = Completer<int>();
    when(
      () => repo.copyEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        targetDayId: any(named: 'targetDayId'),
      ),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(_buildScreen(repo, EntryRouteAction.copy));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DAY 2'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-action-submit')));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    pending.complete(99);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('copy pending 與 failure 以 live region 宣告', (tester) async {
    final repo = _MockTripRepository();
    final pending = Completer<int>();
    when(
      () => repo.copyEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        targetDayId: any(named: 'targetDayId'),
      ),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(_buildScreen(repo, EntryRouteAction.copy));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DAY 2'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-action-submit')));
    await tester.pump();

    final progress = tester.widget<Semantics>(
      find.byKey(const ValueKey('entry-action-progress')),
    );
    expect(progress.properties.liveRegion, isTrue);
    expect(find.text('複製中…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byKey(const ValueKey('entry-action-submit')),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );

    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();

    final error = tester.widget<Semantics>(
      find.byKey(const ValueKey('entry-action-error')),
    );
    expect(error.properties.liveRegion, isTrue);
    expect(find.text('複製失敗，請稍後再試'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('entry-action-day-2')))
          .selected,
      isTrue,
    );
  });

  testWidgets('move pending 與 failure 以 live region 宣告', (tester) async {
    final repo = _MockTripRepository();
    final pending = Completer<void>();
    when(
      () => repo.reorderEntries(
        tripId: any(named: 'tripId'),
        updates: any(named: 'updates'),
      ),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(_buildScreen(repo, EntryRouteAction.move));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DAY 2'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-action-submit')));
    await tester.pump();

    final progress = tester.widget<Semantics>(
      find.byKey(const ValueKey('entry-action-progress')),
    );
    expect(progress.properties.liveRegion, isTrue);
    expect(find.text('移動中…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();

    final error = tester.widget<Semantics>(
      find.byKey(const ValueKey('entry-action-error')),
    );
    expect(error.properties.liveRegion, isTrue);
    expect(find.text('移動失敗，請稍後再試'), findsOneWidget);
  });
}
