import 'dart:async';

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

  Future<void> pumpScreen(
    WidgetTester tester, {
    ThemeData? theme,
    TextScaler textScaler = TextScaler.noScaling,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          tripRepositoryProvider.overrideWithValue(repository),
          tripPrintActionsProvider.overrideWithValue(printActions),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: const TripPrintScreen(tripId: 'trip-1'),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
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

  testWidgets('初始 loading 透過 live region 宣告', (tester) async {
    final pending = Completer<Trip>();
    when(
      () => repository.fetchTrip('trip-1'),
    ).thenAnswer((_) => pending.future);

    await pumpScreen(tester, settle: false);
    await tester.pump();

    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('trip-print-loading-live')),
          )
          .properties
          .liveRegion,
      isTrue,
    );

    pending.complete(trip);
    await tester.pumpAndSettle();
  });

  testWidgets('列印與 PDF 按鈕呼叫注入的 action service', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('trip-print-do')));
    await tester.pumpAndSettle();
    expect(find.text('已送出列印'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trip-print-more')));
    await tester.pumpAndSettle();
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

  testWidgets('notes 載入失敗顯示 partial-data notice 且可重試', (tester) async {
    var shouldFail = true;
    when(() => repository.fetchNotes('trip-1')).thenAnswer((_) async {
      if (shouldFail) throw Exception('notes down');
      return notes;
    });

    await pumpScreen(tester);

    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.text('首里城公園'), findsOneWidget);
    expect(find.text('航班'), findsNothing);
    final notice = tester.widget<Semantics>(
      find.byKey(const ValueKey('trip-print-partial-notice')),
    );
    expect(notice.properties.liveRegion, isTrue);
    expect(find.textContaining('行程筆記載入失敗'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.byKey(const ValueKey('trip-print-notes-retry')));
    await tester.pumpAndSettle();

    expect(find.text('航班'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trip-print-partial-notice')),
      findsNothing,
    );
  });

  testWidgets('行程載入失敗時顯示可重試 live error state', (tester) async {
    var shouldFail = true;
    when(() => repository.fetchTrip('trip-1')).thenAnswer((_) async {
      if (shouldFail) throw Exception('trip down');
      return trip;
    });

    await pumpScreen(tester);

    final error = tester.widget<Semantics>(
      find.byKey(const ValueKey('trip-print-error')),
    );
    expect(error.properties.liveRegion, isTrue);
    expect(find.text('行程載入失敗，請稍後重試'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-print-document')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-print-error')), findsNothing);
  });

  testWidgets('regular dark 與最大文字仍限制內容寬度並保留 Header actions', (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpScreen(
      tester,
      theme: AppTheme.dark(),
      textScaler: const TextScaler.linear(3),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('trip-print-content'))).width,
      lessThanOrEqualTo(720),
    );
    expect(find.byKey(const ValueKey('trip-print-do')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-print-more')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-avatar-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
