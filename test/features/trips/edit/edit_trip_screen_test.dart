import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/cache/cache_read_policy.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/app/adaptive.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;
import 'package:tripline/features/trips/edit/edit_trip_controller.dart';
import 'package:tripline/features/trips/edit/edit_trip_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/destination_input.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

class _MockTripRepo extends Mock implements TripRepository {}

class _MockPoiRepo extends Mock implements PoiRepository {}

const _trip = Trip(
  id: 'okinawa',
  name: 'Okinawa',
  title: '原標題',
  description: '原描述',
  lang: 'zh-TW',
  published: true,
  dayCount: 5,
  startDate: '2026-04-23',
  endDate: '2026-04-27',
  destinations: [TripDestination(name: '那霸', lat: 26.2, lng: 127.6)],
);

const _days = [
  TripDay(
    id: 11,
    dayNum: 1,
    date: '2026-04-23',
    dayOfWeek: '四',
    title: '抵達那霸',
    version: 1,
  ),
  TripDay(
    id: 12,
    dayNum: 2,
    date: '2026-04-24',
    dayOfWeek: '五',
    title: '北部景點',
    version: 1,
  ),
];

void main() {
  setUpAll(() => registerFallbackValue(<DestinationInput>[]));

  late _MockTripRepo tripRepo;
  late _MockPoiRepo poiRepo;

  setUp(() {
    tripRepo = _MockTripRepo();
    poiRepo = _MockPoiRepo();
    when(() => tripRepo.fetchTrip(any())).thenAnswer((_) async => _trip);
    when(
      () => tripRepo.fetchDaySummaries(any()),
    ).thenAnswer((_) async => _days);
    when(
      () => tripRepo.fetchDaySummaries(
        any(),
        policy: CacheReadPolicy.networkOnly,
      ),
    ).thenAnswer((_) async => _days);
    when(
      () => tripRepo.updateTrip(
        any(),
        name: any(named: 'name'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        countries: any(named: 'countries'),
        published: any(named: 'published'),
        dataSource: any(named: 'dataSource'),
        lang: any(named: 'lang'),
        destinations: any(named: 'destinations'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget buildApp() {
    final router = GoRouter(
      initialLocation: '/edit-trip/okinawa',
      routes: [
        GoRoute(
          path: '/edit-trip/:tripId',
          builder: (_, s) =>
              EditTripScreen(tripId: s.pathParameters['tripId']!),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        poiRepositoryProvider.overrideWithValue(poiRepo),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  Widget buildSheetApp() => ProviderScope(
    overrides: [
      tripRepositoryProvider.overrideWithValue(tripRepo),
      poiRepositoryProvider.overrideWithValue(poiRepo),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => showAppScreenSheet<void>(
              context,
              builder: (_) => const EditTripScreen(tripId: 'okinawa'),
            ),
            child: const Text('開啟編輯'),
          ),
        ),
      ),
    ),
  );

  testWidgets('帶入初值（標題/發布）', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('原標題'), findsOneWidget);
    expect(find.text('那霸'), findsWidgets);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('儲存'), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(
      tester
          .widget<TpToolbarTextButton>(find.byKey(const ValueKey('edit-save')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('改標題後取消會確認捨棄未儲存變更', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('edit-title')), '京都七日行');
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
  });

  testWidgets('行程標題欄位在目的地上方', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final titleTop = tester.getTopLeft(find.text('行程標題')).dy;
    final destinationTop = tester.getTopLeft(find.text('目的地')).dy;

    expect(titleTop, lessThan(destinationTop));
  });

  testWidgets('改標題 + 儲存 → updateTrip(title)', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('edit-title')), '新標題');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit-save')));
    await tester.pumpAndSettle();

    verify(
      () => tripRepo.updateTrip(
        'okinawa',
        title: '新標題',
        description: any(named: 'description'),
        lang: any(named: 'lang'),
        published: any(named: 'published'),
        destinations: any(named: 'destinations'),
      ),
    ).called(1);
  });

  testWidgets('近滿版編輯儲存後關閉整個 screen sheet', (tester) async {
    await tester.pumpWidget(buildSheetApp());
    await tester.tap(find.text('開啟編輯'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('edit-title')), '新標題');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit-save')));
    await tester.pumpAndSettle();

    expect(find.byType(EditTripScreen), findsNothing);
    expect(find.byKey(const ValueKey('app-large-screen-sheet')), findsNothing);
    expect(find.text('開啟編輯'), findsOneWidget);
  });

  testWidgets('移除目的地 + 儲存 → updateTrip(destinations)', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.xmark).first); // 移除「那霸」
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-save')));
    await tester.pumpAndSettle();

    verify(
      () => tripRepo.updateTrip(
        'okinawa',
        title: any(named: 'title'),
        description: any(named: 'description'),
        lang: any(named: 'lang'),
        published: any(named: 'published'),
        destinations: any(named: 'destinations'),
      ),
    ).called(1);
  });

  testWidgets('平移出發日期 → shiftDays 並更新日期摘要', (tester) async {
    when(
      () => tripRepo.shiftDays(
        tripId: any(named: 'tripId'),
        startDate: any(named: 'startDate'),
      ),
    ).thenAnswer(
      (_) async => (
        newStartDate: '2026-05-01',
        newEndDate: '2026-05-05',
        daysShifted: 8,
      ),
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final localizations = MaterialLocalizations.of(
      tester.element(find.byKey(const ValueKey('edit-shift-days'))),
    );
    expect(
      find.text(
        '${localizations.formatFullDate(DateTime(2026, 4, 23))} → '
        '${localizations.formatFullDate(DateTime(2026, 4, 27))}',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('edit-shift-days')));
    await tester.pumpAndSettle();
    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    picker.onDateChanged(DateTime(2026, 5));
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    verify(
      () => tripRepo.shiftDays(tripId: 'okinawa', startDate: '2026-05-01'),
    ).called(1);
    expect(
      find.text(
        '${localizations.formatFullDate(DateTime(2026, 5, 1))} → '
        '${localizations.formatFullDate(DateTime(2026, 5, 5))}',
      ),
      findsOneWidget,
    );
    expect(find.text('出發日期已變更'), findsOneWidget);
  });

  testWidgets('新增/刪除天數 → createDay/deleteDay 並刷新摘要', (tester) async {
    var summaries = _days;
    const addedDay = TripDay(
      id: 13,
      dayNum: 3,
      date: '2026-04-25',
      dayOfWeek: '六',
      title: '返回日',
      version: 1,
    );
    when(
      () => tripRepo.fetchDaySummaries(any()),
    ).thenAnswer((_) async => summaries);
    when(
      () => tripRepo.fetchDaySummaries(
        any(),
        policy: CacheReadPolicy.networkOnly,
      ),
    ).thenAnswer((_) async => summaries);
    when(
      () => tripRepo.createDay(
        tripId: any(named: 'tripId'),
        position: any(named: 'position'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async {
      summaries = [...summaries, addedDay];
      return addedDay;
    });
    when(
      () => tripRepo.deleteDay(
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
      ),
    ).thenAnswer((_) async {
      summaries = _days;
      return 0;
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-add-day-end')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('2026-04-24（五）'), findsOneWidget);
    expect(find.text('北部景點'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('edit-add-day-end')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-add-day-end')));
    await tester.pumpAndSettle();

    verify(
      () => tripRepo.createDay(tripId: 'okinawa', position: 'end', date: null),
    ).called(1);
    expect(find.text('2026-04-25（六）'), findsOneWidget);
    expect(find.text('返回日'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('edit-delete-day-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-delete-day-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(() => tripRepo.deleteDay(tripId: 'okinawa', dayNum: 3)).called(1);
    expect(find.text('2026-04-25（六）'), findsNothing);
    expect(find.text('Day 3 已刪除'), findsOneWidget);
  });

  testWidgets('日期中間有缺口 → createDay(insert,date) 新增缺少日期', (tester) async {
    var summaries = const [
      TripDay(
        id: 11,
        dayNum: 1,
        date: '2026-04-23',
        dayOfWeek: '四',
        title: '抵達那霸',
        version: 1,
      ),
      TripDay(
        id: 12,
        dayNum: 2,
        date: '2026-04-25',
        dayOfWeek: '六',
        title: '返回日',
        version: 1,
      ),
    ];
    const restoredDay = TripDay(
      id: 13,
      dayNum: 2,
      date: '2026-04-24',
      dayOfWeek: '五',
      title: 'Day 2',
      version: 1,
    );
    when(
      () => tripRepo.fetchDaySummaries(any()),
    ).thenAnswer((_) async => summaries);
    when(
      () => tripRepo.createDay(
        tripId: any(named: 'tripId'),
        position: any(named: 'position'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async {
      summaries = const [
        TripDay(
          id: 11,
          dayNum: 1,
          date: '2026-04-23',
          dayOfWeek: '四',
          title: '抵達那霸',
          version: 1,
        ),
        restoredDay,
        TripDay(
          id: 12,
          dayNum: 3,
          date: '2026-04-25',
          dayOfWeek: '六',
          title: '返回日',
          version: 1,
        ),
      ];
      return restoredDay;
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-create-missing-day-2026-04-24')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('新增缺少日期'), findsOneWidget);
    expect(find.text('加回'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('edit-create-missing-day-2026-04-24')),
    );
    await tester.pumpAndSettle();

    verify(
      () => tripRepo.createDay(
        tripId: 'okinawa',
        position: 'insert',
        date: '2026-04-24',
      ),
    ).called(1);
    expect(find.text('已新增 2026-04-24'), findsOneWidget);
  });

  testWidgets('刪除行程日明示影響並鎖定操作，成功後才從畫面移除', (tester) async {
    const dayToDelete = TripDay(
      id: 13,
      dayNum: 3,
      date: '2026-04-25',
      dayOfWeek: '六',
      title: '返回日',
      version: 1,
    );
    var summaries = [..._days, dayToDelete];
    final deleteCompleter = Completer<int>();
    when(
      () => tripRepo.fetchDaySummaries(any()),
    ).thenAnswer((_) async => summaries);
    when(
      () => tripRepo.deleteDay(tripId: 'okinawa', dayNum: 3),
    ).thenAnswer((_) => deleteCompleter.future);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-delete-day-3')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-delete-day-3')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '確定要刪除「DAY 3・2026-04-25（六）」嗎？'
        '這會刪除當天所有景點，並重新編號後續行程日。此動作無法復原。',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('edit-day-mutation-progress')),
      findsOneWidget,
    );
    expect(find.text('2026-04-25（六）'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('edit-delete-day-3')))
          .onPressed,
      isNull,
    );

    summaries = _days;
    deleteCompleter.complete(2);
    await tester.pumpAndSettle();

    expect(find.text('2026-04-25（六）'), findsNothing);
    verify(() => tripRepo.deleteDay(tripId: 'okinawa', dayNum: 3)).called(1);
  });

  testWidgets('DELETE 例外但 stable Day 仍存在時，重試先重新確認才可再刪', (tester) async {
    const dayToDelete = TripDay(
      id: 13,
      dayNum: 3,
      date: '2026-04-25',
      dayOfWeek: '六',
      title: '返回日',
      version: 1,
    );
    const renumberedTarget = TripDay(
      id: 13,
      dayNum: 2,
      date: '2026-04-25',
      dayOfWeek: '六',
      title: '返回日',
      version: 1,
    );
    const replacementDay = TripDay(
      id: 14,
      dayNum: 3,
      date: '2026-04-26',
      dayOfWeek: '日',
      title: '加碼行程',
      version: 1,
    );
    var summaries = [..._days, dayToDelete];
    var deleteCount = 0;
    when(
      () => tripRepo.fetchDaySummaries(any()),
    ).thenAnswer((_) async => summaries);
    when(
      () => tripRepo.fetchDaySummaries(
        any(),
        policy: CacheReadPolicy.networkOnly,
      ),
    ).thenAnswer((_) async => summaries);
    when(
      () => tripRepo.deleteDay(
        tripId: 'okinawa',
        dayNum: any(named: 'dayNum'),
      ),
    ).thenAnswer((invocation) async {
      deleteCount++;
      if (deleteCount == 1) {
        summaries = [_days.first, renumberedTarget, replacementDay];
        throw Exception('response lost');
      }
      summaries = [
        _days.first,
        const TripDay(
          id: 14,
          dayNum: 2,
          date: '2026-04-26',
          dayOfWeek: '日',
          title: '加碼行程',
          version: 1,
        ),
      ];
      return 2;
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-delete-day-3')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-delete-day-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2026-04-25（六）'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-error-banner')), findsOneWidget);
    expect(
      find.text('無法確認「DAY 2・2026-04-25（六）」已刪除；重新整理後仍找到同一個行程日'),
      findsOneWidget,
    );

    tester
        .widget<TextButton>(find.widgetWithText(TextButton, '重試'))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(deleteCount, 1);
    expect(find.text('刪除行程日'), findsOneWidget);
    expect(
      find.text(
        '確定要刪除「DAY 2・2026-04-25（六）」嗎？'
        '這會刪除當天所有景點，並重新編號後續行程日。此動作無法復原。',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pumpAndSettle();

    verify(() => tripRepo.deleteDay(tripId: 'okinawa', dayNum: 3)).called(1);
    verify(() => tripRepo.deleteDay(tripId: 'okinawa', dayNum: 2)).called(1);
    expect(find.text('2026-04-25（六）'), findsNothing);
  });

  testWidgets('重試刪除前一律重新取得 server truth，再以 stable Day id 解析 dayNum', (
    tester,
  ) async {
    const dayToDelete = TripDay(
      id: 13,
      dayNum: 3,
      date: '2026-04-25',
      dayOfWeek: '六',
      title: '返回日',
      version: 1,
    );
    const replacementDay = TripDay(
      id: 14,
      dayNum: 3,
      date: '2026-04-26',
      dayOfWeek: '日',
      title: '加碼行程',
      version: 1,
    );
    const serverTarget = TripDay(
      id: 13,
      dayNum: 4,
      date: '2026-04-25',
      dayOfWeek: '六',
      title: '返回日',
      version: 2,
    );
    var summaries = [..._days, dayToDelete];
    final deletedDayNums = <int>[];
    when(
      () => tripRepo.fetchDaySummaries(any()),
    ).thenAnswer((_) async => summaries);
    when(
      () => tripRepo.fetchDaySummaries(
        any(),
        policy: CacheReadPolicy.networkOnly,
      ),
    ).thenAnswer((_) async => summaries);
    when(
      () => tripRepo.deleteDay(
        tripId: 'okinawa',
        dayNum: any(named: 'dayNum'),
      ),
    ).thenAnswer((invocation) async {
      final dayNum = invocation.namedArguments[#dayNum]! as int;
      deletedDayNums.add(dayNum);
      if (deletedDayNums.length == 1) {
        throw Exception('response lost');
      }
      summaries = [..._days, replacementDay];
      return 2;
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-delete-day-3')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-delete-day-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pumpAndSettle();

    expect(deletedDayNums, [3]);
    expect(find.byKey(const ValueKey('app-error-banner')), findsOneWidget);

    summaries = [..._days, replacementDay, serverTarget];
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, '重試'))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(deletedDayNums, [3]);
    expect(
      find.text(
        '確定要刪除「DAY 4・2026-04-25（六）」嗎？'
        '這會刪除當天所有景點，並重新編號後續行程日。此動作無法復原。',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pumpAndSettle();

    expect(deletedDayNums, [3, 4]);
  });

  testWidgets('重試時 stable Day 已不在目前狀態，只重新驗證且不送 DELETE', (tester) async {
    const dayToDelete = TripDay(
      id: 13,
      dayNum: 3,
      date: '2026-04-25',
      dayOfWeek: '六',
      title: '返回日',
      version: 1,
    );
    var summaries = [..._days, dayToDelete];
    var deleteCount = 0;
    when(
      () => tripRepo.fetchDaySummaries(any()),
    ).thenAnswer((_) async => summaries);
    when(
      () => tripRepo.fetchDaySummaries(
        any(),
        policy: CacheReadPolicy.networkOnly,
      ),
    ).thenAnswer((_) async => summaries);
    when(
      () => tripRepo.createDay(
        tripId: any(named: 'tripId'),
        position: any(named: 'position'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => _days.last);
    when(() => tripRepo.deleteDay(tripId: 'okinawa', dayNum: 3)).thenAnswer((
      _,
    ) async {
      deleteCount++;
      throw Exception('response lost');
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-delete-day-3')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-delete-day-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-error-banner')), findsOneWidget);

    summaries = _days;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditTripScreen)),
    );
    await container
        .read(editTripControllerProvider('okinawa').notifier)
        .addDay('end');
    await tester.pumpAndSettle();

    tester
        .widget<TextButton>(find.widgetWithText(TextButton, '重試'))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(deleteCount, 1);
    expect(find.text('此行程日已不存在'), findsOneWidget);
  });

  testWidgets('DELETE 例外但 stable Day 已不存在時，視為已 commit 且不重送', (tester) async {
    const dayToDelete = TripDay(
      id: 13,
      dayNum: 3,
      date: '2026-04-25',
      dayOfWeek: '六',
      title: '返回日',
      version: 1,
    );
    var fetchCount = 0;
    when(() => tripRepo.fetchDaySummaries(any())).thenAnswer((_) async {
      fetchCount++;
      return fetchCount == 1 ? [..._days, dayToDelete] : _days;
    });
    when(
      () => tripRepo.fetchDaySummaries(
        any(),
        policy: CacheReadPolicy.networkOnly,
      ),
    ).thenAnswer((_) async {
      fetchCount++;
      return fetchCount == 1 ? [..._days, dayToDelete] : _days;
    });
    when(
      () => tripRepo.deleteDay(tripId: 'okinawa', dayNum: 3),
    ).thenThrow(Exception('response lost'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-delete-day-3')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-delete-day-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pumpAndSettle();

    verify(() => tripRepo.deleteDay(tripId: 'okinawa', dayNum: 3)).called(1);
    expect(fetchCount, 2);
    expect(find.text('2026-04-25（六）'), findsNothing);
    expect(find.text('Day 3 已刪除'), findsOneWidget);
  });

  testWidgets('DELETE 例外且驗證刷新失敗時，所有重試都只 fetch stable Day', (tester) async {
    const dayToDelete = TripDay(
      id: 13,
      dayNum: 3,
      date: '2026-04-25',
      dayOfWeek: '六',
      title: '返回日',
      version: 1,
    );
    var fetchCount = 0;
    when(() => tripRepo.fetchDaySummaries(any())).thenAnswer((_) async {
      fetchCount++;
      if (fetchCount == 1) return [..._days, dayToDelete];
      if (fetchCount <= 3) throw Exception('verification offline');
      return _days;
    });
    when(
      () => tripRepo.fetchDaySummaries(
        any(),
        policy: CacheReadPolicy.networkOnly,
      ),
    ).thenAnswer((_) async {
      fetchCount++;
      if (fetchCount == 1) return [..._days, dayToDelete];
      if (fetchCount <= 3) throw Exception('verification offline');
      return _days;
    });
    when(
      () => tripRepo.deleteDay(tripId: 'okinawa', dayNum: 3),
    ).thenThrow(Exception('response lost'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-delete-day-3')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-delete-day-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('無法確認「DAY 3・2026-04-25（六）」是否已刪除，請重試確認'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fetchCount, 3);

    tester
        .widget<TextButton>(find.widgetWithText(TextButton, '重試'))
        .onPressed!();
    await tester.pumpAndSettle();

    verify(() => tripRepo.deleteDay(tripId: 'okinawa', dayNum: 3)).called(1);
    expect(fetchCount, 4);
    expect(find.text('2026-04-25（六）'), findsNothing);
  });

  testWidgets('刪除已成功但摘要刷新失敗時，重試只刷新而不再送 DELETE', (tester) async {
    const dayToDelete = TripDay(
      id: 13,
      dayNum: 3,
      date: '2026-04-25',
      dayOfWeek: '六',
      title: '返回日',
      version: 1,
    );
    var fetchCount = 0;
    when(() => tripRepo.fetchDaySummaries(any())).thenAnswer((_) async {
      fetchCount++;
      if (fetchCount == 1) return [..._days, dayToDelete];
      if (fetchCount == 2) throw Exception('refresh offline');
      return _days;
    });
    when(
      () => tripRepo.fetchDaySummaries(
        any(),
        policy: CacheReadPolicy.networkOnly,
      ),
    ).thenAnswer((_) async {
      fetchCount++;
      if (fetchCount == 1) return [..._days, dayToDelete];
      if (fetchCount == 2) throw Exception('refresh offline');
      return _days;
    });
    when(
      () => tripRepo.deleteDay(tripId: 'okinawa', dayNum: 3),
    ).thenAnswer((_) async => 2);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-delete-day-3')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-delete-day-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('「DAY 3・2026-04-25（六）」已刪除，但無法重新整理行程日'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('edit-delete-day-3')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    verify(() => tripRepo.deleteDay(tripId: 'okinawa', dayNum: 3)).called(1);
    expect(fetchCount, 3);
    expect(find.text('2026-04-25（六）'), findsNothing);
  });
}
