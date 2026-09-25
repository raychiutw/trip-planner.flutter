import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSearchTextField;
import 'package:tripline/api/api_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;
import 'package:tripline/features/trips/create/create_trip_screen.dart';
import 'package:tripline/models/destination_input.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

class _MockTripRepo extends Mock implements TripRepository {}

class _MockPoiRepo extends Mock implements PoiRepository {}

class _MockAuthRepo extends Mock implements AuthRepository {}

const _tokyo = PoiSearchResult(
  placeId: 'p1',
  name: '東京',
  lat: 35.68,
  lng: 139.76,
  country: 'JP',
);

void main() {
  setUpAll(() => registerFallbackValue(<DestinationInput>[]));

  late _MockTripRepo tripRepo;
  late _MockPoiRepo poiRepo;
  late _MockAuthRepo authRepo;

  setUp(() {
    tripRepo = _MockTripRepo();
    poiRepo = _MockPoiRepo();
    authRepo = _MockAuthRepo();
    when(
      () => poiRepo.searchPois(
        q: any(named: 'q'),
        region: any(named: 'region'),
      ),
    ).thenAnswer((_) async => const [_tokyo]);
    when(() => authRepo.fetchAiAuthorization()).thenAnswer((_) async => false);
    when(() => authRepo.authorizeAi()).thenAnswer((_) async => true);
  });

  Widget buildApp({Future<bool> Function()? beforeExit}) {
    final router = GoRouter(
      initialLocation: '/new-trip',
      routes: [
        GoRoute(
          path: '/new-trip',
          builder: (_, _) => const CreateTripScreen(),
          onExit: (_, _) async =>
              beforeExit == null ? true : await beforeExit(),
        ),
        GoRoute(
          path: '/trips/:id',
          builder: (_, s) =>
              Scaffold(body: Text('TRIP ${s.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        poiRepositoryProvider.overrideWithValue(poiRepo),
        authRepositoryProvider.overrideWithValue(authRepo),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  Future<void> completeBasics(WidgetTester tester) async {
    await tester.enterText(find.byKey(const ValueKey('dest-poi-search')), '東京');
    await tester.tap(find.byKey(const ValueKey('dest-poi-search-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('poi-result-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('大概時間'));
    await tester.pumpAndSettle();
  }

  testWidgets('目的地空 → 送出鈕 disabled', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    final btn = tester.widget<TpToolbarTextButton>(
      find.byKey(const ValueKey('create-submit')),
    );
    expect(btn.onPressed, isNull);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('新增'), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
  });

  testWidgets('首屏只顯示必要欄位，資料有效後才揭露選填設定', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('create-next-step-hint')), findsOneWidget);
    expect(find.byKey(const ValueKey('create-more-needs')), findsNothing);
    expect(find.byKey(const ValueKey('ai-authorize-card')), findsNothing);

    await completeBasics(tester);

    expect(find.byKey(const ValueKey('create-next-step-hint')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('create-more-needs')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('create-more-needs')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-more-needs')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-more-needs')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-desc')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ai-authorize-card')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('ai-authorize-card')), findsOneWidget);
  });

  testWidgets('POI 搜尋 → 點結果 → 加入目的地', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('dest-poi-search')), '東京');
    await tester.tap(find.byKey(const ValueKey('dest-poi-search-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('poi-result-p1')));
    await tester.pumpAndSettle();

    // 已加入目的地清單(「至少選 1 個」提示消失)
    expect(find.text('至少選 1 個目的地'), findsNothing);
    expect(find.text('東京'), findsWidgets);
  });

  testWidgets('POI 搜尋 → 點結果 → 出現在最近搜尋 chips', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('dest-poi-search')), '東京');
    await tester.tap(find.byKey(const ValueKey('dest-poi-search-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('poi-result-p1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dest-recent-dests')), findsOneWidget);
    expect(find.byKey(const ValueKey('dest-recent-東京')), findsOneWidget);
  });

  testWidgets('切到彈性模式 → 顯示天數 stepper', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('大概時間'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-flex-count')), findsOneWidget);
  });

  testWidgets('AI 授權載入時只顯示說明，POST busy 後顯示已授權', (tester) async {
    final load = Completer<bool>();
    final authorize = Completer<bool>();
    when(() => authRepo.fetchAiAuthorization()).thenAnswer((_) => load.future);
    when(() => authRepo.authorizeAi()).thenAnswer((_) => authorize.future);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await completeBasics(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ai-authorize-card')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('讓 AI 幫你把行程填滿'), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-authorize-btn')), findsNothing);

    load.complete(false);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-authorize-btn')));
    await tester.pump();

    expect(find.text('授權中⋯'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('ai-authorize-btn')))
          .onPressed,
      isNull,
    );

    authorize.complete(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-authorize-on')), findsOneWidget);
    expect(find.text('已授權 · 可隨時在「已連結應用」撤銷'), findsOneWidget);
  });

  testWidgets('AI 授權失敗顯示錯誤並可重試', (tester) async {
    when(() => authRepo.authorizeAi()).thenThrow(Exception('offline'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await completeBasics(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ai-authorize-card')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('ai-authorize-btn')));
    await tester.pumpAndSettle();

    expect(find.text('授權失敗，請稍後再試。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('ai-authorize-btn')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('新增送出中暫停日期編輯並宣告進度', (tester) async {
    final pending =
        Completer<
          ({String tripId, int daysCreated, int destinationsCreated})
        >();
    when(
      () => tripRepo.createTrip(
        name: any(named: 'name'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        description: any(named: 'description'),
        countries: any(named: 'countries'),
        destinations: any(named: 'destinations'),
      ),
    ).thenAnswer((_) => pending.future);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await completeBasics(tester);
    final count = find.byKey(const ValueKey('create-flex-count'));
    expect(tester.widget<Text>(count).data, '5');

    await tester.tap(find.byKey(const ValueKey('create-submit')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('create-flex-plus')));
    await tester.tap(find.byKey(const ValueKey('create-flex-plus')));
    await tester.pump();

    expect(tester.widget<Text>(count).data, '5');
    final progress = find.text('新增中…');
    expect(progress, findsOneWidget);
    expect(
      find.ancestor(
        of: progress,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsWidgets,
    );
    expect(
      tester
          .widget<TpToolbarTextButton>(
            find.byKey(const ValueKey('create-submit')),
          )
          .onPressed,
      isNull,
    );

    pending.complete((
      tripId: 'accepted-trip',
      daysCreated: 5,
      destinationsCreated: 1,
    ));
    await tester.pumpAndSettle();
    expect(find.text('TRIP accepted-trip'), findsOneWidget);
  });

  testWidgets('新增失敗保留完整草稿，送出期間停用輸入並可原樣重試', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending =
        Completer<
          ({String tripId, int daysCreated, int destinationsCreated})
        >();
    final requests = <Map<Symbol, dynamic>>[];
    when(
      () => tripRepo.createTrip(
        name: any(named: 'name'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        description: any(named: 'description'),
        countries: any(named: 'countries'),
        destinations: any(named: 'destinations'),
      ),
    ).thenAnswer((invocation) {
      requests.add(invocation.namedArguments);
      return requests.length == 1
          ? pending.future
          : Future.value((
              tripId: 'retry-trip',
              daysCreated: 6,
              destinationsCreated: 2,
            ));
    });
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await completeBasics(tester);
    await tester.tap(find.widgetWithText(ActionChip, '京都'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-flex-plus')));
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.add_circled).at(1));
    await tester.tap(find.byKey(const ValueKey('create-more-needs')));
    await tester.pumpAndSettle();
    final description = find.byKey(const ValueKey('create-desc'));
    await tester.enterText(description, '拉麵與二手書店');
    await tester.tap(find.byKey(const ValueKey('create-submit')));
    await tester.pump();

    expect(tester.widget<TextField>(description).enabled, isFalse);
    expect(
      tester
          .widget<CupertinoSearchTextField>(
            find.byKey(const ValueKey('dest-poi-search')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<ActionChip>(find.widgetWithText(ActionChip, '京都'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('取消'));
    await tester.pump();
    expect(find.text('捨棄未儲存的變更？'), findsNothing);
    expect(requests, hasLength(1));
    expect(requests.single[#name], '東京、京都');
    expect(requests.single[#description], '拉麵與二手書店');
    expect(
      (requests.single[#destinations] as List<DestinationInput>).first.dayQuota,
      2,
    );

    pending.completeError(
      const ApiError(status: 409, code: 'CONFLICT', message: 'conflict'),
    );
    await tester.pumpAndSettle();
    expect(find.text('行程新增衝突，請再試一次'), findsOneWidget);
    expect(find.text('新增中…'), findsNothing);
    expect(tester.widget<TextField>(description).controller!.text, '拉麵與二手書店');
    expect(tester.widget<TextField>(description).enabled, isTrue);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('create-flex-count'))).data,
      '6',
    );
    expect(find.byKey(const ValueKey('dest-0-東京')), findsOneWidget);
    expect(find.byKey(const ValueKey('dest-1-京都')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-submit')));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests.last, requests.first);
    expect(find.text('TRIP retry-trip'), findsOneWidget);
  });

  testWidgets('連點只新增一次，成功等待離頁時不能把新輸入變成第二筆行程', (tester) async {
    final pending =
        Completer<
          ({String tripId, int daysCreated, int destinationsCreated})
        >();
    final exit = Completer<bool>();
    var requests = 0;
    var exits = 0;
    when(
      () => tripRepo.createTrip(
        name: any(named: 'name'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        description: any(named: 'description'),
        countries: any(named: 'countries'),
        destinations: any(named: 'destinations'),
      ),
    ).thenAnswer((_) {
      requests++;
      return pending.future;
    });
    await tester.pumpWidget(
      buildApp(
        beforeExit: () {
          exits++;
          return exit.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await completeBasics(tester);
    final submit = find.byKey(const ValueKey('create-submit'));
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(requests, 1);
    pending.complete((
      tripId: 'only-trip',
      daysCreated: 5,
      destinationsCreated: 1,
    ));
    await tester.pumpAndSettle();
    expect(exits, 1);
    expect(find.byType(CreateTripScreen), findsOneWidget);
    final plus = find.byKey(const ValueKey('create-flex-plus'));
    await tester.ensureVisible(plus);
    await tester.tap(plus);
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('create-flex-count'))).data,
      '5',
    );
    await tester.tap(submit);
    await tester.pump();
    expect(requests, 1);
    exit.complete(true);
    await tester.pumpAndSettle();
    expect(exits, 1);
    expect(find.text('TRIP only-trip'), findsOneWidget);
  });

  testWidgets('加目的地 + 彈性日期 → 送出呼叫 createTrip + 導頁', (tester) async {
    when(() => authRepo.fetchAiAuthorization()).thenThrow(Exception('offline'));
    when(
      () => tripRepo.createTrip(
        name: any(named: 'name'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        countries: any(named: 'countries'),
        published: any(named: 'published'),
        dataSource: any(named: 'dataSource'),
        lang: any(named: 'lang'),
        destinations: any(named: 'destinations'),
      ),
    ).thenAnswer(
      (_) async => (tripId: 'tokyo-x', daysCreated: 5, destinationsCreated: 1),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // 加目的地並切到自動有效的彈性日期
    await completeBasics(tester);

    // 送出(捲到底確保可點)
    await tester.ensureVisible(find.byKey(const ValueKey('create-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-submit')));
    await tester.pumpAndSettle();

    verify(
      () => tripRepo.createTrip(
        name: '東京',
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        countries: 'JP',
        destinations: any(named: 'destinations'),
      ),
    ).called(1);
    expect(find.text('TRIP tokyo-x'), findsOneWidget); // 已導去新行程
  });
}
