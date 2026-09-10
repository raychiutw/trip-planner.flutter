import 'dart:ui' show PointerDeviceKind, Tristate;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/features/shell/app_shell.dart';
import 'package:tripline/features/trips/current_trip_provider.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_glass_surface.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';

GoRouter buildShellRouter() {
  StatefulShellBranch probe(String path, String marker) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => Text(marker))],
  );
  return GoRouter(
    initialLocation: '/chat',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          probe('/chat', 'PROBE-CHAT'),
          probe('/trips', 'PROBE-TRIPS'),
          probe('/map', 'PROBE-MAP'),
          probe('/favorites', 'PROBE-FAV'),
        ],
      ),
    ],
  );
}

GoRouter buildScrollableShellRouter() {
  StatefulShellBranch probe(String path, Widget child) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => child)],
  );
  return GoRouter(
    initialLocation: '/chat',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          probe(
            '/chat',
            ListView.builder(
              key: const ValueKey('root-vertical-list'),
              itemCount: 60,
              itemBuilder: (_, index) =>
                  SizedBox(height: 56, child: Text('ROW-$index')),
            ),
          ),
          probe('/trips', const Text('PROBE-TRIPS')),
          probe('/map', const Text('PROBE-MAP')),
          probe('/favorites', const Text('PROBE-FAV')),
        ],
      ),
    ],
  );
}

GoRouter buildReselectShellRouter() {
  StatefulShellBranch probe(String path, Widget child) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => child)],
  );
  return GoRouter(
    initialLocation: '/chat',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          probe('/chat', const _ReselectRootProbe()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trips',
                builder: (_, _) => const Text('TRIPS-ROOT'),
                routes: [
                  GoRoute(
                    path: 'detail',
                    builder: (_, _) => const Text('TRIPS-DETAIL'),
                  ),
                ],
              ),
            ],
          ),
          probe('/map', const Text('PROBE-MAP')),
          probe('/favorites', const Text('PROBE-FAV')),
        ],
      ),
    ],
  );
}

GoRouter buildStateShellRouter() {
  StatefulShellBranch probe(String path, Widget child) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => child)],
  );
  return GoRouter(
    initialLocation: '/chat',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          probe(
            '/chat',
            const CircularProgressIndicator.adaptive(
              key: ValueKey('loading-state'),
            ),
          ),
          probe('/trips', const Text('EMPTY-STATE')),
          probe('/map', const Text('OFFLINE-STATE')),
          probe('/favorites', const Text('ERROR-STATE')),
        ],
      ),
    ],
  );
}

GoRouter buildSplitShellRouter() {
  StatefulShellBranch probe(String path, String marker) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => Text(marker))],
  );
  return GoRouter(
    initialLocation: '/trips/trip-1',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          probe('/chat', 'PROBE-CHAT'),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trips',
                builder: (_, _) => const Text('TRIPS-ROOT'),
                routes: [
                  GoRoute(
                    path: ':tripId',
                    builder: (_, state) => AdaptiveTripDetail(
                      selectedTripId: state.pathParameters['tripId']!,
                      child: const _AdaptiveDetailStateProbe(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          probe('/map', 'PROBE-MAP'),
          probe('/favorites', 'PROBE-FAV'),
        ],
      ),
    ],
  );
}

