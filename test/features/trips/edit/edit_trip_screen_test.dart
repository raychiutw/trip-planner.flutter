import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/cache_read_policy.dart';
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

  testWidgets('帶入初值，標題列只有「完成」，沒有「取消」與「儲存」', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('原標題'), findsOneWidget);
    expect(find.text('那霸'), findsWidgets);
    expect(find.text('取消'), findsNothing);
    expect(find.text('儲存'), findsNothing);
    expect(find.byKey(const ValueKey('tp-app-bar-cancel')), findsNothing);
    expect(find.byKey(const ValueKey('edit-done')), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(find.textContaining('需按「儲存」'), findsNothing);
    expect(find.textContaining('取消不會還原'), findsNothing);
  });

  testWidgets('未發布的行程沒有發布開關（app 不提供公開上線，分享走分享連結）', (tester) async {
    when(() => tripRepo.fetchTrip(any())).thenAnswer(
      (_) async => const Trip(
        id: 'okinawa',
        name: 'Okinawa',
        title: '原標題',
        description: '原描述',
        lang: 'zh-TW',
        dayCount: 5,
        startDate: '2026-04-23',
        endDate: '2026-04-27',
        destinations: [TripDestination(name: '那霸', lat: 26.2, lng: 127.6)],
      ),
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // 先捲到底，避免開關在畫面外沒被建出來而假綠。
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-lang')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-published')), findsNothing);
    expect(find.textContaining('知道網址'), findsNothing);
  });

  testWidgets('已發布的行程保留開關以便關閉，並說明任何知道網址的人都看得到', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-published')),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byKey(const ValueKey('edit-published')), findsOneWidget);
    expect(find.textContaining('知道網址'), findsOneWidget);
  });

  testWidgets('載入失敗顯示可重試錯誤頁，不渲染表單與完成鈕，重試成功後出現表單', (tester) async {
    var calls = 0;
    when(() => tripRepo.fetchTrip(any())).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('boom-internal');
      return _trip;
    });
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('edit-trip-load-error')), findsOneWidget);
    expect(find.text('無法載入行程'), findsOneWidget);
    expect(find.textContaining('boom-internal'), findsNothing);
    expect(find.byKey(const ValueKey('edit-title')), findsNothing);
    expect(find.byKey(const ValueKey('edit-done')), findsNothing);
    final live = tester.getSemantics(
      find.byKey(const ValueKey('edit-trip-load-error')),
    );
    expect(live.flagsCollection.isLiveRegion, isTrue);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('edit-trip-load-error')), findsNothing);
    expect(find.byKey(const ValueKey('edit-title')), findsOneWidget);
    expect(find.text('原標題'), findsOneWidget);
  });

  Future<void> blur(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(buildSheetApp());
    await tester.tap(find.text('開啟編輯'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder f, [double d = 150]) async {
    await tester.scrollUntilVisible(
      f,
      d,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
  }

  void verifyNoUpdate() => verifyNever(
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
  );

  testWidgets('行程標題欄位在目的地上方', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final titleTop = tester.getTopLeft(find.text('行程標題')).dy;
    final destinationTop = tester.getTopLeft(find.text('目的地')).dy;

    expect(titleTop, lessThan(destinationTop));
  });

  testWidgets('標題打字中不送出，失焦才送出 updateTrip(title)', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('edit-title')), '新標題');
    await tester.pump();
    verifyNoUpdate();

    await blur(tester);
    verify(() => tripRepo.updateTrip('okinawa', title: '新標題')).called(1);
  });

  testWidgets('描述打字中不送出，失焦才送出 updateTrip(description)', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    final desc = find.byKey(const ValueKey('edit-desc'));
    await scrollTo(tester, desc, 200);

    await tester.enterText(desc, '新描述');
    await tester.pump();
    verifyNoUpdate();

    await blur(tester);
    verify(() => tripRepo.updateTrip('okinawa', description: '新描述')).called(1);
  });

  testWidgets('標題輸入後直接按「完成」會送出並關閉整個 screen sheet', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byKey(const ValueKey('edit-title')), '新標題');
    await tester.pump();
    verifyNoUpdate();
    await tester.tap(find.byKey(const ValueKey('edit-done')));
    await tester.pumpAndSettle();

    verify(() => tripRepo.updateTrip('okinawa', title: '新標題')).called(1);
    expect(find.byType(EditTripScreen), findsNothing);
    expect(find.byKey(const ValueKey('app-large-screen-sheet')), findsNothing);
    expect(find.text('開啟編輯'), findsOneWidget);
  });

  testWidgets('沒有變更時按「完成」直接關閉，不送出也不詢問', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('edit-done')));
    await tester.pumpAndSettle();

    verifyNoUpdate();
    expect(find.byType(EditTripScreen), findsNothing);
    expect(find.text('捨棄未儲存的變更？'), findsNothing);
  });

  testWidgets('改了標題但還沒送出時不會跳出「捨棄未儲存的變更」', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byKey(const ValueKey('edit-title')), '京都七日行');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit-done')));
    await tester.pumpAndSettle();

    expect(find.text('捨棄未儲存的變更？'), findsNothing);
  });

  testWidgets('語言選擇後立即送出 updateTrip(lang)，不必失焦或按完成', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('edit-lang')));
    await tester.tap(find.byKey(const ValueKey('edit-lang')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    verify(() => tripRepo.updateTrip('okinawa', lang: 'en')).called(1);
  });

  testWidgets('發布狀態切換後立即送出 updateTrip(published)', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('edit-published')), 100);
    await tester.tap(find.byKey(const ValueKey('edit-published')));
    await tester.pump();

    verify(() => tripRepo.updateTrip('okinawa', published: 0)).called(1);
  });

  testWidgets('移除目的地後立即送出 updateTrip(destinations)', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.xmark).first); // 移除「那霸」
    await tester.pumpAndSettle();

    verify(() => tripRepo.updateTrip('okinawa', destinations: [])).called(1);
  });

  testWidgets('送出中又輸入新標題：成功後保留較新輸入，之後失焦再送一次', (tester) async {
    final pending = Completer<void>();
    when(
      () => tripRepo.updateTrip('okinawa', title: '送出的標題'),
    ).thenAnswer((_) => pending.future);

    await openSheet(tester);
    await tester.enterText(find.byKey(const ValueKey('edit-title')), '送出的標題');
    await blur(tester);
    verify(() => tripRepo.updateTrip('okinawa', title: '送出的標題')).called(1);

    await tester.enterText(find.byKey(const ValueKey('edit-title')), '後來的標題');
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();

    expect(find.byType(EditTripScreen), findsOneWidget);
    expect(find.text('後來的標題'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit-done')));
    await tester.pumpAndSettle();
    verify(() => tripRepo.updateTrip('okinawa', title: '後來的標題')).called(1);
    expect(find.byType(EditTripScreen), findsNothing);
  });

  testWidgets('送出進度可見且不重複送出', (tester) async {
    final pending = Completer<void>();
    when(
      () => tripRepo.updateTrip('okinawa', title: '保留這個標題'),
    ).thenAnswer((_) => pending.future);
    await openSheet(tester);
    await tester.enterText(find.byKey(const ValueKey('edit-title')), '保留這個標題');
    await blur(tester);

    expect(find.text('儲存中…'), findsOneWidget);
    await blur(tester);
    verify(() => tripRepo.updateTrip('okinawa', title: '保留這個標題')).called(1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('儲存中…'), findsNothing);
  });

  testWidgets('全螢幕編輯開啟鍵盤時儲存進度仍可見', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final pending = Completer<void>();
    when(
      () => tripRepo.updateTrip('okinawa', title: '鍵盤中的草稿'),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('edit-title')), '鍵盤中的草稿');
    await blur(tester);

    expect(tester.getBottomRight(find.text('儲存中…')).dy, lessThanOrEqualTo(544));
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pump();
  });

  group('失敗與驗證路徑', () {
    testWidgets('送出失敗保留輸入，在欄位旁就地顯示錯誤與重試，重試成功後錯誤消失', (tester) async {
      var requests = 0;
      when(() => tripRepo.updateTrip('okinawa', title: '保留這個標題')).thenAnswer((
        _,
      ) async {
        requests++;
        if (requests == 1) throw Exception('暫時無法連線');
      });
      await openSheet(tester);
      await tester.enterText(
        find.byKey(const ValueKey('edit-title')),
        '保留這個標題',
      );
      await blur(tester);
      await tester.pumpAndSettle();

      expect(find.text('保留這個標題'), findsOneWidget);
      expect(find.text('儲存失敗,請稍後再試'), findsOneWidget);
      // 錯誤就在標題欄位下方，而不是頁面最底。
      expect(
        tester.getTopLeft(find.text('儲存失敗,請稍後再試')).dy,
        lessThan(tester.getTopLeft(find.text('目的地')).dy),
      );
      // 只有失敗的欄位有重試；描述沒有被送過，不顯示。
      expect(find.byKey(const ValueKey('edit-retry-title')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('edit-retry-description')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('edit-retry-title')));
      await tester.pumpAndSettle();

      expect(requests, 2);
      expect(find.text('儲存失敗,請稍後再試'), findsNothing);
      expect(find.byKey(const ValueKey('edit-retry-title')), findsNothing);
      expect(find.text('保留這個標題'), findsOneWidget);
    });

    testWidgets('切換發布失敗：開關保留使用者的選擇並在旁邊顯示重試', (tester) async {
      when(
        () => tripRepo.updateTrip('okinawa', published: 0),
      ).thenThrow(Exception('boom'));
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const ValueKey('edit-published')), 100);
      await tester.tap(find.byKey(const ValueKey('edit-published')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('edit-published')),
            )
            .value,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('edit-retry-published')),
        findsOneWidget,
      );
    });

    testWidgets('有未送出成功的變更時按「完成」攔截，說出是哪個欄位；放棄後關閉', (tester) async {
      when(
        () => tripRepo.updateTrip('okinawa', title: '送不出去'),
      ).thenThrow(Exception('boom'));
      await openSheet(tester);
      await tester.enterText(find.byKey(const ValueKey('edit-title')), '送不出去');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('edit-done')));
      await tester.pumpAndSettle();

      expect(find.text('有變更尚未送出'), findsOneWidget);
      expect(find.textContaining('標題'), findsWidgets);
      expect(find.byType(EditTripScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(CupertinoDialogAction, '放棄變更'));
      await tester.pumpAndSettle();
      expect(find.byType(EditTripScreen), findsNothing);
    });

    testWidgets('攔截時選「重試」會再送一次，成功就關閉', (tester) async {
      var requests = 0;
      when(() => tripRepo.updateTrip('okinawa', title: '第二次才成功')).thenAnswer((
        _,
      ) async {
        requests++;
        if (requests == 1) throw Exception('boom');
      });
      await openSheet(tester);
      await tester.enterText(
        find.byKey(const ValueKey('edit-title')),
        '第二次才成功',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('edit-done')));
      await tester.pumpAndSettle();
      expect(find.text('有變更尚未送出'), findsOneWidget);

      await tester.tap(find.widgetWithText(CupertinoDialogAction, '重試'));
      await tester.pumpAndSettle();

      expect(requests, 2);
      expect(find.byType(EditTripScreen), findsNothing);
    });

    testWidgets('標題清空不送出，就地提示；補回文字後提示消失', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('edit-title')), '');
      await blur(tester);

      verifyNoUpdate();
      expect(find.text('標題不能是空白'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('edit-title')), '有字了');
      await tester.pump();
      expect(find.text('標題不能是空白'), findsNothing);
    });

    testWidgets('標題只有空白也視為空白', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('edit-title')), '   ');
      await blur(tester);

      verifyNoUpdate();
      expect(find.text('標題不能是空白'), findsOneWidget);
    });

    testWidgets('標題清空時按「完成」：不送標題、直接關閉', (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byKey(const ValueKey('edit-title')), '');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('edit-done')));
      await tester.pumpAndSettle();

      verifyNoUpdate();
      expect(find.byType(EditTripScreen), findsNothing);
    });

    testWidgets('標題清空時按「完成」遇到其他欄位送出失敗：欄位還原成上次成功的標題', (tester) async {
      when(
        () => tripRepo.updateTrip('okinawa', description: '新描述'),
      ).thenThrow(Exception('boom'));
      await openSheet(tester);
      await tester.enterText(find.byKey(const ValueKey('edit-title')), '');
      final desc = find.byKey(const ValueKey('edit-desc'));
      await scrollTo(tester, desc, 200);
      await tester.enterText(desc, '新描述');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('edit-done')));
      await tester.pumpAndSettle();

      // 標題沒有被送出（baseline 仍是原標題），攔截框只提描述。
      verifyNever(
        () => tripRepo.updateTrip(
          any(),
          title: any(named: 'title', that: isNotNull),
          description: any(named: 'description'),
        ),
      );
      expect(find.text('有變更尚未送出'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EditTripScreen)),
      );
      expect(
        container.read(editTripControllerProvider('okinawa')).title,
        '原標題',
      );
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '放棄變更'));
      await tester.pumpAndSettle();
    });
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
    // 日期選擇器自己也有「完成」,取最上層那個。
    await tester.tap(find.text('完成').last);
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

  testWidgets('說明 Day 操作立即生效，且畫面沒有可放棄的草稿', (tester) async {
    var summaries = _days;
    const addedDay = TripDay(
      id: 13,
      dayNum: 3,
      date: '2026-04-25',
      dayOfWeek: '六',
      version: 1,
    );
    when(
      () => tripRepo.fetchDaySummaries(any()),
    ).thenAnswer((_) async => summaries);
    when(
      () => tripRepo.createDay(tripId: 'okinawa', position: 'end'),
    ).thenAnswer((_) async {
      summaries = [...summaries, addedDay];
      return addedDay;
    });

    await openSheet(tester);
    final immediateNotice = find.text('日期平移與天數新增、刪除會立即生效；刪除天數無法復原。');
    await scrollTo(tester, immediateNotice);
    expect(immediateNotice, findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('edit-add-day-end')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-add-day-end')));
    await tester.pumpAndSettle();
    verify(
      () => tripRepo.createDay(tripId: 'okinawa', position: 'end'),
    ).called(1);

    await tester.tap(find.byKey(const ValueKey('edit-done')));
    await tester.pumpAndSettle();
    expect(find.byType(EditTripScreen), findsNothing);
    expect(find.text('捨棄未儲存的變更？'), findsNothing);
    verifyNoUpdate();
    await tester.tap(find.text('開啟編輯'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('2026-04-25（六）'));
    expect(find.text('2026-04-25（六）'), findsOneWidget);
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
        '確定要刪除「Day 3 · 2026-04-25（六）」嗎？'
        '這會刪除當天所有停留點，並重新編號後續行程日。此動作無法復原。',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<CupertinoDialogAction>(
            find.widgetWithText(CupertinoDialogAction, '刪除'),
          )
          .isDestructiveAction,
      isTrue,
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
      find.text('無法確認「Day 2 · 2026-04-25（六）」已刪除；重新整理後仍找到同一個行程日'),
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
        '確定要刪除「Day 2 · 2026-04-25（六）」嗎？'
        '這會刪除當天所有停留點，並重新編號後續行程日。此動作無法復原。',
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
        '確定要刪除「Day 4 · 2026-04-25（六）」嗎？'
        '這會刪除當天所有停留點，並重新編號後續行程日。此動作無法復原。',
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

    expect(find.text('無法確認「Day 3 · 2026-04-25（六）」是否已刪除，請重試確認'), findsOneWidget);

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

    expect(find.text('「Day 3 · 2026-04-25（六）」已刪除，但無法重新整理行程日'), findsOneWidget);
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
