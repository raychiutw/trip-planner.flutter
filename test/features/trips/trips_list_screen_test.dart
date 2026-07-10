import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trips/trip_card.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

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

/// large title(SliverAppBar.large)+ 搜尋/篩選 header 會吃掉垂直空間;預設 600px
/// 測試視窗下 SliverList 懶載入只建部分卡片。放大視窗讓短清單一次全建,穩定斷言卡片數。
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
  Widget buildRouterApp() {
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
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: fakeRouter,
    );
  }

  group('TripsListScreen 清單渲染', () {
    testWidgets('渲染 N 張卡：標題、eyebrow、tone 輪替', (tester) async {
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

      // SliverAppBar.large 標題會雙渲染(展開 + 收合),故用 findsWidgets。
      expect(find.text('我的行程'), findsWidgets);
      expect(find.byType(TripCard), findsNWidgets(3));

      // title 優先顯示，無 title 退回 name
      expect(find.text('沖繩家族之旅'), findsOneWidget);
      expect(find.text('kyoto-trip-2025'), findsOneWidget);
      expect(find.text('釜山美食團'), findsOneWidget);

      // eyebrow：totalDays 天；null 則不顯示
      expect(find.text('5 天'), findsOneWidget);
      expect(find.text('4 天'), findsOneWidget);

      // tone 依 index 輪替 accent → sage → pink
      final renderedCards = tester
          .widgetList<TripCard>(find.byType(TripCard))
          .toList();
      expect(renderedCards.map((card) => card.tone).toList(), [
        TripCardTone.accent,
        TripCardTone.sage,
        TripCardTone.pink,
      ]);
    });

    testWidgets('empty state：顯示「還沒有行程」hero 文案', (tester) async {
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
      expect(find.text('還沒有行程'), findsOneWidget);
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

      await tester.tap(find.text('重試'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(TripCard), findsNWidgets(3));
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

    testWidgets('filtered 後 tone 輪替依新 index 計算', (tester) async {
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

      // 搜尋「busan」→ 只剩第三張（原 index=2），但 filtered index=0 → accent tone
      await tester.enterText(
        find.byKey(const ValueKey('trips-search-field')),
        'busan',
      );
      await tester.pump();

      final cards = tester.widgetList<TripCard>(find.byType(TripCard)).toList();
      expect(cards.length, 1);
      expect(
        cards.first.tone,
        TripCardTone.accent,
      ); // filtered index 0 → accent
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

    testWidgets('nameAsc 排序後 tone 輪替依最終 index 計算', (tester) async {
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
      // 排序後 index 0,1,2 → accent, sage, pink
      expect(cards[0].tone, TripCardTone.accent);
      expect(cards[1].tone, TripCardTone.sage);
      expect(cards[2].tone, TripCardTone.pink);
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

    testWidgets(
      '長按 → bottom sheet → AlertDialog 確認 → 呼叫 deleteTrip 並 refresh',
      (tester) async {
        await _useWideSurface(tester);
        final mockTripRepository = MockTripRepository();
        when(
          () => mockTripRepository.watchMyTrips(),
        ).thenAnswer((_) => Stream.value(fakeTrips));
        when(
          () => mockTripRepository.deleteTrip(any()),
        ).thenAnswer((_) async {});

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

        // 長按第一張卡 → bottom sheet
        await tester.longPress(find.text('沖繩家族之旅'));
        await tester.pumpAndSettle();
        expect(find.text('刪除行程'), findsOneWidget);

        // 點「刪除行程」→ AlertDialog 確認
        await tester.tap(find.text('刪除行程'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);

        // 確認刪除 → 呼叫 repository.deleteTrip + 清單 refresh
        await tester.tap(find.text('刪除'));
        await tester.pumpAndSettle();

        verify(
          () => mockTripRepository.deleteTrip('okinawa-trip-2026'),
        ).called(1);
        // 初載 + 刪除後 invalidate refresh = 2 次
        verify(() => mockTripRepository.watchMyTrips()).called(2);
      },
    );

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

      expect(find.byType(AlertDialog), findsNothing);
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