/// 中性表面的公開設定；HIG 矩陣另驗實際繪製與操作。
Color _selectedPillColor(WidgetTester tester, String label) => tester
    .widget<GlassTabBar>(
      find.descendant(
        of: find.byKey(const ValueKey('apple-root-tab-bar')),
        matching: find.byType(GlassTabBar),
      ),
    )
    .indicatorColor!;

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    for (final highContrast in [true, false]) {
      testWidgets('地圖不透明降級時未選取 tabs 仍清楚可讀 $size highContrast=$highContrast', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final router = buildShellRouter();
        addTearDown(router.dispose);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          AppAccessibilityScope(
            reduceTransparency: !highContrast,
            child: ProviderScope(
              child: MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(highContrast: highContrast),
                  child: RepaintBoundary(key: boundaryKey, child: child!),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getCenter(find.bySemanticsLabel('地圖')));
        await tester.pumpAndSettle();
        expect(find.text('PROBE-MAP'), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel('地圖')),
          matchesSemantics(
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            label: '地圖',
            hasTapAction: true,
          ),
        );
        final selectedLabels = tester.widgetList<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('apple-root-tab-bar')),
            matching: find.text('地圖'),
          ),
        );
        expect(
          selectedLabels.map((label) => label.style?.color),
          contains(AppTheme.light().colorScheme.primary),
        );
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = (await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1),
        ))!;
        final data = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        Color pixel(Offset point) {
          final local = boundary.globalToLocal(point);
          final offset =
              (local.dy.floor() * image.width + local.dx.floor()) * 4;
          return Color.fromARGB(
            data.getUint8(offset + 3),
            data.getUint8(offset),
            data.getUint8(offset + 1),
            data.getUint8(offset + 2),
          );
        }

        for (final label in ['聊天', '行程', '收藏']) {
          final text = find.descendant(
            of: find.byKey(const ValueKey('apple-root-tab-bar')),
            matching: find.text(label),
          );
          expect(text, findsWidgets);
          // 套件可重複繪製標籤層；驗最終畫面墨跡，不依賴層數。
          final rect = tester.getRect(text.first);
          final background = pixel(Offset(rect.center.dx, rect.top - 2));
          var strongestContrast = 1.0;
          for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
            for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
              final luminance = pixel(
                Offset(x.toDouble(), y.toDouble()),
              ).computeLuminance();
              final backdrop = background.computeLuminance();
              final ratio = luminance > backdrop
                  ? (luminance + 0.05) / (backdrop + 0.05)
                  : (backdrop + 0.05) / (luminance + 0.05);
              if (ratio > strongestContrast) strongestContrast = ratio;
            }
          }
          expect(
            strongestContrast,
            greaterThanOrEqualTo(4.5),
            reason: '$label 的實際墨跡必須與不透明背景有足夠對比',
          );
        }
        image.dispose();
        await tester.tapAt(tester.getCenter(find.bySemanticsLabel('聊天')));
        await tester.pumpAndSettle();
        expect(find.text('PROBE-CHAT'), findsOneWidget);
      });
    }
  }
  group('AppShell 4-tab 導航', () {
    testWidgets('iOS／Android 尺寸矩陣依可用寬度選擇導覽', (tester) async {
      final cases = [
        (
          name: 'iPhone 直向',
          size: const Size(390, 844),
          platform: TargetPlatform.iOS,
          regular: false,
        ),
        (
          name: 'iPhone 橫向',
          size: const Size(844, 390),
          platform: TargetPlatform.iOS,
          regular: true,
        ),
        (
          name: 'iPad',
          size: const Size(1024, 768),
          platform: TargetPlatform.iOS,
          regular: true,
        ),
        (
          name: 'iPad Split View',
          size: const Size(600, 820),
          platform: TargetPlatform.iOS,
          regular: false,
        ),
        (
          name: 'Android 手機',
          size: const Size(412, 915),
          platform: TargetPlatform.android,
          regular: false,
        ),
        (
          name: 'Android 平板',
          size: const Size(1280, 800),
          platform: TargetPlatform.android,
          regular: true,
        ),
      ];
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final testCase in cases) {
        tester.view.physicalSize = testCase.size;
        final router = buildShellRouter();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(
              theme: AppTheme.light().copyWith(platform: testCase.platform),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('apple-regular-root-tabs')),
          testCase.regular ? findsOneWidget : findsNothing,
          reason: testCase.name,
        );
        expect(
          find.byType(NavigationRail),
          findsNothing,
          reason: testCase.name,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    });

    testWidgets('依可用寬度切換 compact bottom tabs 與 regular top tabs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = buildShellRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('apple-root-tab-bar')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('apple-regular-root-tabs')),
        findsNothing,
      );

      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('apple-regular-root-tabs')),
        findsOneWidget,
      );
      expect(find.byType(NavigationRail), findsNothing);
      for (final label in ['聊天', '行程', '地圖', '收藏']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
    });

    testWidgets('regular top tabs 支援外接鍵盤焦點與啟用', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = buildShellRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(
        tester.getCenter(find.bySemanticsLabel('地圖')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(find.text('PROBE-MAP'), findsOneWidget);

      // 使用真實 Tab 導覽；不取套件或 App 的 FocusNode。
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('PROBE-FAV'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('PROBE-MAP'), findsOneWidget);
    });

    testWidgets('regular top tabs 避開頂部 safe area', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final router = buildShellRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = find.byKey(const ValueKey('apple-root-tab-bar'));
      expect(tester.getTopLeft(bar).dy, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact／regular resize 保留 branch 與未送出內容', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = buildReselectShellRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('root-draft-field')),
        '跨尺寸保留',
      );

      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpAndSettle();
      expect(find.text('跨尺寸保留'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('apple-regular-root-tabs')),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('地圖'));
      await tester.pumpAndSettle();
      expect(find.text('PROBE-MAP'), findsOneWidget);

      tester.view.physicalSize = const Size(600, 820);
      await tester.pumpAndSettle();
      expect(find.text('PROBE-MAP'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('apple-regular-root-tabs')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('apple-root-tab-bar')), findsOneWidget);
    });

    testWidgets('regular width 行程 detail 使用保留選取的 split view', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = buildSplitShellRouter();
      addTearDown(router.dispose);
      final trips = [
        TripSummary(tripId: 'trip-1', name: 'okinawa', title: '沖繩旅行'),
        TripSummary(tripId: 'trip-2', name: 'tokyo', title: '東京旅行'),
        for (var index = 3; index <= 24; index++)
          TripSummary(
            tripId: 'trip-$index',
            name: 'trip-$index',
            title: '行程 $index',
          ),
      ];
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTripsProvider.overrideWith((ref) => Stream.value(trips)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('trip-regular-split-view')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('trip-detail-probe')), findsOneWidget);
      final selected = tester.getSemantics(
        find.byKey(const ValueKey('trip-sidebar-item-trip-1')),
      );
      expect(
        selected.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('trip-sidebar-item-trip-2')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/trips/trip-2');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdaptiveTripDetail)),
      );
      expect(container.read(currentTripIdProvider).value, 'trip-2');
      final sidebarList = find.byKey(
        const PageStorageKey('trip-regular-sidebar-list'),
      );
      await tester.drag(sidebarList, const Offset(0, -300));
      await tester.pump();
      final sidebarScrollBeforeResize = tester
          .state<ScrollableState>(
            find
                .descendant(of: sidebarList, matching: find.byType(Scrollable))
                .first,
          )
          .position
          .pixels;
      expect(sidebarScrollBeforeResize, greaterThan(0));
      await tester.enterText(
        find.byKey(const ValueKey('trip-detail-draft')),
        '保留 detail 狀態',
      );
      await tester.tap(find.byKey(const ValueKey('trip-detail-next-day')));
      await tester.drag(
        find.byKey(const ValueKey('trip-detail-scroll')),
        const Offset(0, -300),
      );
      await tester.pump();
      final scrollBeforeResize = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('trip-detail-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      expect(scrollBeforeResize, greaterThan(0));

      tester.view.physicalSize = const Size(600, 820);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('trip-regular-split-view')),
        findsNothing,
      );
      expect(router.state.uri.path, '/trips/trip-2');
      expect(find.text('保留 detail 狀態'), findsOneWidget);
      expect(find.text('DAY 2'), findsOneWidget);
      final scrollAfterResize = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('trip-detail-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      expect(scrollAfterResize, closeTo(scrollBeforeResize, 0.1));

      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpAndSettle();
      final restoredSidebarScrollable = tester.state<ScrollableState>(
        find
            .descendant(of: sidebarList, matching: find.byType(Scrollable))
            .first,
      );
      expect(
        restoredSidebarScrollable.position.pixels,
        closeTo(sidebarScrollBeforeResize, 0.1),
      );
      restoredSidebarScrollable.position.jumpTo(0);
      await tester.pump();
      final restoredSelected = tester.getSemantics(
        find.byKey(const ValueKey('trip-sidebar-item-trip-2')),
      );
      expect(
        restoredSelected.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(container.read(currentTripIdProvider).value, 'trip-2');
      semantics.dispose();
    });

    testWidgets('resize 保留深層 branch stack，系統返回仍回上一層', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = buildReselectShellRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      router.go('/trips/detail');
      await tester.pumpAndSettle();
      expect(find.text('TRIPS-DETAIL'), findsOneWidget);

      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/trips/detail');
      expect(find.text('TRIPS-DETAIL'), findsOneWidget);

      tester.view.physicalSize = const Size(600, 820);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/trips');
      expect(find.text('TRIPS-ROOT'), findsOneWidget);
    });

    testWidgets('4 個 tab,點擊切換到對應 branch', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: buildShellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 初始 branch 0
      expect(find.text('PROBE-CHAT'), findsOneWidget);
      expect(find.byKey(const ValueKey('apple-root-tab-bar')), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // 點「地圖」→ branch 2
      await tester.tap(find.bySemanticsLabel('地圖'));
      await tester.pumpAndSettle();
      expect(find.text('PROBE-MAP'), findsOneWidget);
      expect(find.text('PROBE-CHAT'), findsNothing);

      // 點「收藏」→ branch 3
      await tester.tap(find.bySemanticsLabel('收藏'));
      await tester.pumpAndSettle();
      expect(find.text('PROBE-FAV'), findsOneWidget);
      expect(find.bySemanticsLabel('帳號'), findsNothing);
    });

    testWidgets('地圖 branch 跟隨深色主題並使用深色 Liquid Glass', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            routerConfig: buildShellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('地圖'));
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.text('PROBE-MAP'))).brightness,
        Brightness.dark,
      );
      final bar = find.byKey(const ValueKey('apple-root-tab-bar'));
      final glass = tester.widget<GlassTabBar>(
        find.descendant(of: bar, matching: find.byType(GlassTabBar)),
      );
      expect(glass.platformViewBackdrop, isTrue);
      expect(
        _selectedPillColor(tester, '地圖'),
        AppTheme.dark().colorScheme.surfaceContainerHigh,
      );
      expect(glass.selectedIconColor, AppTheme.dark().colorScheme.primary);
    });

    testWidgets('root branches keep content visible through Liquid Glass', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: buildShellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      GlassTabBar rootBar() => tester.widget<GlassTabBar>(
        find.descendant(
          of: find.byKey(const ValueKey('apple-root-tab-bar')),
          matching: find.byType(GlassTabBar),
        ),
      );

      final standard = rootBar();
      expect(standard.platformViewBackdrop, isFalse);
      expect(standard.settings?.glassColor.a, lessThan(1));
      expect(standard.settings?.backerColor, isNull);

      await tester.tap(find.bySemanticsLabel('地圖'));
      await tester.pumpAndSettle();

      final map = rootBar();
      expect(map.platformViewBackdrop, isTrue);
      final chatGlyphs = tester.widgetList<RichText>(
        find.descendant(
          of: find.descendant(
            of: find.byKey(const ValueKey('apple-root-tab-bar')),
            matching: find.byIcon(CupertinoIcons.chat_bubble_fill),
          ),
          matching: find.byType(RichText),
        ),
      );
      expect(
        chatGlyphs.map((glyph) => glyph.text.style?.color),
        contains(Colors.white),
      );
      expect(map.settings?.glassColor.a, closeTo(tpMediaScrimOpacity, 0.01));
      // 媒體暗化與原生 PlatformView 相容路徑保留，其餘採相同新版材質。
      expect(map.settings?.blur, standard.settings?.blur);
      expect(
        map.settings?.chromaticAberration,
        standard.settings?.chromaticAberration,
      );
      expect(map.settings?.refractiveIndex, standard.settings?.refractiveIndex);
      expect(map.indicatorSettings?.blur, map.settings?.blur);
      expect(
        map.indicatorSettings?.refractiveIndex,
        map.settings?.refractiveIndex,
      );
      expect(
        _selectedPillColor(tester, '地圖'),
        AppTheme.light().colorScheme.surfaceContainerHigh,
      );
    });

    testWidgets('Reduce Transparency 使用不透明且無模糊的 root tab 選取底色', (tester) async {
      await tester.pumpWidget(
        AppAccessibilityScope(
          reduceTransparency: true,
          child: ProviderScope(
            child: MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: buildShellRouter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final glass = tester.widget<GlassTabBar>(
        find.descendant(
          of: find.byKey(const ValueKey('apple-root-tab-bar')),
          matching: find.byType(GlassTabBar),
        ),
      );
      expect(glass.indicatorSettings?.blur, 0);
      expect(glass.indicatorSettings?.glassColor.a, 1);
      expect(_selectedPillColor(tester, '聊天').a, 1);
    });

    testWidgets('root tab 是浮動 Liquid Glass 功能層', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: buildShellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = find.byKey(const ValueKey('apple-root-tab-bar'));
      expect(bar, findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.byType(GlassTabBar)),
        findsOneWidget,
      );
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isTrue);
    });

    // tab bar 尺寸與 label 不隨捲動改變：Apple 的 minimize 語意綁定「tab bar 底下
    // 是可捲動內容」,本 app 多數 root 畫面底下是固定版面,縮放只會讓導覽跳動。
    testWidgets('捲動不改變 root tab 尺寸與 label', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: buildScrollableShellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = find.byKey(const ValueKey('apple-root-tab-bar'));
      final restingSize = tester.getSize(bar);
      expect(find.bySemanticsLabel('聊天'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('root-vertical-list')),
        const Offset(0, -320),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(bar), restingSize);
      expect(find.bySemanticsLabel('聊天'), findsOneWidget);
      expect(find.bySemanticsLabel('收藏'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('root-vertical-list')),
        const Offset(0, 220),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(bar), restingSize);
      expect(find.bySemanticsLabel('聊天'), findsOneWidget);
    });

    testWidgets('重點 detail tab 回 root；重點 root 回頂端且保留輸入', (tester) async {
      final router = buildReselectShellRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('root-draft-field')),
        '保留的草稿',
      );
      await tester.tap(find.bySemanticsLabel('地圖'));
      await tester.pumpAndSettle();
      expect(find.text('PROBE-MAP'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('聊天'));
      await tester.pumpAndSettle();
      expect(find.text('保留的草稿'), findsOneWidget);

      await tester.fling(
        find.byKey(const ValueKey('tp-root-scroll-view')),
        const Offset(0, -600),
        1200,
      );
      await tester.pumpAndSettle();
      ScrollableState scrollable() => tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('tp-root-scroll-view')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scrollable().position.pixels, greaterThan(0));

      await tester.tapAt(tester.getCenter(find.bySemanticsLabel('聊天')));
      await tester.pumpAndSettle();

      expect(find.text('保留的草稿'), findsOneWidget);
      expect(scrollable().position.pixels, 0);

      router.go('/trips/detail');
      await tester.pumpAndSettle();
      expect(find.text('TRIPS-DETAIL'), findsOneWidget);

      await tester.tapAt(tester.getCenter(find.bySemanticsLabel('行程')));
      await tester.pumpAndSettle();
      expect(find.text('TRIPS-ROOT'), findsOneWidget);
    });

    testWidgets('鍵盤顯示時隱藏 root tab bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: buildShellRouter(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('apple-root-tab-bar')), findsNothing);
    });

    testWidgets('載入、空白、離線與錯誤狀態都保留四個可用 tabs', (tester) async {
      final router = buildStateShellRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('loading-state')), findsOneWidget);
      for (final target in [
        ('行程', 'EMPTY-STATE'),
        ('地圖', 'OFFLINE-STATE'),
        ('收藏', 'ERROR-STATE'),
      ]) {
        await tester.tap(find.bySemanticsLabel(target.$1));
        await tester.pumpAndSettle();
        expect(find.text(target.$2), findsOneWidget);
        expect(
          find.byKey(const ValueKey('apple-root-tab-bar')),
          findsOneWidget,
        );
        for (final label in ['聊天', '行程', '地圖', '收藏']) {
          expect(find.bySemanticsLabel(label), findsOneWidget);
        }
      }
    });

    testWidgets('四個 tab 都有 label、系統圖示且目前 tab 具 selected semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: buildShellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['聊天', '行程', '地圖', '收藏']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      expect(find.bySemanticsLabel('帳號'), findsNothing);
      final bar = find.byKey(const ValueKey('apple-root-tab-bar'));
      // 兩態同字符後，選取層與底層會各渲染一次；精確的字符契約由
      //「root tab bar 選取態是中性膠囊加品牌 tint 前景」那支負責。
      expect(
        find.descendant(
          of: bar,
          matching: find.byIcon(CupertinoIcons.briefcase_fill),
        ),
        findsWidgets,
      );
      final selected = tester.getSemantics(find.bySemanticsLabel('聊天'));
      expect(
        selected.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      semantics.dispose();
    });

    testWidgets('320pt 與 200% 文字下四個單字 label 完整可讀', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: buildShellRouter(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['聊天', '行程', '地圖', '收藏']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('root tab 保留導覽高度、觸控與選取語意', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: buildShellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = find.byKey(const ValueKey('apple-root-tab-bar'));
      final padding = tester.widget<Padding>(
        find.descendant(of: bar, matching: find.byType(Padding)).first,
      );
      expect(padding.padding, const EdgeInsets.fromLTRB(16, 0, 16, 16));
      final glass = tester.widget<GlassTabBar>(
        find.descendant(of: bar, matching: find.byType(GlassTabBar)),
      );
      expect(glass.barHeight, 64);
      expect(glass.iconSize, 24);
      expect(glass.iconLabelSpacing, 4);
      expect(glass.platformViewBackdrop, isFalse);
      expect(
        _selectedPillColor(tester, '聊天'),
        AppTheme.light().colorScheme.surfaceContainerHigh,
      );
      // 新版材質數值由套件決定；幾何、選取及前景語意維持 App 契約。
    });

    testWidgets('root tab bar 選取態是中性膠囊加品牌柔褐字符，兩態同實心字符', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: buildShellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scheme = AppTheme.light().colorScheme;
      final glass = tester.widget<GlassTabBar>(
        find.descendant(
          of: find.byKey(const ValueKey('apple-root-tab-bar')),
          matching: find.byType(GlassTabBar),
        ),
      );
      (double, double, double) rgb(Color c) => (c.r, c.g, c.b);

      // 中性選取表面與品牌前景各自保留。
      final pillColor = _selectedPillColor(tester, '聊天');
      expect(rgb(pillColor), isNot(rgb(scheme.primary)));
      expect(
        rgb(pillColor),
        rgb(scheme.surfaceContainerHigh),
        reason: '選取底是中性語意層',
      );

      // 品牌色只出現在前景：字符與標籤。
      expect(glass.selectedIconColor, scheme.primary);

      final icons = tester.widgetList<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('apple-root-tab-bar')),
          matching: find.byType(Icon),
        ),
      );
      for (final icon in [
        CupertinoIcons.chat_bubble_fill,
        CupertinoIcons.briefcase_fill,
        CupertinoIcons.map_fill,
        CupertinoIcons.heart_fill,
      ]) {
        expect(icons.any((widget) => widget.icon == icon), isTrue);
      }
    });

    testWidgets('深色 root tab 使用中性黑玻璃與中性選取膠囊', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: buildShellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = find.byKey(const ValueKey('apple-root-tab-bar'));
      final glass = tester.widget<GlassTabBar>(
        find.descendant(of: bar, matching: find.byType(GlassTabBar)),
      );
      expect(
        _selectedPillColor(tester, '聊天'),
        AppTheme.dark().colorScheme.surfaceContainerHigh,
      );
      expect(glass.selectedIconColor, AppTheme.dark().colorScheme.primary);
      expect(glass.settings!.glassColor.a, lessThan(1));
    });

    test('iPhone safe area 與膠囊重疊後，底部至少保留 16pt', () {
      expect(TpRootTabGeometry.expandedHeightFor(34), 80);
    });
  });
}

