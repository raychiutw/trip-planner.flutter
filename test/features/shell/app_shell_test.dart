import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/features/shell/app_shell.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
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

void main() {
  group('AppShell 4-tab 導航', () {
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
        glass.indicatorColor,
        TpColorsDark.rootTabSelection.withValues(alpha: 0.68),
      );
      expect(glass.selectedIconColor, TpColorsDark.accentDeep);
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
      expect(standard.settings?.glassColor.a, closeTo(0.40, 0.01));
      expect(standard.settings?.backerColor, isNull);

      await tester.tap(find.bySemanticsLabel('地圖'));
      await tester.pumpAndSettle();

      final map = rootBar();
      expect(map.platformViewBackdrop, isTrue);
      expect(map.settings?.glassColor.a, closeTo(0.56, 0.01));
      expect(map.settings?.thickness, standard.settings?.thickness);
      expect(map.settings?.blur, standard.settings?.blur);
      expect(map.settings?.lightIntensity, standard.settings?.lightIntensity);
      expect(map.settings?.ambientStrength, standard.settings?.ambientStrength);
      expect(map.settings?.refractiveIndex, standard.settings?.refractiveIndex);
      expect(
        map.settings?.standardOpacityMultiplier,
        standard.settings?.standardOpacityMultiplier,
      );
      expect(map.indicatorSettings?.blur, map.settings?.blur);
      expect(
        map.indicatorSettings?.refractiveIndex,
        map.settings?.refractiveIndex,
      );
      expect(TpColorsLight.rootTabSelection, TpColorsLight.dayThumb);
    });

    testWidgets('root tab 是浮動 Liquid Glass 功能層', (tester) async {
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
      expect(
        find.descendant(of: bar, matching: find.byIcon(SFIcons.sf_suitcase)),
        findsOneWidget,
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

    testWidgets('root tab 使用套件原生 16/64/32 Liquid Glass 幾何', (tester) async {
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
      expect(glass.barBorderRadius, 32);
      expect(glass.iconSize, 24);
      expect(glass.iconLabelSpacing, 4);
      expect(glass.platformViewBackdrop, isFalse);
      expect(
        glass.indicatorColor,
        TpColorsLight.rootTabSelection.withValues(alpha: 0.68),
      );
      expect(glass.settings?.chromaticAberration, 0);
      expect(glass.settings?.refractiveIndex, lessThanOrEqualTo(1.08));
    });

    testWidgets('深色 root tab 使用中性黑玻璃與暖褐選取色', (tester) async {
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
        glass.indicatorColor,
        TpColorsDark.rootTabSelection.withValues(alpha: 0.68),
      );
      expect(glass.selectedIconColor, TpColorsDark.accentDeep);
      expect(glass.settings?.chromaticAberration, 0);
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
