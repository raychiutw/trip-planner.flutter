import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/edit_entry_screen.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  const tripId = 'okinawa-trip-2026';
  const entry = TimelineEntry(
    id: 101,
    dayId: 11,
    sortOrder: 0,
    startTime: '10:00',
    endTime: '11:30',
    title: '首里城公園',
    description: '世界遺產',
    source: 'google',
    version: 7,
    entryPoisVersion: '3',
    master: EntryPoiInfo(
      poiId: 501,
      name: '首里城公園',
      type: 'attraction',
      note: '黃昏時段去',
    ),
    alternates: [
      EntryPoiInfo(poiId: 502, name: '玉陵', type: 'attraction', sortOrder: 2),
      EntryPoiInfo(poiId: 503, name: '識名園', type: 'attraction', sortOrder: 3),
    ],
  );

  late MockTripRepository mockTripRepository;

  setUp(() {
    mockTripRepository = MockTripRepository();
    when(
      () => mockTripRepository.fetchEntry(tripId, 101),
    ).thenAnswer((_) async => entry);
    when(
      () => mockTripRepository.updateEntry(
        any(),
        any(),
        expectedVersion: any(named: 'expectedVersion'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        description: any(named: 'description'),
      ),
    ).thenAnswer(
      (_) async => const TimelineEntry(
        id: 101,
        dayId: 11,
        sortOrder: 0,
        startTime: '10:30',
        endTime: '12:00',
        title: '首里城公園',
        description: '改成上午晚點去',
        version: 8,
      ),
    );
    when(
      () => mockTripRepository.deleteEntry(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockTripRepository.deleteEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer(
      (_) async => const EntryPoisMutationResult(
        entryId: 101,
        poiId: 502,
        entryPoisVersion: '4',
      ),
    );
    when(
      () => mockTripRepository.reorderEntryAlternates(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        orderedPoiIds: any(named: 'orderedPoiIds'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer(
      (_) async => const EntryAlternatesReorderResult(
        entryId: 101,
        order: [503, 502],
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

  Widget buildRouterApp() {
    final router = GoRouter(
      initialLocation: '/trips/$tripId/stop/101/edit',
      routes: [
        GoRoute(
          path: '/trips/:tripId/stop/:entryId/edit',
          builder: (context, state) => EditEntryScreen(
            tripId: state.pathParameters['tripId']!,
            entryId: int.parse(state.pathParameters['entryId']!),
          ),
        ),
        GoRoute(
          path: '/trips/:tripId/stop/:entryId/change-poi',
          builder: (context, state) => Scaffold(
            body: Text(
              'change-poi:${state.pathParameters['entryId']}:${state.uri.queryParameters['mode'] ?? 'master'}',
            ),
          ),
        ),
        GoRoute(
          path: '/trips/:tripId/stop/:entryId/copy',
          builder: (context, state) =>
              Scaffold(body: Text('copy:${state.pathParameters['entryId']}')),
        ),
        GoRoute(
          path: '/trips/:tripId/stop/:entryId/move',
          builder: (context, state) =>
              Scaffold(body: Text('move:${state.pathParameters['entryId']}')),
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

  testWidgets('載入 entry 顯示正選、備選、時間與描述欄位', (tester) async {
    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('編輯景點'), findsOneWidget);
    expect(find.text('首里城公園'), findsOneWidget);
    expect(find.text('備選：玉陵、識名園'), findsOneWidget);
    expect(find.text('備選景點'), findsOneWidget);
    expect(find.text('玉陵'), findsOneWidget);
    expect(find.text('識名園'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '10:00'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '11:30'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '世界遺產'), findsOneWidget);
  });

  testWidgets('置換與加入備選按鈕導向 change-poi route', (tester) async {
    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('edit-entry-change-poi')));
    await tester.pumpAndSettle();
    expect(find.text('change-poi:101:master'), findsOneWidget);

    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('edit-entry-add-alternate')));
    await tester.pumpAndSettle();
    expect(find.text('change-poi:101:alternate'), findsOneWidget);
  });

  testWidgets('複製與移動按鈕導向 entry action routes', (tester) async {
    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('edit-entry-copy')));
    await tester.pumpAndSettle();
    expect(find.text('copy:101'), findsOneWidget);

    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('edit-entry-move')));
    await tester.pumpAndSettle();
    expect(find.text('move:101'), findsOneWidget);
  });

  testWidgets('移除備選時 DELETE alternate 並帶 entryPoisVersion', (tester) async {
    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('edit-entry-alt-delete-502')));
    await tester.pumpAndSettle();
    expect(find.text('移除備選？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '移除'));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.deleteEntryAlternate(
        tripId: tripId,
        entryId: 101,
        poiId: 502,
        entryPoisVersion: '3',
      ),
    ).called(1);
    expect(find.text('編輯景點'), findsOneWidget);
  });

  testWidgets('調整備選順序時 PATCH reorder 並帶完整 poiId 順序', (tester) async {
    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('edit-entry-alt-down-502')));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.reorderEntryAlternates(
        tripId: tripId,
        entryId: 101,
        orderedPoiIds: const [503, 502],
        entryPoisVersion: '3',
      ),
    ).called(1);
    expect(find.text('編輯景點'), findsOneWidget);
  });

  testWidgets('儲存時 PATCH entry 並帶 expectedVersion', (tester) async {
    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('edit-entry-start-time')),
      '10:30',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-entry-end-time')),
      '12:00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-entry-description')),
      '改成上午晚點去',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    final saveButton = find.byKey(const ValueKey('edit-entry-save')).last;
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.updateEntry(
        tripId,
        101,
        expectedVersion: 7,
        startTime: '10:30',
        endTime: '12:00',
        description: '改成上午晚點去',
      ),
    ).called(1);
    verify(() => mockTripRepository.recomputeTravel(tripId)).called(1);
    expect(find.text('trip:$tripId'), findsOneWidget);
  });

  testWidgets('刪除 entry 後回到 timeline 並觸發 recompute', (tester) async {
    await tester.pumpWidget(buildRouterApp());
    await tester.pump();
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    final deleteButton = find.byKey(const ValueKey('edit-entry-delete')).last;
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '刪除'));
    await tester.pumpAndSettle();

    verify(() => mockTripRepository.deleteEntry(tripId, 101)).called(1);
    verify(() => mockTripRepository.recomputeTravel(tripId)).called(1);
    expect(find.text('trip:$tripId'), findsOneWidget);
  });
}
