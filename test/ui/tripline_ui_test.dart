import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_content_surface.dart';
import 'package:tripline/ui/tp_root_scroll_scaffold.dart';
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
  });
}
