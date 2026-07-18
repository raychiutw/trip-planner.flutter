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
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

const _days = [
  TripDay(id: 1, dayNum: 1, title: '抵達', version: 0),
  TripDay(id: 2, dayNum: 2, title: '市區', version: 0),
];

Widget _buildScreen(_MockTripRepository repo, EntryRouteAction action) {
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
  return ProviderScope(
    overrides: [
      tripRepositoryProvider.overrideWithValue(repo),
      tripDaysProvider('trip-1').overrideWith((ref) => Stream.value(_days)),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
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

  testWidgets('move：選目標 day 後呼叫 moveEntry 並回行程頁', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.moveEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        targetDayId: any(named: 'targetDayId'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildScreen(repo, EntryRouteAction.move));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DAY 2'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-action-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.moveEntry(tripId: 'trip-1', entryId: 11, targetDayId: 2),
    ).called(1);
    expect(find.text('trip trip-1'), findsOneWidget);
  });
}