class _ReselectRootProbe extends StatelessWidget {
  const _ReselectRootProbe();

  @override
  Widget build(BuildContext context) => const TpRootScrollView(
    slivers: [
      SliverToBoxAdapter(child: TextField(key: ValueKey('root-draft-field'))),
      SliverToBoxAdapter(child: SizedBox(height: 1200)),
    ],
  );
}

class _AdaptiveDetailStateProbe extends StatefulWidget {
  const _AdaptiveDetailStateProbe();

  @override
  State<_AdaptiveDetailStateProbe> createState() =>
      _AdaptiveDetailStateProbeState();
}

class _AdaptiveDetailStateProbeState extends State<_AdaptiveDetailStateProbe> {
  final _scrollController = ScrollController();
  var _day = 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('TRIPS-DETAIL', key: ValueKey('trip-detail-probe')),
        Text('DAY $_day'),
        TextButton(
          key: const ValueKey('trip-detail-next-day'),
          onPressed: () => setState(() => _day++),
          child: const Text('下一天'),
        ),
        const TextField(key: ValueKey('trip-detail-draft')),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('trip-detail-scroll'),
            controller: _scrollController,
            itemCount: 40,
            itemBuilder: (_, index) =>
                SizedBox(height: 44, child: Text('ENTRY $index')),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
