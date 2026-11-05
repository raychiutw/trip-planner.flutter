/// #387：跨畫面流程的狀態連續性驗證（iPad resize、地圖往返、離線衝突）。
///
/// 全部走正式 `TriplineApp` 與正式 router／provider 鏈，只替換網路與平台邊界
/// （`AppFlowFixture`）。這些是 host runner 上的 widget test，不是真機也不是原生地圖。
library;

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:go_router/go_router.dart';
import 'package:tripline/app/router.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/entry.dart';

import '../../integration_test/support/app_flow_fixture.dart';

const _compact = Size(390, 844);
const _regular = Size(1024, 768);

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

AppFlowFixture _signedInFixture() {
  final fixture = AppFlowFixture.loggedOut();
  fixture.session.signedIn = true;
  addTearDown(fixture.dispose);
  return fixture;
}

void _expectDaySelected(int dayNum, {required int of}) {
  final day = find.semantics.byLabel('第 $dayNum 天，共 $of 天');
  expect(day, findsOne, reason: 'Day $dayNum 的 pill 要存在且唯一');
  expect(
    day.evaluate().single.getSemanticsData().flagsCollection.isSelected,
    Tristate.isTrue,
    reason: 'Day $dayNum 要是選取態',
  );
}

Future<void> _openOkinawaDay2(WidgetTester tester) async {
  await tester.tap(find.text('沖繩家族之旅').first);
  await tester.pumpAndSettle();
  expect(find.text('那霸機場'), findsOneWidget);
  await tester.ensureVisible(find.byKey(const ValueKey('day-pill-2')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('day-pill-2')));
  await tester.pumpAndSettle();
  expect(find.text('首里城'), findsOneWidget);
  _expectDaySelected(2, of: 2);
}

Future<void> _pumpApp(WidgetTester tester, AppFlowFixture fixture) async {
  await tester.pumpWidget(fixture.app);
  await tester.pumpAndSettle();
  expect(find.byType(TripsListScreen), findsOneWidget);
}

GoRouter _routerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(appRouterProvider);

void _expectSidebarSelected(WidgetTester tester, String tripId) {
  expect(
    tester
        .getSemantics(find.byKey(ValueKey('trip-sidebar-item-$tripId')))
        .getSemanticsData()
        .flagsCollection
        .isSelected,
    Tristate.isTrue,
    reason: 'regular 側欄要標出目前行程 $tripId',
  );
}

