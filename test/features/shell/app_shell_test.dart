import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tripline/features/shell/app_shell.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';

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
      await tester.tap(find.text('地圖'));
      await tester.pumpAndSettle();
      expect(find.text('PROBE-MAP'), findsOneWidget);
      expect(find.text('PROBE-CHAT'), findsNothing);

      // 點「收藏」→ branch 3
      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();
      expect(find.text('PROBE-FAV'), findsOneWidget);
      expect(find.text('帳號'), findsNothing);
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
        find.descendant(of: bar, matching: find.byType(BackdropFilter)),
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
      expect(find.text('聊天'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('root-vertical-list')),
        const Offset(0, -320),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(bar), restingSize);
      expect(find.text('聊天'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('root-vertical-list')),
        const Offset(0, 220),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(bar), restingSize);
      expect(find.text('聊天'), findsOneWidget);
    });

    testWidgets('四個 tab 都有 label 且目前 tab 具 selected semantics', (tester) async {
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
      final selected = tester.getSemantics(
        find.byKey(const ValueKey('root-tab-聊天')),
      );
      expect(
        selected.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      semantics.dispose();
    });

    testWidgets('root tab 對齊定版 mockup 的 30/44/8 幾何與透明玻璃色', (tester) async {
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
      expect(padding.padding, const EdgeInsets.fromLTRB(30, 0, 30, 8));
      final glass = find.descendant(
        of: bar,
        matching: find.byType(BackdropFilter),
      );
      expect(tester.getSize(glass).height, 44);

      final glassDecoration = tester.widget<DecoratedBox>(
        find.descendant(of: bar, matching: find.byType(DecoratedBox)).first,
      );
      expect(
        (glassDecoration.decoration as BoxDecoration).color,
        TpColorsLight.background.withValues(alpha: 0.42),
      );
      expect(
        find.byKey(const ValueKey('root-tab-selected-surface-聊天')),
        findsOneWidget,
      );
    });

    testWidgets('深色 root tab 使用更透的 Liquid Glass rgba(40,40,42,.38)', (
      tester,
    ) async {
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
      final glassDecoration = tester.widget<DecoratedBox>(
        find.descendant(of: bar, matching: find.byType(DecoratedBox)).first,
      );
      expect(
        (glassDecoration.decoration as BoxDecoration).color,
        TpColorsDark.glass.withValues(alpha: 0.38),
      );
    });

    test('iPhone safe area 與膠囊重疊 24pt，底部仍保留 10pt', () {
      expect(TpRootTabGeometry.expandedHeightFor(34), 54);
    });
  });
}
