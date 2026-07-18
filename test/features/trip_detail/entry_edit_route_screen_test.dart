import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/entry_edit_route_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

const _entry = TimelineEntry(
  id: 11,
  sortOrder: 0,
  startTime: '09:00',
  endTime: '10:00',
  title: '首里城',
  description: '世界遺產',
  version: 2,
);

Widget _buildApp(_MockTripRepository repository) {
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(
        path: '/edit',
        builder: (context, state) =>
            const EntryEditRouteScreen(tripId: 'trip-1', entryId: 11),
      ),
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) => const Scaffold(body: Text('行程頁')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      tripRepositoryProvider.overrideWithValue(repository),
      entryDetailProvider((
        tripId: 'trip-1',
        entryId: 11,
      )).overrideWith((ref) => Stream.value(_entry)),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('編輯停留點 route 使用取消／儲存 header 且不重複底部按鈕', (tester) async {
    final repository = _MockTripRepository();
    when(
      () => repository.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repository.recomputeTravel(tripId: 'trip-1'),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('儲存'), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(find.byKey(const ValueKey('entry-edit-title')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '更新後的說明',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateEntry(
        tripId: 'trip-1',
        entryId: 11,
        expectedVersion: 2,
        description: '更新後的說明',
        startTime: '09:00',
        endTime: '10:00',
      ),
    ).called(1);
    expect(find.text('行程頁'), findsOneWidget);
  });
}
