import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';

const _bandKey = ValueKey('tp-root-tab-band');

Future<void> _pump(WidgetTester tester, {double keyboard = 0}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      // 與 AppShell 一致：root 畫面外面還有一層 Scaffold，會先吃掉鍵盤 inset，
      // 所以 TpRootScaffold 的 MediaQuery.viewInsets 永遠是 0，要讀 View 本身。
      home: const Scaffold(
        body: TpRootScaffold(
          header: TpRootHeaderConfig(title: Text('測試')),
          body: SizedBox.expand(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('沒有鍵盤：底部 tab 遮蔽帶存在', (tester) async {
    await _pump(tester);
    expect(find.byKey(_bandKey), findsOneWidget);
  });

  testWidgets('鍵盤開啟：tab 已隱藏，遮蔽帶也不能留著糊住輸入列', (tester) async {
    await _pump(tester, keyboard: 300);
    expect(find.byKey(_bandKey), findsNothing);
  });
}
