import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
