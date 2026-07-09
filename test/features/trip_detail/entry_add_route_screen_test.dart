import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/entry_add_route_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

const _days = [
  TripDay(id: 1, dayNum: 1, title: '抵達', version: 0),
  TripDay(id: 2, dayNum: 2, title: '市區', version: 0),
];

Widget _buildScreen(_MockTripRepository repo, {int initialDayNum = 2}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            EntryAddRouteScreen(tripId: 'trip-1', initialDayNum: initialDayNum),
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
      tripDaysProvider('trip-1').overrideWith((ref) => Stream.value(_days)),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
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
    expect(find.text('DAY 2 · 市區'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '自由活動',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '自由活動',
        description: any(named: 'description'),
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

    await tester.tap(find.text('DAY 2 · 市區'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '晚餐',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 'trip-1',
        dayNum: 2,
        title: '晚餐',
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'custom',
      ),
    ).called(1);
  });
}
