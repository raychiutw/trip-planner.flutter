import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tripline/features/shell/app_shell.dart';
import 'package:tripline/theme/app_theme.dart';

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
          probe('/account', 'PROBE-ACCOUNT'),
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
          probe('/account', const Text('PROBE-ACCOUNT')),
        ],
      ),
    ],
  );
}

GoRouter buildHorizontalShellRouter() {
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
              key: const ValueKey('root-horizontal-list'),
              scrollDirection: Axis.horizontal,
              itemCount: 20,
              itemBuilder: (_, index) =>
                  SizedBox(width: 120, child: Text('CARD-$index')),
            ),
          ),
          probe('/trips', const Text('PROBE-TRIPS')),
          probe('/map', const Text('PROBE-MAP')),
          probe('/favorites', const Text('PROBE-FAV')),
          probe('/account', const Text('PROBE-ACCOUNT')),
        ],
      ),
    ],
  );
}

void main() {
  group('AppShell 5-tab 導航', () {
    testWidgets('5 個 tab,點擊切換到對應 branch', (tester) async {
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

      // 點「帳號」→ branch 4
      await tester.tap(find.text('帳號'));
      await tester.pumpAndSettle();
      expect(find.text('PROBE-ACCOUNT'), findsOneWidget);
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

    testWidgets('垂直向下捲縮成 icon-only,向上捲恢復 label', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: buildScrollableShellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('聊天'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('root-vertical-list')),
        const Offset(0, -320),
      );
      await tester.pumpAndSettle();
      expect(find.text('聊天'), findsNothing);

      await tester.drag(
        find.byKey(const ValueKey('root-vertical-list')),
        const Offset(0, 220),
      );
      await tester.pumpAndSettle();
      expect(find.text('聊天'), findsOneWidget);
    });

    testWidgets('水平內容捲動不縮減 root tab', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: buildHorizontalShellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const ValueKey('root-horizontal-list')),
        const Offset(-320, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('聊天'), findsOneWidget);
      expect(find.text('帳號'), findsOneWidget);
    });

    testWidgets('五個 tab 都有 label 且目前 tab 具 selected semantics', (tester) async {
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

      for (final label in ['聊天', '行程', '地圖', '收藏', '帳號']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      final selected = tester.getSemantics(
        find.byKey(const ValueKey('root-tab-聊天')),
      );
      expect(
        selected.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      semantics.dispose();
    });
  });
}
