import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/account_repository.dart';
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

class MockTripRepository extends Mock
    implements TripRepository, AccountRepository {}

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
          builder: (context, state) => const Scaffold(body: Text('login')),
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
        retry: (retryCount, error) => null,
        overrides: [
          tripRepositoryProvider.overrideWithValue(repository),
          accountRepositoryProvider.overrideWithValue(repository),
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

  testWidgets('公開分享在 compact Accessibility Size 可捲動完成主要操作', (tester) async {
    await pumpScreen(tester, size: const Size(320, 568), textScale: 3.2);

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('public-share-clone')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('public-share-clone')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('public-share-clone'))).height,
      greaterThanOrEqualTo(44),
    );
  });

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

  testWidgets('分享連結失效時顯示 notfound 狀態', (tester) async {
    when(
      () => repository.fetchPublicTripShare(any()),
    ).thenThrow(Exception('404'));

    await pumpScreen(tester);

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
