import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_bottom_accessory.dart';
import 'package:tripline/ui/tp_content_surface.dart';
import 'package:tripline/ui/tp_root_scroll_scaffold.dart';
import 'package:tripline/ui/tp_scope_menu.dart';
import 'package:tripline/ui/tp_settings_group.dart';
import 'package:tripline/ui/tp_state_view.dart';

Widget app(Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void main() {
  testWidgets('TpStateView error 保留訊息與單一 recovery action', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TpStateView(
            kind: TpStateKind.error,
            title: '無法載入行程',
            message: '請檢查連線後再試一次。',
            actionLabel: '重試',
            onAction: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text('無法載入行程'), findsOneWidget);
    expect(find.text('請檢查連線後再試一次。'), findsOneWidget);
    await tester.tap(find.text('重試'));
    expect(retries, 1);
  });

  testWidgets('TpSettingsGroup 在 200% 文字仍保留 44pt row 與 disclosure', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: TpSettingsGroup(
              title: '安全性',
              children: [
                TpSettingsRow(
                  title: '登入裝置',
                  subtitle: '管理目前登入中的裝置',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        textScale: 2,
      ),
    );

    expect(find.text('登入裝置'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_forward), findsOneWidget);
    expect(
      tester.getSize(find.byType(TpSettingsRow)).height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TpContentSurface 是內容材質而不是 glass', (tester) async {
    await tester.pumpWidget(
      app(
        const Scaffold(
          body: TpContentSurface(semanticLabel: '東京行程', child: Text('東京行程')),
        ),
      ),
    );

    final surface = find.byType(TpContentSurface);
    expect(surface, findsOneWidget);
    expect(
      find.descendant(of: surface, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
  });

  testWidgets('TpRootScrollScaffold 提供 large title 與浮動 tab 底部 inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const TpRootScrollScaffold(
          title: '我的行程',
          slivers: [SliverToBoxAdapter(child: Text('內容'))],
        ),
      ),
    );

    expect(find.text('我的行程'), findsWidgets);
    expect(
      find.byKey(const ValueKey('root-scroll-bottom-inset')),
      findsOneWidget,
    );
    final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(appBar.toolbarHeight, 56);
    expect(appBar.collapsedHeight, 56);
    expect(appBar.expandedHeight, 108);
    expect(appBar.centerTitle, isTrue);
  });

  testWidgets('TpAppBar more 使用水平 ellipsis 且維持 44pt target', (tester) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          appBar: TpAppBar(
            title: const Text('行程'),
            actions: [
              TpMoreMenuButton<int>(
                items: const [PopupMenuItem(value: 1, child: Text('列印'))],
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(CupertinoIcons.ellipsis), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(
      tester.getSize(find.byType(TpMoreMenuButton<int>)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('TpScopeMenu 顯示目前值並回傳新選項', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TpScopeMenu<int>(
            label: '地圖 · 總覽',
            value: selected,
            options: const [
              TpScopeOption(value: 0, label: '總覽'),
              TpScopeOption(value: 1, label: 'DAY 01'),
            ],
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('地圖 · 總覽'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAY 01'));
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  testWidgets('TpBottomAccessory 只有 collapsed 與 medium 兩個 detent', (
    tester,
  ) async {
    var detent = TpAccessoryDetent.collapsed;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TpBottomAccessory(
                detent: detent,
                collapsed: const Text('collapsed'),
                medium: const Text('medium'),
                onChanged: (value) => setState(() => detent = value),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(TpBottomAccessory)).height, 72);
    await tester.tap(find.byType(TpBottomAccessory));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(TpBottomAccessory)).height, 220);
  });
}