void main() {
  testWidgets('流程5-a iPad resize：Trip／Day 選擇與導覽堆疊不重置', (tester) async {
    _setView(tester, _compact);
    final semantics = tester.ensureSemantics();
    final fixture = _signedInFixture();
    await _pumpApp(tester, fixture);
    await _openOkinawaDay2(tester);
    final router = _routerOf(tester);
    final location = router.state.uri.toString();
    expect(location, contains('okinawa'));

    tester.view.physicalSize = _regular;
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('trip-regular-split-view')),
      findsOneWidget,
      reason: 'regular 寬度要走分欄',
    );
    expect(router.state.uri.toString(), location);
    expect(find.text('首里城'), findsOneWidget);
    _expectDaySelected(2, of: 2);
    _expectSidebarSelected(tester, 'okinawa');

    tester.view.physicalSize = _compact;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-regular-split-view')), findsNothing);
    expect(router.state.uri.toString(), location);
    expect(find.text('首里城'), findsOneWidget);
    _expectDaySelected(2, of: 2);

    // 導覽堆疊沒被重置：返回仍回到行程列表。
    await tester.tap(find.byKey(const ValueKey('trip-timeline-back')));
    await tester.pumpAndSettle();
    expect(find.byType(TripsListScreen), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('流程5-b iPad resize：停留點編輯 sheet 的未送出草稿不重置', (tester) async {
    _setView(tester, _compact);
    final fixture = _signedInFixture();
    final entryChanges = StreamController<TimelineEntry>.broadcast();
    addTearDown(entryChanges.close);
    when(
      () => fixture.trips.watchEntry(tripId: 'okinawa', entryId: 21),
    ).thenAnswer((_) => entryChanges.stream);
    await _pumpApp(tester, fixture);
    await _openOkinawaDay2(tester);

    await tester.tap(find.byKey(const ValueKey('entry-more-21')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-edit-21')));
    await tester.pumpAndSettle();
    entryChanges.add(releaseSmokeDays[1].timeline.single);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '跨尺寸草稿',
    );
    await tester.pump();
    final router = _routerOf(tester);
    final location = router.state.uri.toString();

    for (final size in [_regular, _compact, _regular, _compact]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), location, reason: '$size');
      expect(
        find.widgetWithText(TextField, '跨尺寸草稿'),
        findsOneWidget,
        reason: '$size 草稿要保留',
      );
    }
  });

  testWidgets('流程5-c iPad resize：聊天未送出草稿不重置', (tester) async {
    _setView(tester, _compact);
    final fixture = _signedInFixture();
    await _pumpApp(tester, fixture);
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('root-tab-聊天'))),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '跨尺寸聊天草稿');
    await tester.pump();

    for (final size in [_regular, _compact]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(find.text('跨尺寸聊天草稿'), findsOneWidget, reason: '$size');
    }
  });

  testWidgets('流程3 地圖往返：Day 與選取狀態在行程↔地圖之間保留（假地圖畫布）', (tester) async {
    _setView(tester, _compact);
    final semantics = tester.ensureSemantics();
    final fixture = _signedInFixture();
    await _pumpApp(tester, fixture);
    await _openOkinawaDay2(tester);

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('root-tab-地圖'))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsOneWidget);
    _expectDaySelected(2, of: 2); // 時間軸選的 Day 2 帶進地圖

    // 點地圖上的 Google POI → accessory；關閉後 Day 仍是 2。
    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey('fake-google-poi-trigger')),
        )
        .onTap!();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('google-poi-accessory')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('google-poi-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('google-poi-accessory')), findsNothing);
    _expectDaySelected(2, of: 2);

    // 地圖改選 Day 1 → 回行程，時間軸跟著是 Day 1。
    await tester.tap(find.byKey(const ValueKey('trip-map-day-1')));
    await tester.pumpAndSettle();
    _expectDaySelected(1, of: 2);
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('root-tab-行程'))),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('trip-timeline-view-day-selector')),
      findsOneWidget,
    );
    expect(find.text('那霸機場'), findsOneWidget);
    _expectDaySelected(1, of: 2);

    // 再回地圖：仍在同一行程同一天。
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('root-tab-地圖'))),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('global-trip-map-okinawa')),
      findsOneWidget,
    );
    _expectDaySelected(1, of: 2);
    semantics.dispose();
  });

  testWidgets('流程2-離線 離線寫入重送撞 409 → 衝突橫幅與解決 sheet，保留我的版本後仍在原行程原日', (
    tester,
  ) async {
    _setView(tester, _compact);
    final semantics = tester.ensureSemantics();
    final fixture = _signedInFixture();
    final patchedVersions = <int>[];
    final cache = InMemoryCacheStore();
    final dio = Dio(BaseOptions())..options.validateStatus = (_) => true;
    final adapter = DioAdapter(dio: dio);
    // DioAdapter 的 reply 回呼在註冊時就執行，不能拿來計次；改記錄實際送出的請求。
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'PATCH') {
            patchedVersions.add(
              (options.data as Map)['expectedVersion']! as int,
            );
          }
          handler.next(options);
        },
      ),
    );
    final client = ApiClient(dio: dio, cacheStore: cache);
    fixture
      ..realCacheStore = cache
      ..realApiClient = client;
    const entryPath = '/trips/okinawa/entries/21';
    adapter
      ..onPatch(
        entryPath,
        (server) => server.reply(409, {
          'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
        }),
        data: {
          'description': '我的離線備註',
          'start_time': null,
          'end_time': null,
          'expectedVersion': 0,
        },
      )
      ..onGet(
        '/trips/okinawa/days',
        (server) => server.reply(200, [
          {
            'dayNum': 2,
            'timeline': [
              {'id': 21, 'version': 1, 'description': '協作者備註'},
            ],
          },
        ]),
        queryParameters: {'all': '1'},
      )
      ..onPatch(
        entryPath,
        (server) => server.reply(200, {'ok': true}),
        data: {'description': '我的離線備註', 'expectedVersion': 1},
      );

    await _pumpApp(tester, fixture);
    await _openOkinawaDay2(tester);

    // 離線時排進佇列的編輯；連線後重送撞上協作者較新的版本。
    await cache.appendMutation(
      QueuedMutation(
        id: 'q1',
        method: 'PATCH',
        path: entryPath,
        body: const {
          'description': '我的離線備註',
          'start_time': null,
          'end_time': null,
          'expectedVersion': 0,
        },
        type: 'entry.update',
        cacheKey: cacheKeyFor('GET', '/trips/okinawa/days', {'all': '1'}),
        args: const {'entryId': 21, 'description': '我的離線備註'},
        createdAt: 't',
        base: const {'description': null},
      ),
    );
    final flushed = await tester.runAsync(client.flushQueue);
    await tester.pumpAndSettle();
    expect(flushed!.conflicts, hasLength(1));
    expect(await cache.readQueue(), isEmpty);
    expect(
      find.byKey(const ValueKey('offline-conflict-banner')),
      findsOneWidget,
    );
    expect(find.text('1 筆同步衝突'), findsOneWidget);

    await tester.tap(find.text('檢視'));
    await tester.pumpAndSettle();
    expect(find.text('協作者備註'), findsOneWidget);
    expect(find.text('我的離線備註'), findsWidgets);
    final keepOurs = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('conflict-keep-ours-');
    });
    await tester.tap(keepOurs);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('conflict-apply')));
    // dio mock adapter 的回應走真實非同步；輪詢到衝突清掉為止（最多約 2 秒）。
    for (var i = 0; i < 20 && (await cache.readConflicts()).isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(patchedVersions, [0, 1], reason: '先以舊版本撞 409，解決時以新版本重送一次');
    expect(await cache.readConflicts(), isEmpty);
    expect(find.byKey(const ValueKey('conflict-apply')), findsNothing);
    expect(find.byKey(const ValueKey('offline-conflict-banner')), findsNothing);
    expect(find.text('首里城'), findsOneWidget);
    _expectDaySelected(2, of: 2);
    semantics.dispose();
  });

  testWidgets('流程1-尾端 進入 Account 設定子頁再返回：行程與 Day 選擇保留', (tester) async {
    _setView(tester, _compact);
    final semantics = tester.ensureSemantics();
    final fixture = _signedInFixture();
    await _pumpApp(tester, fixture);
    await _openOkinawaDay2(tester);
    final router = _routerOf(tester);
    final location = router.state.uri.toString();

    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    await tester.pumpAndSettle();
    final accountScroll = find.descendant(
      of: find.byKey(const ValueKey('account-sheet-content')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-appearance')),
      -200,
      scrollable: accountScroll,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-appearance')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('appearance-page')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-sheet-content')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-large-sheet')), findsNothing);
    expect(router.state.uri.toString(), location);
    expect(find.text('首里城'), findsOneWidget);
    _expectDaySelected(2, of: 2);
    semantics.dispose();
  });
}
