import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/adaptive.dart';

Widget _host(TargetPlatform platform) => MaterialApp(
  theme: ThemeData(platform: platform),
  home: const Scaffold(
    body: CustomScrollView(
      slivers: [
        SliverAdaptiveLargeTitle(title: '我的行程'),
        SliverToBoxAdapter(
          child: SizedBox(height: 1200, child: Text('body')),
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('iOS 走 CupertinoSliverNavigationBar 並顯示標題', (tester) async {
    await tester.pumpWidget(_host(TargetPlatform.iOS));
    expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
    expect(find.text('我的行程'), findsWidgets);
  });

  testWidgets('iOS 收合後小標放大成 titleLarge(對齊 AppBar,只在收合時顯示)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(TargetPlatform.iOS));
    final nav = tester.widget<CupertinoSliverNavigationBar>(
      find.byType(CupertinoSliverNavigationBar),
    );
    // middle 只在收合時淡入(置頂仍只顯示大標)
    expect(nav.alwaysShowMiddle, isFalse);
    final ctx = tester.element(find.byType(CupertinoSliverNavigationBar));
    final expected = Theme.of(ctx).textTheme.titleLarge?.fontSize;
    expect((nav.middle! as Text).style?.fontSize, expected);
    // 比 iOS 預設 nav title(17)大
    expect(expected, greaterThan(17));
  });

  testWidgets('Android 走 SliverAppBar.large 並顯示標題', (tester) async {
    await tester.pumpWidget(_host(TargetPlatform.android));
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.text('我的行程'), findsWidgets);
  });

  testWidgets('actions 會渲染在標題列', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAdaptiveLargeTitle(
                title: 'X',
                actions: [
                  IconButton(
                    key: const ValueKey('act'),
                    icon: const Icon(CupertinoIcons.add),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('act')), findsOneWidget);
  });
}
