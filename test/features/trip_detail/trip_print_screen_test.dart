import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/trip_print_data.dart';
import 'package:tripline/features/trip_detail/trip_pdf_service.dart';
import 'package:tripline/features/trip_detail/trip_print_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

class FakeTripPrintActions implements TripPrintActions {
  int printCalls = 0;
  int sharePdfCalls = 0;
  TripPrintData? printedData;
  TripPrintData? sharedData;

  @override
  Future<void> print(TripPrintData data) async {
    printCalls++;
    printedData = data;
  }

  @override
  Future<void> sharePdf(TripPrintData data) async {
    sharePdfCalls++;
    sharedData = data;
  }
}

void main() {
  late MockTripRepository repository;
  late FakeTripPrintActions printActions;

  const trip = Trip(
    id: 'trip-1',
    name: 'okinawa-trip-2026',
    title: '沖繩家族旅行',
    countries: 'JP',
    destinations: [TripDestination(name: '那霸')],
  );
  const days = [
    TripDay(
      id: 10,
      dayNum: 1,
      date: '2026-10-01',
      label: '抵達日',
      version: 1,
      timeline: [
        TimelineEntry(
          id: 101,
          sortOrder: 0,
          title: '首里城公園',
          version: 1,
          startTime: '09:00',
          endTime: '10:30',
          travel: Travel(
            type: 'transit',
            submode: 'hsr',
            min: 18,
            distanceM: 950,
          ),
        ),
        TimelineEntry(
          id: 102,
          sortOrder: 1,
          title: '園區內移動',
          version: 1,
          travel: Travel(type: 'transit', sameplace: true),
        ),
      ],
    ),
  ];
  const notes = TripNotes(
    flights: [TripFlight(id: 1, sortOrder: 0, version: 1, flightNo: 'BR112')],
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          tripRepositoryProvider.overrideWithValue(repository),
          tripPrintActionsProvider.overrideWithValue(printActions),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TripPrintScreen(tripId: 'trip-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = MockTripRepository();
    printActions = FakeTripPrintActions();
    when(() => repository.fetchTrip('trip-1')).thenAnswer((_) async => trip);
    when(() => repository.fetchDays('trip-1')).thenAnswer((_) async => days);
    when(() => repository.fetchNotes('trip-1')).thenAnswer((_) async => notes);
  });

  testWidgets('顯示列印文件、日程與 notes', (tester) async {
    await pumpScreen(tester);

    expect(find.text('列印預覽'), findsOneWidget);
    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.text('2026-10-01 · 那霸 · 1 天'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('09:00-10:30'), findsOneWidget);
    expect(find.text('首里城公園'), findsOneWidget);
    expect(find.text('高鐵 · 18 分 · 0.9km'), findsOneWidget);
    expect(find.text('不需計算路程'), findsOneWidget);
    expect(find.text('航班'), findsOneWidget);
    expect(find.text('BR112'), findsOneWidget);
  });

  testWidgets('列印與 PDF 按鈕呼叫注入的 action service', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('trip-print-do')));
    await tester.pumpAndSettle();
    expect(find.text('已送出列印'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trip-print-pdf')));
    await tester.pumpAndSettle();

    expect(printActions.printCalls, 1);
    expect(printActions.sharePdfCalls, 1);
    expect(printActions.printedData?.displayTitle, '沖繩家族旅行');
    expect(
      printActions.sharedData?.pdfFileName(now: DateTime(2026, 7, 8)),
      '沖繩家族旅行-2026-07-08.pdf',
    );
    expect(find.text('PDF 已建立'), findsOneWidget);
  });

  testWidgets('notes 載入失敗時仍顯示列印文件主體', (tester) async {
    when(
      () => repository.fetchNotes('trip-1'),
    ).thenThrow(Exception('notes down'));

    await pumpScreen(tester);

    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.text('首里城公園'), findsOneWidget);
    expect(find.text('航班'), findsNothing);
  });

  testWidgets('行程載入失敗時顯示 error state', (tester) async {
    when(
      () => repository.fetchTrip('trip-1'),
    ).thenThrow(Exception('trip down'));

    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('trip-print-error')), findsOneWidget);
    expect(find.text('行程載入失敗，請稍後重試'), findsOneWidget);
  });
}
