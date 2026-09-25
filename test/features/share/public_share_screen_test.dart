import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/share/public_share_screen.dart';
import 'package:tripline/features/trip_detail/trip_pdf_service.dart';
import 'package:tripline/features/trip_detail/trip_print_data.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/share.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

import '../../fixtures/note_content_fixture.dart';

class MockTripRepository extends Mock implements TripRepository {}

class FakeTripPrintActions implements TripPrintActions {
  final printed = <TripPrintData>[];
  final shared = <TripPrintData>[];

  @override
  Future<void> print(TripPrintData data) async {
    printed.add(data);
  }

  @override
  Future<void> sharePdf(TripPrintData data) async {
    shared.add(data);
  }
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(this.user);

  final UserInfo? user;

  @override
  Future<UserInfo?> build() async => user;
}

void main() {
  late MockTripRepository repository;
  late FakeTripPrintActions printActions;

  const sharedTrip = PublicTripShare(
    name: 'okinawa-trip-2026',
    title: '沖繩家族旅行',
    sharedBy: 'Ray',
    destinations: ['那霸'],
    days: [
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
    ],
    notes: TripNotes(
      flights: [TripFlight(id: 1, sortOrder: 0, version: 1, flightNo: 'BR112')],
    ),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    UserInfo? user,
    String token = 's1',
    Locale locale = const Locale('zh', 'TW'),
    Size size = const Size(390, 844),
    double textScale = 1,
    bool settle = true,
    bool useDefaultRetry = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/s/$token',
      routes: [
        GoRoute(
          path: '/s/:token',
          builder: (context, state) =>
              PublicShareScreen(token: state.pathParameters['token']!),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('login'),
                Text(state.uri.queryParameters['redirect_after'] ?? ''),
              ],
            ),
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

    await tester.pumpWidget(
      ProviderScope(
        retry: useDefaultRetry ? null : (retryCount, error) => null,
        overrides: [
          tripRepositoryProvider.overrideWithValue(repository),
          tripPrintActionsProvider.overrideWithValue(printActions),
          authStateProvider.overrideWith(() => FakeAuthNotifier(user)),
        ],
        child: MaterialApp.router(
          locale: locale,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(size: size, textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  setUp(() {
    repository = MockTripRepository();
    printActions = FakeTripPrintActions();
    when(
      () => repository.fetchPublicTripShare(any()),
    ).thenAnswer((_) async => sharedTrip);
    when(
      () => repository.clonePublicTripShare(any()),
    ).thenAnswer((_) async => 'cln-trip-1');
  });

  testWidgets('公開分享保留五區語意內容且不讀私人筆記', (tester) async {
    when(() => repository.fetchPublicTripShare('s1')).thenAnswer(
      (_) async =>
          const PublicTripShare(name: '公開旅行', notes: noteContentFixture),
    );
    final semantics = tester.ensureSemantics();
    try {
      await pumpScreen(tester, size: const Size(800, 1800));
      expect(find.text('商務艙'), findsOneWidget);
      expect(find.bySemanticsLabel('電子郵件：family@example.com'), findsOneWidget);
      final text = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('public-share-page')),
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
      when(() => repository.fetchPublicTripShare('s1')).thenAnswer(
        (_) async =>
            const PublicTripShare(name: '公開旅行', notes: emptyNoteContentFixture),
      );
      await pumpScreen(tester, size: const Size(800, 1800));
      expect(find.text('行程筆記'), findsNothing);
      verifyNever(() => repository.fetchNotes(any()));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('公開授權視圖及列印輸出不回補私有區塊', (tester) async {
    when(() => repository.fetchPublicTripShare('s1')).thenAnswer(
      (_) async =>
          const PublicTripShare(name: '公開旅行', notes: publicNoteFixture),
    );
    when(
      () => repository.fetchNotes(any()),
    ).thenAnswer((_) async => privateNoteFixture);
    await pumpScreen(tester);
    expect(find.text('PUBLIC-BR112'), findsOneWidget);
    expect(find.text('公開提醒'), findsOneWidget);
    expect(find.text('PRIVATE-SECRET-385'), findsNothing);
    expect(find.text('住宿'), findsNothing);
    expect(find.text('緊急聯絡'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('public-share-print')));
    await tester.pumpAndSettle();
    expect(printActions.printed.single.notes.emergencyContacts, isEmpty);
    expect(
      printActions.printed.single.notes.flights.single.cabinClass,
      isEmpty,
    );
    verifyNever(() => repository.fetchNotes(any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('公開分享可開啟電話並將筆記原文複製到剪貼簿', (tester) async {
    final launched = <String>[];
    String? copied;
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
      }
      return true;
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    when(() => repository.fetchPublicTripShare('s1')).thenAnswer(
      (_) async => PublicTripShare(
        name: '公開旅行',
        notes: TripNotes(
          pretripNotes: const [
            TripPretripNote(
              id: 1,
              sortOrder: 0,
              version: 0,
              content: 'PASSPORT2026',
            ),
          ],
          emergencyContacts: noteContentFixture.emergencyContacts,
        ),
      ),
    );
    await pumpScreen(
      tester,
      locale: const Locale('en', 'US'),
      size: const Size(800, 1200),
    );
    await tester.tap(find.text('+886 912 345 678'));
    await tester.pumpAndSettle();
    expect(launched, ['tel:+886912345678']);
    await tester.longPress(find.text('PASSPORT2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, 'PASSPORT2026');
    expect(tester.takeException(), isNull);
  });

  testWidgets('顯示公開分享 hero、日程與允許公開的 notes', (tester) async {
    await pumpScreen(tester);

    expect(find.text('由 Ray 分享給你'), findsOneWidget);
    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.text('2026/10/1 · 那霸 · 1 天'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.textContaining('9:00'), findsOneWidget);
    expect(find.textContaining('10:30'), findsOneWidget);
    expect(find.text('首里城公園'), findsOneWidget);
    expect(find.text('高鐵 · 18 分 · 0.9km'), findsOneWidget);
    expect(find.text('不需計算路程'), findsOneWidget);
    expect(find.text('航班'), findsOneWidget);
    expect(find.text('BR112'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-avatar-button')), findsNothing);
    expect(
      tester
          .widget<ListView>(find.byKey(const ValueKey('public-share-page')))
          .keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
  });

  testWidgets('公開分享日期依目前 locale 顯示', (tester) async {
    await pumpScreen(tester, locale: const Locale('en', 'US'));

    expect(find.text('10/1/2026 · 那霸 · 1 天'), findsOneWidget);
    expect(find.textContaining('10/1/2026'), findsNWidgets(2));
    expect(find.text('9:00 AM–10:30 AM'), findsOneWidget);
  });

  for (final user in [
    null,
    const UserInfo(id: 'user-1', email: 'ray@example.com'),
  ]) {
    testWidgets('最大測試字級三動作皆可操作：${user == null ? '未登入' : '已登入'}', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        user: user,
        size: const Size(320, 568),
        textScale: 3.2,
      );
      expect(tester.takeException(), isNull);

      for (final action in ['print', 'pdf', 'clone']) {
        final button = find.byKey(ValueKey('public-share-$action'));
        await tester.scrollUntilVisible(
          button,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(printActions.printed, hasLength(1));
      expect(printActions.shared, hasLength(1));
      if (user == null) {
        expect(find.text('login'), findsOneWidget);
        expect(find.text('/s/s1'), findsOneWidget);
        verifyNever(() => repository.clonePublicTripShare(any()));
      } else {
        expect(find.text('trip cln-trip-1'), findsOneWidget);
        verify(() => repository.clonePublicTripShare('s1')).called(1);
      }
    });
  }

  testWidgets('未登入點複製會前往 login', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('public-share-clone')));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    verifyNever(() => repository.clonePublicTripShare(any()));
  });

  testWidgets('已登入點複製會 clone 並導向新行程', (tester) async {
    const user = UserInfo(id: 'user-1', email: 'ray@example.com');
    await pumpScreen(tester, user: user);

    await tester.tap(find.byKey(const ValueKey('public-share-clone')));
    await tester.pumpAndSettle();

    verify(() => repository.clonePublicTripShare('s1')).called(1);
    expect(find.text('trip cln-trip-1'), findsOneWidget);
  });

  testWidgets('已登入連點複製只送出一次', (tester) async {
    const user = UserInfo(id: 'user-1', email: 'ray@example.com');
    final pending = Completer<String>();
    when(
      () => repository.clonePublicTripShare(any()),
    ).thenAnswer((_) => pending.future);
    await pumpScreen(tester, user: user);

    final clone = find.byKey(const ValueKey('public-share-clone'));
    await tester.tap(clone);
    await tester.pump();
    await tester.tap(clone, warnIfMissed: false);
    await tester.pump();

    verify(() => repository.clonePublicTripShare('s1')).called(1);
    pending.complete('cln-trip-1');
    await tester.pumpAndSettle();
  });

  testWidgets('複製失敗保留公開內容並向 screen reader 宣告', (tester) async {
    const user = UserInfo(id: 'user-1', email: 'ray@example.com');
    when(
      () => repository.clonePublicTripShare(any()),
    ).thenThrow(Exception('clone failed'));
    await pumpScreen(tester, user: user);

    await tester.tap(find.byKey(const ValueKey('public-share-clone')));
    await tester.pumpAndSettle();

    expect(find.text('沖繩家族旅行'), findsOneWidget);
    final error = find.byKey(const ValueKey('public-share-clone-error'));
    expect(error, findsOneWidget);
    expect(
      tester
          .getSemantics(error)
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
  });

  testWidgets('點列印會用公開分享資料建立列印文件', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('public-share-print')));
    await tester.pumpAndSettle();

    expect(printActions.printed, hasLength(1));
    expect(printActions.printed.single.displayTitle, '沖繩家族旅行');
    expect(
      printActions.printed.single.days.single.timeline.first.title,
      '首里城公園',
    );
  });

  testWidgets('點 PDF 會用公開分享資料分享 PDF', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('public-share-pdf')));
    await tester.pumpAndSettle();

    expect(printActions.shared, hasLength(1));
    expect(printActions.shared.single.destinationsLabel, '那霸');
  });

  testWidgets('公開分享逾時可原地重試', (tester) async {
    var requests = 0;
    when(() => repository.fetchPublicTripShare('s1')).thenAnswer((_) async {
      if (requests++ == 0) {
        throw DioException(
          requestOptions: RequestOptions(path: '/share/s1'),
          type: DioExceptionType.receiveTimeout,
        );
      }
      return sharedTrip;
    });

    await pumpScreen(tester);

    expect(find.text('暫時無法載入行程'), findsOneWidget);
    expect(find.text('連結已失效'), findsNothing);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.text('暫時無法載入行程'), findsNothing);
    verify(() => repository.fetchPublicTripShare('s1')).called(2);
  });

  testWidgets('離線保留暫時失敗與可操作的重試', (tester) async {
    when(() => repository.fetchPublicTripShare(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/share/s1'),
        type: DioExceptionType.connectionError,
      ),
    );
    await pumpScreen(tester);
    expect(find.text('暫時無法載入行程'), findsOneWidget);
    expect(find.text('連結已失效'), findsNothing);
    expect(find.text('重試').hitTestable(), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('public-share-load-error')))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
  });

  testWidgets('錯誤文字包含 404 不會冒充失效連結', (tester) async {
    when(
      () => repository.fetchPublicTripShare(any()),
    ).thenThrow(Exception('404'));
    await pumpScreen(tester);
    expect(find.text('暫時無法載入行程'), findsOneWidget);
    expect(find.text('連結已失效'), findsNothing);
  });

  testWidgets('正式預設 Scope 立即顯示錯誤並等待使用者重試', (tester) async {
    when(() => repository.fetchPublicTripShare(any())).thenThrow(
      const ApiError(status: 503, code: 'HTTP_503', message: 'unavailable'),
    );
    await pumpScreen(tester, useDefaultRetry: true, settle: false);
    await tester.pump();

    expect(find.text('暫時無法載入行程'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('暫時無法載入行程'), findsOneWidget);
    verify(() => repository.fetchPublicTripShare('s1')).called(1);
  });

  testWidgets('原地重試處理中不重送且保留同一分享連結', (tester) async {
    final pending = Completer<PublicTripShare>();
    var requests = 0;
    when(() => repository.fetchPublicTripShare('s1')).thenAnswer((_) {
      if (requests++ == 0) return Future.error(Exception('offline'));
      return pending.future;
    });
    await pumpScreen(tester);
    final retryPosition = tester.getCenter(find.text('重試'));

    await tester.tapAt(retryPosition);
    await tester.pump();
    await tester.tapAt(retryPosition);
    await tester.pump();

    verify(() => repository.fetchPublicTripShare('s1')).called(2);
    expect(find.byKey(const ValueKey('public-share-loading')), findsOneWidget);
    pending.complete(sharedTrip);
    await tester.pumpAndSettle();
    expect(find.text('沖繩家族旅行'), findsOneWidget);
  });

  testWidgets('大字級失效說明可捲動到重試並恢復內容', (tester) async {
    when(() => repository.fetchPublicTripShare(any())).thenThrow(
      const ApiError(status: 404, code: 'NOT_FOUND', message: 'NOT_FOUND'),
    );
    await pumpScreen(tester, size: const Size(320, 568), textScale: 3.2);

    expect(tester.takeException(), isNull);
    when(
      () => repository.fetchPublicTripShare(any()),
    ).thenAnswer((_) async => sharedTrip);
    await tester.ensureVisible(find.text('重試'));
    expect(find.text('重試').hitTestable(), findsOneWidget);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.text('沖繩家族旅行'), findsOneWidget);
  });

  testWidgets('分享連結失效時顯示 notfound 狀態', (tester) async {
    when(() => repository.fetchPublicTripShare(any())).thenThrow(
      const ApiError(status: 404, code: 'NOT_FOUND', message: 'NOT_FOUND'),
    );

    await pumpScreen(tester, useDefaultRetry: true);
    await tester.pump(const Duration(seconds: 1));
    verify(() => repository.fetchPublicTripShare('s1')).called(1);

    expect(find.byKey(const ValueKey('public-share-notfound')), findsOneWidget);
    expect(find.text('連結已失效'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('public-share-notfound')))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
  });
}
