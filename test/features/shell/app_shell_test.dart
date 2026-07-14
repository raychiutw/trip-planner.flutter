import 'package:flutter/cupertino.dart';
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

void main() {
  group('AppShell 5-tab 導航', () {
    Future<void> setWindowSize(WidgetTester tester, Size size) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });
    }

    Future<void> pumpShell(
      WidgetTester tester, {
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light().copyWith(platform: platform),
            routerConfig: buildShellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('窄版 Android 顯示 5 個底部 tab 並可切換 branch', (tester) async {
      await setWindowSize(tester, const Size(390, 844));
      await pumpShell(tester);

      // 初始 branch 0
      expect(find.text('PROBE-CHAT'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(5));

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

    testWidgets('窄版 iOS 使用 Cupertino tab bar', (tester) async {
      await setWindowSize(tester, const Size(390, 844));
      await pumpShell(tester, platform: TargetPlatform.iOS);

      expect(find.byType(CupertinoTabBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();
      expect(find.text('PROBE-FAV'), findsOneWidget);
    });

    testWidgets('寬版改用側邊 NavigationRail 並保留 5 個入口', (tester) async {
      await setWindowSize(tester, const Size(1024, 768));
      await pumpShell(tester);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, hasLength(5));

      await tester.tap(find.text('地圖'));
      await tester.pumpAndSettle();
      expect(find.text('PROBE-MAP'), findsOneWidget);
    });
  });
}
