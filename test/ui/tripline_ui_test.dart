import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_content_surface.dart';
import 'package:tripline/ui/tp_root_scroll_scaffold.dart';
import 'package:tripline/ui/tp_settings_group.dart';
import 'package:tripline/ui/tp_state_view.dart';

/// `bottomInset` 模擬 AppShell（extendBody）灌進 body 的浮動 tab bar 高度。
Widget app(Widget child, {double textScale = 1, double bottomInset = 0}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        padding: EdgeInsets.only(bottom: bottomInset),
      ),
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

  testWidgets('TpRootScrollScaffold 底部 inset 等於實測 tab bar 高度', (tester) async {
    const inset = 100.0;
    await tester.pumpWidget(
      app(
        const TpRootScrollScaffold(
          title: '我的行程',
          slivers: [SliverToBoxAdapter(child: Text('內容'))],
        ),
        bottomInset: inset,
      ),
    );

    expect(find.text('我的行程'), findsWidgets);
    // inset 必須跟著實測值走。硬編常數（先前的 navHeight + s4 = 104）在任何
    // 裝置都不會剛好對：實際高度是 safe area + 8 + 64。
    final spacer = find.byKey(const ValueKey('root-scroll-bottom-inset'));
    expect(tester.getSize(spacer).height, inset);
  });

  testWidgets('TpRootScrollScaffold 頁首恆為 inline,捲動不放大也不收合', (tester) async {
    await tester.pumpWidget(
      app(
        TpRootScrollScaffold(
          title: '我的行程',
          slivers: [
            SliverList.builder(
              itemCount: 40,
              itemBuilder: (_, index) =>
                  SizedBox(height: 56, child: Text('ROW-$index')),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // SliverAppBar 的 render object 是 RenderSliver,量不到 size;量內部的 AppBar。
    final toolbar = find.descendant(
      of: find.byType(SliverAppBar),
      matching: find.byType(AppBar),
    );
    final restingHeight = tester.getSize(toolbar).height;
    expect(restingHeight, kToolbarHeight);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('我的行程'), findsWidgets);
    expect(tester.getSize(toolbar).height, restingHeight);
  });
}
