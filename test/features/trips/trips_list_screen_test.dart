import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trips/trip_card.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';

class MockTripRepository extends Mock implements TripRepository {}

/// 固定回傳指定使用者的假 AuthNotifier（不打 API），供卡片判斷「由你建立」。
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._fixedUser);

  final UserInfo? _fixedUser;

  @override
  Future<UserInfo?> build() async => _fixedUser;
}

class _FakeTripImportFilePicker implements TripImportFilePicker {
  const _FakeTripImportFilePicker(this.file);

  final TripImportFile? file;

  @override
  Future<TripImportFile?> pick() async => file;
}

class _FakeTripExportFileWriter implements TripExportFileWriter {
  String? suggestedName;
  String? content;
  bool saved = true;

  @override
  Future<bool> save({
    required String suggestedName,
    required String content,
  }) async {
    this.suggestedName = suggestedName;
    this.content = content;
    return saved;
  }
}

UserInfo _userWithId(String id) => UserInfo(id: id, email: '$id@example.com');

/// 頁首 + 搜尋/篩選 header 會吃掉垂直空間;預設 600px 測試視窗下 SliverList 懶載入
/// 只建部分卡片。放大視窗讓短清單一次全建,穩定斷言卡片數。
/// setSurfaceSize 斷言須在測試內呼叫,故用 helper + addTearDown 於測試 zone 內還原。
Future<void> _useWideSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  const fakeTrips = [
    TripSummary(
      tripId: 'okinawa-trip-2026',
      name: 'okinawa-trip-2026',
      title: '沖繩家族之旅',
      totalDays: 5,
    ),
    TripSummary(
      tripId: 'kyoto-trip-2025',
      name: 'kyoto-trip-2025',
      // title 為 null → 卡片應退回顯示 name
      totalDays: 4,
    ),
    TripSummary(
      tripId: 'busan-trip-2024',
      name: 'busan-trip-2024',
      title: '釜山美食團',
      // totalDays 為 null → 不顯示 eyebrow
    ),
  ];

  /// 把畫面包進假 GoRouter：/trips 是清單頁、/trips/:tripId 是導航目的地探針。
  /// （flutter_riverpod 3.x 未匯出 Override 型別，overrides 由各測試
  /// 直接在 ProviderScope 建構處以 list literal 傳入。）
  ///
  /// `bottomInset` 模擬 AppShell（extendBody）灌進 body 的浮動 tab bar 高度。
  Widget buildRouterApp({double bottomInset = 0}) {
    final fakeRouter = GoRouter(
      initialLocation: '/trips',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (context, state) => const TripsListScreen(),
        ),
        GoRoute(
          path: '/trips/:tripId',
          builder: (context, state) =>
              Scaffold(body: Text('detail:${state.pathParameters['tripId']}')),
          routes: [
            GoRoute(
              path: 'health',
              builder: (context, state) => Scaffold(
                body: Text('health:${state.pathParameters['tripId']}'),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/share-trip/:tripId',
          builder: (context, state) =>
              Scaffold(body: Text('share:${state.pathParameters['tripId']}')),
        ),
        GoRoute(
          path: '/collab/:tripId',
          builder: (context, state) =>
              Scaffold(body: Text('collab:${state.pathParameters['tripId']}')),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: fakeRouter,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(padding: EdgeInsets.only(bottom: bottomInset)),
        child: child!,
      ),
    );
  }

  group('TripsListScreen 底部淨空', () {
    // AppShell 開 extendBody,Flutter 把浮動 tab bar 高度灌進 body 的
    // MediaQuery.padding.bottom(scaffold.dart _BodyBuilder)。清單必須吃掉它,
    // 否則捲到底時最後一張卡永久壓在 tab bar 下。
    testWidgets('捲到底時最後一張卡不被浮動 tab bar 蓋住', (tester) async {
      const inset = 100.0;
      // 清單必須長到溢出視窗,否則捲不動、最後一張卡停在畫面中段,斷言會假綠燈。
      final longTripList = [
        for (var index = 0; index < 20; index++)
          TripSummary(
            tripId: 'trip-$index',
            name: 'trip-$index',
            title: '行程 $index',
            totalDays: 3,
          ),
      ];
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(longTripList)),
          ],
          child: buildRouterApp(bottomInset: inset),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final lastCard = tester.getRect(find.byType(TripCard).last);
      expect(lastCard.bottom, lessThanOrEqualTo(800 - inset));
    });
  });

  group('TripsListScreen 清單渲染', () {
    testWidgets('功能選單收納新增行程，Account 入口固定在 Header', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('trips-create-fab')), findsNothing);
      expect(find.byType(TpRootScaffold), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tp-root-glass-header')),
        findsOneWidget,
      );
      expect(find.text('我的行程'), findsOneWidget);
      expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
      expect(find.byKey(const ValueKey('tp-app-bar-close')), findsNothing);
      expect(find.byKey(const ValueKey('trips-sort-button')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('account-avatar-button')),
        findsOneWidget,
      );
      expect(find.byType(SliverAppBar), findsNothing);
      expect(find.byTooltip('更多'), findsOneWidget);
      // 每張行程卡另有自己的「⋯」選單，這裡只數 header 那一顆。
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tp-root-glass-header')),
          matching: find.byWidgetPredicate(
            (widget) => widget is TpMoreMenuButton,
          ),
        ),
        findsOneWidget,
      );
      final moreGlass = find.descendant(
        of: find.byKey(const ValueKey('trips-sort-button')),
        matching: find.byKey(const ValueKey('tp-toolbar-glass-button')),
      );
      expect(tester.getSize(moreGlass), const Size(44, 44));

      await tester.tap(find.byKey(const ValueKey('trips-sort-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trips-create-button')), findsOneWidget);
      expect(find.text('新增行程'), findsOneWidget);
      // 動作配字符；排序是值選項，只以勾選標示目前排序。
      Finder menuItem(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(GlassMenuItem),
      );
      expect(
        find.descendant(
          of: menuItem('新增行程'),
          matching: find.byIcon(CupertinoIcons.add),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: menuItem('預設順序'),
          matching: find.byIcon(CupertinoIcons.check_mark),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menuItem('預設順序'), matching: find.byType(Icon)),
        findsOneWidget,
        reason: '選取值只有勾選，沒有另配字符',
      );
      expect(
        find.descendant(of: menuItem('名稱 A→Z'), matching: find.byType(Icon)),
        findsNothing,
      );
    });

    testWidgets('渲染 N 張中性卡：標題與 eyebrow', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      expect(find.text('我的行程'), findsWidgets);
      expect(find.byType(TripCard), findsNWidgets(3));

      // title 優先顯示，無 title 退回 name
      expect(find.text('沖繩家族之旅'), findsOneWidget);
      expect(find.text('kyoto-trip-2025'), findsOneWidget);
      expect(find.text('釜山美食團'), findsOneWidget);

      // eyebrow：totalDays 天；null 則不顯示
      expect(find.text('5 天'), findsOneWidget);
      expect(find.text('4 天'), findsOneWidget);

      for (final trip in fakeTrips) {
        expect(
          find.byKey(ValueKey('trip-card-cover-${trip.tripId}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('empty state：顯示「尚無行程」hero 文案', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith(
              (ref) => Stream.value(const <TripSummary>[]),
            ),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      expect(find.byType(TripCard), findsNothing);
      expect(find.text('尚無行程'), findsOneWidget);
    });

    testWidgets('error state：顯示重試按鈕，點擊後重新載入成功', (tester) async {
      await _useWideSurface(tester);
      var fetchAttempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          // 關閉 riverpod 3.x 自動 retry，讓 error state 可被穩定斷言
          retry: (retryCount, error) => null,
          overrides: [
            myTripsProvider.overrideWith((ref) {
              fetchAttempts++;
              if (fetchAttempts == 1) {
                return Stream.error(Exception('network down'));
              }
              return Stream.value(fakeTrips);
            }),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('重試'), findsOneWidget);
      expect(find.byType(TripCard), findsNothing);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('trips-error-state')))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );

      await tester.tap(find.text('重試'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(TripCard), findsNWidgets(3));
    });

    testWidgets('loading state 使用 VoiceOver 即時語意', (tester) async {
      final neverCompletes = Completer<List<TripSummary>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith(
              (ref) => Stream.fromFuture(neverCompletes.future),
            ),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      final semantics = tester
          .getSemantics(find.byKey(const ValueKey('trips-loading-state')))
          .getSemanticsData();
      expect(semantics.label, '正在載入行程清單');
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
    });
  });

  group('TripsListScreen 搜尋', () {
    testWidgets('輸入關鍵字 → 只顯示符合的卡片', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();
      // 初始：3 張卡全部顯示
      expect(find.byType(TripCard), findsNWidgets(3));

      // 在搜尋框輸入「沖繩」
      await tester.enterText(
        find.byKey(const ValueKey('trips-search-field')),
        '沖繩',
      );
      await tester.pump();

      // 只剩符合的卡片
      expect(find.byType(TripCard), findsOneWidget);
      expect(find.text('沖繩家族之旅'), findsOneWidget);
      expect(find.text('kyoto-trip-2025'), findsNothing);
      expect(find.text('釜山美食團'), findsNothing);
    });

    testWidgets('清空搜尋框 → 全部卡片還原', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      final searchField = find.byKey(const ValueKey('trips-search-field'));
      await tester.enterText(searchField, '釜山');
      await tester.pump();
      expect(find.byType(TripCard), findsOneWidget);

      // 清空搜尋框
      await tester.enterText(searchField, '');
      await tester.pump();

      // 全部卡片還原
      expect(find.byType(TripCard), findsNWidgets(3));
    });

    testWidgets('鍵盤 Search 收合鍵盤但保留查詢，清除鈕還原完整清單', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      final searchField = find.byKey(const ValueKey('trips-search-field'));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: searchField,
                matching: find.byType(EditableText),
              ),
            )
            .textInputAction,
        TextInputAction.search,
      );

      await tester.enterText(searchField, '沖繩');
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: searchField,
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isFalse,
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: searchField,
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '沖繩',
      );
      expect(find.text('沖繩家族之旅'), findsOneWidget);
      expect(find.byType(TripCard), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
      await tester.pump();

      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: searchField,
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        isEmpty,
      );
      expect(find.byType(TripCard), findsNWidgets(3));
    });

    testWidgets('無相符結果 → 顯示空狀態文字', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('trips-search-field')),
        '找不到我',
      );
      await tester.pump();

      expect(find.byType(TripCard), findsNothing);
      expect(find.text('找不到符合的行程'), findsOneWidget);
    });

    testWidgets('搜尋匹配 name 欄位（無 title 的行程）', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      // kyoto-trip-2025 的 title 為 null，顯示 name；搜尋 name 應能命中
      await tester.enterText(
        find.byKey(const ValueKey('trips-search-field')),
        'kyoto',
      );
      await tester.pump();

      expect(find.byType(TripCard), findsOneWidget);
      expect(find.text('kyoto-trip-2025'), findsOneWidget);
    });

    testWidgets('filtered 後仍使用中性卡片', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      // 搜尋「busan」→ 只剩第三張。
      await tester.enterText(
        find.byKey(const ValueKey('trips-search-field')),
        'busan',
      );
      await tester.pump();

      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.length, 1);
      expect(cards.first.trip.tripId, 'busan-trip-2024');
    });
  });

  group('TripsListScreen 排序', () {
    // 名稱亂序：busan < kyoto < okinawa（ASCII/locale 順），但原始順序是 okinawa, kyoto, busan
    const unsortedTrips = [
      TripSummary(
        tripId: 'okinawa-trip-2026',
        name: 'okinawa-trip-2026',
        title: '沖繩家族之旅',
        totalDays: 5,
      ),
      TripSummary(
        tripId: 'kyoto-trip-2025',
        name: 'kyoto-trip-2025',
        totalDays: 4,
      ),
      TripSummary(
        tripId: 'busan-trip-2024',
        name: 'busan-trip-2024',
        title: '釜山美食團',
      ),
    ];

    testWidgets('初始有排序按鈕，預設顯示原始順序', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(unsortedTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      // 排序按鈕應存在
      expect(find.byKey(const ValueKey('trips-sort-button')), findsOneWidget);

      // 預設順序：okinawa → kyoto → busan（沖繩 → kyoto → 釜山）
      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.length, 3);
      expect(cards[0].trip.tripId, 'okinawa-trip-2026');
      expect(cards[1].trip.tripId, 'kyoto-trip-2025');
      expect(cards[2].trip.tripId, 'busan-trip-2024');
    });

    testWidgets('選「名稱 A→Z」後依 displayTitle 排序', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(unsortedTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      // 點排序按鈕開 PopupMenu
      await tester.tap(find.byKey(const ValueKey('trips-sort-button')));
      await tester.pumpAndSettle();

      // 點「名稱 A→Z」
      await tester.tap(find.text('名稱 A→Z'));
      await tester.pumpAndSettle();

      // displayTitle: '沖繩家族之旅' (U+51D6≈27990) / 'kyoto-trip-2025' (U+6B) / '釜山美食團' (U+91DC≈37340)
      // compareTo 順序：'kyoto-trip-2025' < '沖繩家族之旅' < '釜山美食團'（ASCII < 沖 < 釜）
      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.length, 3);
      expect(cards[0].trip.tripId, 'kyoto-trip-2025');
      expect(cards[1].trip.tripId, 'okinawa-trip-2026');
      expect(cards[2].trip.tripId, 'busan-trip-2024');
    });

    testWidgets('選「預設順序」可切回原始順序', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(unsortedTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      // 先切到 nameAsc
      await tester.tap(find.byKey(const ValueKey('trips-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('名稱 A→Z'));
      await tester.pumpAndSettle();

      // 再切回「預設順序」
      await tester.tap(find.byKey(const ValueKey('trips-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('預設順序'));
      await tester.pumpAndSettle();

      // 還原原始順序
      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.length, 3);
      expect(cards[0].trip.tripId, 'okinawa-trip-2026');
      expect(cards[1].trip.tripId, 'kyoto-trip-2025');
      expect(cards[2].trip.tripId, 'busan-trip-2024');
    });

    testWidgets('搜尋 + 排序並存：filter 之後再 sort', (tester) async {
      await _useWideSurface(tester);
      // 加入第四筆，讓搜尋後仍有多筆可以驗證排序
      const moreTrips = [
        TripSummary(
          tripId: 'okinawa-trip-2026',
          name: 'okinawa-trip-2026',
          title: '沖繩家族之旅',
          totalDays: 5,
        ),
        TripSummary(
          tripId: 'okinawa-food-2025',
          name: 'okinawa-food-2025',
          title: 'Okinawa Food Tour',
          totalDays: 3,
        ),
        TripSummary(
          tripId: 'kyoto-trip-2025',
          name: 'kyoto-trip-2025',
          totalDays: 4,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(moreTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      // 搜尋「okinawa」→ filter 到 2 筆（okinawa-trip + okinawa-food）
      await tester.enterText(
        find.byKey(const ValueKey('trips-search-field')),
        'okinawa',
      );
      await tester.pump();
      expect(find.byType(TripCard), findsNWidgets(2));

      // 切「名稱 A→Z」
      await tester.tap(find.byKey(const ValueKey('trips-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('名稱 A→Z'));
      await tester.pumpAndSettle();

      // 'Okinawa Food Tour'(O=79) < '沖繩家族之旅'(沖=27798)（ASCII < CJK）
      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.length, 2);
      expect(cards[0].trip.tripId, 'okinawa-food-2025');
      expect(cards[1].trip.tripId, 'okinawa-trip-2026');
    });

    testWidgets('nameAsc 排序後仍使用中性卡片', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(unsortedTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('trips-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('名稱 A→Z'));
      await tester.pumpAndSettle();

      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.length, 3);
      expect(cards.map((card) => card.trip.tripId).toSet(), hasLength(3));
    });
  });

  group('TripsListScreen 行程卡選單', () {
    const moreKey = ValueKey('trip-card-more-okinawa-trip-2026');
    const menuLabels = {
      'trip-menu-share-okinawa-trip-2026': '分享',
      'trip-menu-collab-okinawa-trip-2026': '共編',
      'trip-menu-health-okinawa-trip-2026': 'AI 健檢',
      'trip-menu-export-okinawa-trip-2026': '匯出 JSON',
      'trip-menu-delete-okinawa-trip-2026': '刪除行程',
    };

    /// 篩選分頁也有「共編」二字，選單內文字一律以項目 key 定位。
    Finder menuText(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.text(menuLabels[key]!),
    );

    void expectMenuLabels() {
      for (final entry in menuLabels.entries) {
        expect(menuText(entry.key), findsOneWidget, reason: entry.value);
      }
    }

    Future<void> pumpList(WidgetTester tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();
    }

    testWidgets('點「⋯」在卡片旁展開玻璃選單：上排三個快捷動作、下方匯出與分組刪除', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpList(tester);

      await tester.tap(find.byKey(moreKey));
      await tester.pumpAndSettle();

      expectMenuLabels();
      expect(find.text('取消'), findsNothing, reason: '不再是底部動作表');
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.bySemanticsLabel('共編設定'), findsOneWidget);

      final share = tester.getRect(
        menuText('trip-menu-share-okinawa-trip-2026'),
      );
      final collab = tester.getRect(
        menuText('trip-menu-collab-okinawa-trip-2026'),
      );
      final health = tester.getRect(
        menuText('trip-menu-health-okinawa-trip-2026'),
      );
      expect(share.top, closeTo(collab.top, 0.5));
      expect(collab.top, closeTo(health.top, 0.5));
      expect(share.right, lessThan(collab.left));
      expect(collab.right, lessThan(health.left));
      final export = tester.getRect(
        menuText('trip-menu-export-okinawa-trip-2026'),
      );
      final delete = tester.getRect(
        menuText('trip-menu-delete-okinawa-trip-2026'),
      );
      expect(export.top, greaterThan(share.bottom));
      expect(delete.top, greaterThan(export.bottom));
      for (final symbol in [
        CupertinoIcons.share,
        CupertinoIcons.person_2,
        CupertinoIcons.sparkles,
        CupertinoIcons.square_arrow_down,
        CupertinoIcons.delete,
      ]) {
        expect(find.byIcon(symbol), findsOneWidget, reason: '$symbol');
      }

      // 選單從卡片附近展開，不是貼在畫面底部。
      final card = tester.getRect(
        find.ancestor(of: find.text('沖繩家族之旅'), matching: find.byType(TripCard)),
      );
      expect(share.top, lessThan(card.bottom + 120));
      expect(share.top, greaterThan(card.top - 120));
      semantics.dispose();
    });

    testWidgets('「⋯」維持 44×44 與「行程選項」可及性名稱，且不套玻璃外框', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpList(tester);

      final size = tester.getSize(find.byKey(moreKey));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(
        find.descendant(
          of: find.byKey(moreKey),
          matching: find.byType(GlassButton),
        ),
        findsNothing,
        reason: '內容卡上的入口不疊玻璃',
      );
      final flags = tester
          .getSemantics(find.bySemanticsLabel('行程選項').first)
          .getSemanticsData()
          .flagsCollection;
      expect(flags.isButton, isTrue);
      semantics.dispose();
    });

    testWidgets('長按卡片與「⋯」取得同一組動作；共編走 /collab、分享走 /share-trip', (tester) async {
      await pumpList(tester);

      await tester.longPress(find.text('沖繩家族之旅'));
      await tester.pumpAndSettle();
      expectMenuLabels();
      await tester.tap(menuText('trip-menu-collab-okinawa-trip-2026'));
      await tester.pumpAndSettle();
      expect(find.text('collab:okinawa-trip-2026'), findsOneWidget);
    });

    testWidgets('「⋯」→ 分享 → 導航到 share route 且只執行一次', (tester) async {
      await pumpList(tester);

      await tester.tap(find.byKey(moreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('分享'));
      await tester.tap(find.text('分享'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('share:okinawa-trip-2026'), findsOneWidget);
    });

    testWidgets('匯出進行中再開選單：匯出 JSON 暫不提供，其餘動作沿用', (tester) async {
      await _useWideSurface(tester);
      final mockTripRepository = MockTripRepository();
      final exportCompleter = Completer<TripJsonExport>();
      final writer = _FakeTripExportFileWriter();
      when(
        () => mockTripRepository.watchMyTrips(),
      ).thenAnswer((_) => Stream.value(fakeTrips));
      when(
        () => mockTripRepository.exportTripJson(any()),
      ).thenAnswer((_) => exportCompleter.future);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(mockTripRepository),
            tripExportFileWriterProvider.overrideWithValue(writer),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(moreKey));
      await tester.pumpAndSettle();
      await tester.tap(menuText('trip-menu-export-okinawa-trip-2026'));
      await tester.pumpAndSettle();

      // 匯出尚未完成：同一張與另一張卡的選單都不再提供匯出，快捷動作照舊。
      for (final tripId in ['okinawa-trip-2026', 'busan-trip-2024']) {
        await tester.tap(find.byKey(ValueKey('trip-card-more-$tripId')));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('trip-menu-export-$tripId')), findsNothing);
        for (final action in ['share', 'collab', 'health', 'delete']) {
          expect(
            find.byKey(ValueKey('trip-menu-$action-$tripId')),
            findsOneWidget,
            reason: '$tripId $action',
          );
        }
        await tester.tapAt(const Offset(20, 1500));
        await tester.pumpAndSettle();
      }

      exportCompleter.complete(
        const TripJsonExport(fileName: 'okinawa.json', content: '{}'),
      );
      await tester.pumpAndSettle();
      expect(find.text('匯出成功'), findsOneWidget);
      await tester.tap(find.byKey(moreKey));
      await tester.pumpAndSettle();
      expect(menuText('trip-menu-export-okinawa-trip-2026'), findsOneWidget);
      verify(
        () => mockTripRepository.exportTripJson('okinawa-trip-2026'),
      ).called(1);
    });

    testWidgets('點選單外面關閉且不觸發背景卡片導航', (tester) async {
      await pumpList(tester);

      await tester.tap(find.byKey(moreKey));
      await tester.pumpAndSettle();
      expect(find.text('分享'), findsOneWidget);
      await tester.tapAt(const Offset(20, 1500));
      await tester.pumpAndSettle();
      expect(find.text('分享'), findsNothing);
      expect(find.text('detail:okinawa-trip-2026'), findsNothing);
      expect(find.byType(TripCard), findsNWidgets(3));
    });
  });

  group('TripsListScreen 互動', () {
    testWidgets('點卡片 → 導航到 /trips/:tripId', (tester) async {
      await _useWideSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('沖繩家族之旅'));
      await tester.pumpAndSettle();

      expect(find.text('detail:okinawa-trip-2026'), findsOneWidget);
    });

    testWidgets('AppBar 匯入 JSON → 呼叫 importTripJson 並導向新行程', (tester) async {
      await _useWideSurface(tester);
      final mockTripRepository = MockTripRepository();
      when(
        () => mockTripRepository.watchMyTrips(),
      ).thenAnswer((_) => Stream.value(fakeTrips));
      when(
        () => mockTripRepository.importTripJson(any()),
      ).thenAnswer((_) async => 'imported-trip');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(mockTripRepository),
            tripImportFilePickerProvider.overrideWithValue(
              const _FakeTripImportFilePicker(
                TripImportFile(
                  name: 'trip.json',
                  length: 31,
                  content: '{"schemaVersion":1,"meta":{}}',
                ),
              ),
            ),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('trips-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trips-list-import-trigger')));
      await tester.pumpAndSettle();

      verify(
        () =>
            mockTripRepository.importTripJson('{"schemaVersion":1,"meta":{}}'),
      ).called(1);
      expect(find.text('detail:imported-trip'), findsOneWidget);
    });

    testWidgets('長按 → 匯出 JSON → 寫入 export 檔名與內容', (tester) async {
      await _useWideSurface(tester);
      final mockTripRepository = MockTripRepository();
      final writer = _FakeTripExportFileWriter();
      when(
        () => mockTripRepository.watchMyTrips(),
      ).thenAnswer((_) => Stream.value(fakeTrips));
      when(() => mockTripRepository.exportTripJson(any())).thenAnswer(
        (_) async => const TripJsonExport(
          fileName: 'okinawa.json',
          content: '{"schemaVersion":1}',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(mockTripRepository),
            tripExportFileWriterProvider.overrideWithValue(writer),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('沖繩家族之旅'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('匯出 JSON'));
      await tester.pumpAndSettle();

      verify(
        () => mockTripRepository.exportTripJson('okinawa-trip-2026'),
      ).called(1);
      expect(writer.suggestedName, 'okinawa.json');
      expect(writer.content, '{"schemaVersion":1}');
      expect(find.text('匯出成功'), findsOneWidget);
    });

    testWidgets('長按 → AI 健檢 → 導航到 health route', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('沖繩家族之旅'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI 健檢'));
      await tester.pumpAndSettle();

      expect(find.text('health:okinawa-trip-2026'), findsOneWidget);
    });

    testWidgets('左滑行程卡 → AlertDialog 確認 → 呼叫 deleteTrip', (tester) async {
      await _useWideSurface(tester);
      final mockTripRepository = MockTripRepository();
      when(
        () => mockTripRepository.watchMyTrips(),
      ).thenAnswer((_) => Stream.value(fakeTrips));
      when(() => mockTripRepository.deleteTrip(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(mockTripRepository),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('trip-dismiss-okinawa-trip-2026')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<Object>((
            'swipe-delete-action',
            ValueKey('trip-dismiss-okinawa-trip-2026'),
          )),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pumpAndSettle();

      verify(
        () => mockTripRepository.deleteTrip('okinawa-trip-2026'),
      ).called(1);
    });

    testWidgets('長按 → 選單 → AlertDialog 確認 → 呼叫 deleteTrip 並 refresh', (
      tester,
    ) async {
      await _useWideSurface(tester);
      final mockTripRepository = MockTripRepository();
      when(
        () => mockTripRepository.watchMyTrips(),
      ).thenAnswer((_) => Stream.value(fakeTrips));
      when(() => mockTripRepository.deleteTrip(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(mockTripRepository),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();
      expect(find.byType(TripCard), findsNWidgets(3));

      // 長按第一張卡 → 錨定選單
      await tester.longPress(find.text('沖繩家族之旅'));
      await tester.pumpAndSettle();
      expect(find.text('刪除行程'), findsOneWidget);

      // 點「刪除行程」→ AlertDialog 確認
      await tester.tap(find.text('刪除行程'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);

      // 確認刪除 → 呼叫 repository.deleteTrip + 清單 refresh
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();

      verify(
        () => mockTripRepository.deleteTrip('okinawa-trip-2026'),
      ).called(1);
      // 初載 + 刪除後 invalidate refresh = 2 次
      verify(() => mockTripRepository.watchMyTrips()).called(2);
    });

    testWidgets('刪除確認說明影響與不可復原，送出後鎖定卡片直到伺服器成功', (tester) async {
      await _useWideSurface(tester);
      final deleteCompleter = Completer<void>();
      final mockTripRepository = MockTripRepository();
      when(
        () => mockTripRepository.watchMyTrips(),
      ).thenAnswer((_) => Stream.value(fakeTrips));
      when(
        () => mockTripRepository.deleteTrip('okinawa-trip-2026'),
      ).thenAnswer((_) => deleteCompleter.future);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(mockTripRepository),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('沖繩家族之旅'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除行程'));
      await tester.pumpAndSettle();

      expect(
        find.text('確定要刪除「沖繩家族之旅」嗎？這會刪除其中所有行程日與景點。此動作無法復原。'),
        findsOneWidget,
      );

      await tester.tap(find.text('刪除'));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('trip-delete-progress-okinawa-trip-2026')),
        findsOneWidget,
      );
      expect(find.text('沖繩家族之旅'), findsOneWidget);
      final deletingCard = tester.widget<TripCard>(
        find.ancestor(of: find.text('沖繩家族之旅'), matching: find.byType(TripCard)),
      );
      expect(deletingCard.onTap, isNull);
      expect(deletingCard.onLongPress, isNull);
      expect(deletingCard.moreMenu, isNull);

      deleteCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.text('沖繩家族之旅'), findsNothing);
      verify(
        () => mockTripRepository.deleteTrip('okinawa-trip-2026'),
      ).called(1);
    });

    testWidgets('刪除行程失敗保留卡片並顯示可重試的持續錯誤', (tester) async {
      await _useWideSurface(tester);
      final mockTripRepository = MockTripRepository();
      when(
        () => mockTripRepository.watchMyTrips(),
      ).thenAnswer((_) => Stream.value(fakeTrips));
      when(
        () => mockTripRepository.deleteTrip('okinawa-trip-2026'),
      ).thenThrow(Exception('offline'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(mockTripRepository),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('沖繩家族之旅'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除行程'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();

      expect(find.text('沖繩家族之旅'), findsOneWidget);
      expect(find.byKey(const ValueKey('app-error-banner')), findsOneWidget);
      expect(find.text('刪除「沖繩家族之旅」失敗，請稍後再試'), findsOneWidget);

      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      verify(
        () => mockTripRepository.deleteTrip('okinawa-trip-2026'),
      ).called(2);
    });

    testWidgets('刪除確認對話框按「取消」→ 不呼叫 deleteTrip', (tester) async {
      await _useWideSurface(tester);
      final mockTripRepository = MockTripRepository();
      when(
        () => mockTripRepository.watchMyTrips(),
      ).thenAnswer((_) => Stream.value(fakeTrips));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(mockTripRepository),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('沖繩家族之旅'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除行程'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsNothing);
      verifyNever(() => mockTripRepository.deleteTrip(any()));
    });
  });

  group('TripsListScreen 建立者標示串接', () {
    const ownedAndShared = [
      TripSummary(
        tripId: 'mine',
        name: 'mine',
        title: '我的行程',
        totalDays: 3,
        ownerUserId: 'me',
        ownerDisplayName: 'Me Owner',
      ),
      TripSummary(
        tripId: 'shared',
        name: 'shared',
        title: '共編行程',
        totalDays: 2,
        ownerUserId: 'someone-else',
        ownerDisplayName: 'Amy Wang',
      ),
    ];

    testWidgets('card 收到 authState 的 currentUserId → 自己的卡顯示「由你建立」', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(ownedAndShared)),
            authStateProvider.overrideWith(
              () => _FakeAuthNotifier(_userWithId('me')),
            ),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pumpAndSettle();

      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.map((c) => c.currentUserId).toSet(), {'me'});
      expect(find.text('由你建立'), findsOneWidget);
      expect(find.text('Amy Wang'), findsOneWidget);
    });
  });

  group('TripsListScreen 篩選分頁（全部 / 我的 / 共編）', () {
    const mixedTrips = [
      TripSummary(
        tripId: 'mine-1',
        name: 'mine-1',
        title: '我的沖繩',
        ownerUserId: 'me',
      ),
      TripSummary(
        tripId: 'shared-1',
        name: 'shared-1',
        title: '共編京都',
        ownerUserId: 'other',
      ),
      TripSummary(
        tripId: 'mine-2',
        name: 'mine-2',
        title: '我的釜山',
        ownerUserId: 'me',
      ),
    ];

    Future<void> pumpMixed(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(mixedTrips)),
            authStateProvider.overrideWith(
              () => _FakeAuthNotifier(_userWithId('me')),
            ),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('預設「全部」顯示所有行程', (tester) async {
      await _useWideSurface(tester);
      await pumpMixed(tester);
      expect(find.byType(TripCard), findsNWidgets(3));
    });

    testWidgets('切「我的」→ 只剩 ownerUserId == 當前 user', (tester) async {
      await _useWideSurface(tester);
      await pumpMixed(tester);

      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();

      expect(find.byType(TripCard), findsNWidgets(2));
      expect(find.text('我的沖繩'), findsOneWidget);
      expect(find.text('我的釜山'), findsOneWidget);
      expect(find.text('共編京都'), findsNothing);
    });

    testWidgets('切「共編」→ 只剩 ownerUserId != 當前 user', (tester) async {
      await _useWideSurface(tester);
      await pumpMixed(tester);

      await tester.tap(find.text('共編'));
      await tester.pumpAndSettle();

      expect(find.byType(TripCard), findsOneWidget);
      expect(find.text('共編京都'), findsOneWidget);
    });

    testWidgets('篩選 + 搜尋並存：filter → search', (tester) async {
      await _useWideSurface(tester);
      await pumpMixed(tester);

      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      expect(find.byType(TripCard), findsNWidgets(2));

      await tester.enterText(
        find.byKey(const ValueKey('trips-search-field')),
        '沖繩',
      );
      await tester.pumpAndSettle();

      expect(find.byType(TripCard), findsOneWidget);
      expect(find.text('我的沖繩'), findsOneWidget);
    });
  });

  group('TripsListScreen 擴充排序（最新編輯 / 出發日）', () {
    const datedTrips = [
      TripSummary(
        tripId: 'a',
        name: 'a',
        title: 'A 行程',
        startDate: '2026-05-10',
        updatedAt: '2026-01-01T00:00:00Z',
      ),
      TripSummary(
        tripId: 'b',
        name: 'b',
        title: 'B 行程',
        startDate: '2026-03-01',
        updatedAt: '2026-03-15T00:00:00Z',
      ),
      TripSummary(
        tripId: 'c',
        name: 'c',
        title: 'C 行程',
        startDate: '2026-04-20',
        updatedAt: '2026-02-01T00:00:00Z',
      ),
    ];

    Future<void> pumpDated(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(datedTrips)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();
    }

    testWidgets('選「最新編輯」→ updatedAt 由新到舊', (tester) async {
      await _useWideSurface(tester);
      await pumpDated(tester);

      await tester.tap(find.byKey(const ValueKey('trips-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('最新編輯'));
      await tester.pumpAndSettle();

      // updatedAt: b(03-15) > c(02-01) > a(01-01)
      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.map((c) => c.trip.tripId).toList(), ['b', 'c', 'a']);
    });

    testWidgets('選「出發日」→ startDate 由近到遠', (tester) async {
      await _useWideSurface(tester);
      await pumpDated(tester);

      await tester.tap(find.byKey(const ValueKey('trips-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('出發日'));
      await tester.pumpAndSettle();

      // startDate: b(03-01) < c(04-20) < a(05-10)
      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.map((c) => c.trip.tripId).toList(), ['b', 'c', 'a']);
    });

    testWidgets('缺 startDate 的行程排到最後（出發日排序）', (tester) async {
      await _useWideSurface(tester);
      const withMissing = [
        TripSummary(
          tripId: 'x',
          name: 'x',
          title: 'X',
          startDate: '2026-06-01',
        ),
        TripSummary(tripId: 'y', name: 'y', title: 'Y'),
        TripSummary(
          tripId: 'z',
          name: 'z',
          title: 'Z',
          startDate: '2026-02-01',
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(withMissing)),
          ],
          child: buildRouterApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('trips-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('出發日'));
      await tester.pumpAndSettle();

      // z(02-01) < x(06-01) < y(null → 最後)
      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.map((c) => c.trip.tripId).toList(), ['z', 'x', 'y']);
    });
  });
}
