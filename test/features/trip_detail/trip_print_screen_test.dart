import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

import '../../fixtures/note_content_fixture.dart';

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

  testWidgets('列印預覽保留航班艙等', (tester) async {
    when(() => repository.fetchDays('trip-1')).thenAnswer((_) async => []);
    when(() => repository.fetchNotes('trip-1')).thenAnswer(
      (_) async => const TripNotes(
        flights: [
          TripFlight(
            id: 1,
            sortOrder: 0,
            version: 1,
            airline: '長榮航空',
            flightNo: 'BR112',
            cabinClass: '商務艙',
          ),
        ],
      ),
    );

    await pumpScreen(tester);

    expect(find.textContaining('BR112'), findsOneWidget);
    expect(find.textContaining('商務艙'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('列印預覽的電話保留欄位語意與可複製原文', (tester) async {
    when(() => repository.fetchDays('trip-1')).thenAnswer((_) async => []);
    when(() => repository.fetchNotes('trip-1')).thenAnswer(
      (_) async => const TripNotes(
        lodgings: [
          TripLodging(
            id: 2,
            sortOrder: 0,
            version: 0,
            name: '那霸旅館',
            phone: '+81 98 123 4567',
          ),
        ],
      ),
    );
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);
    expect(find.bySemanticsLabel('電話：+81 98 123 4567'), findsOneWidget);
    expect(find.byType(SelectionArea), findsWidgets);
    expect(find.text('+81 98 123 4567'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('列印預覽保留五區欄位與緊急聯絡語意', (tester) async {
    when(() => repository.fetchDays('trip-1')).thenAnswer((_) async => []);
    when(
      () => repository.fetchNotes('trip-1'),
    ).thenAnswer((_) async => noteContentFixture);
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    try {
      await pumpScreen(tester);
      expect(find.bySemanticsLabel('電子郵件：family@example.com'), findsOneWidget);
      final text = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('trip-print-document')),
              matching: find.byType(Text),
            ),
          )
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
          .join('\n');
      var cursor = 0;
      for (final value in noteContentExpectedOrder) {
        final next = text.indexOf(value, cursor);
        expect(next, greaterThanOrEqualTo(0), reason: '缺少或順序錯誤：$value');
        cursor = next + value.length;
      }
      expect(text, isNot(contains('0 位')));
      await tester.pumpWidget(const SizedBox());
      when(
        () => repository.fetchNotes('trip-1'),
      ).thenAnswer((_) async => emptyNoteContentFixture);
      await pumpScreen(tester);
      expect(find.text('行程筆記'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('列印預覽開啟電話、郵件與安全的 Markdown 連結', (tester) async {
    final launched = <String>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
      }
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    when(() => repository.fetchDays('trip-1')).thenAnswer((_) async => []);
    when(() => repository.fetchNotes('trip-1')).thenAnswer(
      (_) async => TripNotes(
        emergencyContacts: noteContentFixture.emergencyContacts,
        pretripNotes: const [
          TripPretripNote(
            id: 7,
            sortOrder: 0,
            version: 0,
            title: '連結',
            content:
                '[入境文件](https://example.com/a_(b)?x=1&y=2) [拒絕](javascript:alert(1)) [相對](/private) [格式錯誤](https:missing) [參考文件][guide]\n\n[guide]: https://example.com/guide',
          ),
        ],
      ),
    );
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpScreen(tester);
    await tester.tap(find.text('+886 912 345 678'));
    await tester.pumpAndSettle();
    expect(launched, ['tel:+886912345678']);
    await tester.tap(find.text('family@example.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('入境文件'));
    await tester.pumpAndSettle();
    expect(launched, [
      'tel:+886912345678',
      'mailto:family@example.com',
      'https://example.com/a_(b)?x=1&y=2',
    ]);
    await tester.tap(find.text('參考文件'));
    await tester.pumpAndSettle();
    expect(launched.last, 'https://example.com/guide');
    for (final label in ['拒絕', '相對', '格式錯誤']) {
      expect(find.widgetWithText(TextButton, label), findsNothing);
    }
    expect(find.textContaining('[拒絕](javascript:alert(1))'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('筆記連結首次開啟失敗可重試同一目的地', (tester) async {
    final launched = <String>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
        return launched.length > 1;
      }
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    when(() => repository.fetchDays('trip-1')).thenAnswer((_) async => []);
    when(() => repository.fetchNotes('trip-1')).thenAnswer(
      (_) async =>
          TripNotes(emergencyContacts: noteContentFixture.emergencyContacts),
    );
    await pumpScreen(tester);
    await tester.tap(find.text('+886 912 345 678'));
    await tester.pumpAndSettle();
    expect(find.text('無法開啟連結'), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(launched, ['tel:+886912345678', 'tel:+886912345678']);
    expect(find.text('無法開啟連結'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('筆記電話連結保留讀屏啟用動作', (tester) async {
    when(() => repository.fetchDays('trip-1')).thenAnswer((_) async => []);
    when(() => repository.fetchNotes('trip-1')).thenAnswer(
      (_) async =>
          TripNotes(emergencyContacts: noteContentFixture.emergencyContacts),
    );
    final semantics = tester.ensureSemantics();
    try {
      await pumpScreen(tester);
      final node = tester.getSemantics(
        find.bySemanticsLabel('電話：+886 912 345 678'),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('空白筆記不留下空區塊且保留輸入順序', (tester) async {
    when(() => repository.fetchDays('trip-1')).thenAnswer((_) async => []);
    when(() => repository.fetchNotes('trip-1')).thenAnswer(
      (_) async => const TripNotes(
        flights: [TripFlight(id: 1, sortOrder: 0, version: 0, airline: '  ')],
        reservations: [
          TripReservation(
            id: 2,
            sortOrder: 9,
            version: 0,
            title: '第一筆',
            partySize: 0,
          ),
          TripReservation(
            id: 3,
            sortOrder: 1,
            version: 0,
            title: '第二筆',
            partySize: 2,
          ),
        ],
      ),
    );
    await pumpScreen(tester);
    expect(find.text('航班'), findsNothing);
    expect(find.text('0 位'), findsNothing);
    expect(find.text('2 位'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('第一筆')).dy,
      lessThan(tester.getTopLeft(find.text('第二筆')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('列印預覽可將筆記原文複製到剪貼簿', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    when(() => repository.fetchDays('trip-1')).thenAnswer((_) async => []);
    when(() => repository.fetchNotes('trip-1')).thenAnswer(
      (_) async => const TripNotes(
        pretripNotes: [
          TripPretripNote(
            id: 1,
            sortOrder: 0,
            version: 0,
            content: 'PASSPORT2026',
          ),
        ],
      ),
    );
    await pumpScreen(tester);
    await tester.longPress(find.text('PASSPORT2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, 'PASSPORT2026');
    expect(tester.takeException(), isNull);
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trip-print-pdf')),
        matching: find.byIcon(CupertinoIcons.square_arrow_down),
      ),
      findsOneWidget,
      reason: '匯出 PDF 與匯出 JSON 用同一個匯出字符',
    );
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
