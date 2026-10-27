import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';

const _bandKey = ValueKey('tp-root-tab-band');

Widget _scene({double keyboard = 0}) => MediaQuery(
  data: MediaQueryData(
    size: const Size(390, 844),
    padding: const EdgeInsets.only(top: 47, bottom: 34),
    viewInsets: EdgeInsets.only(bottom: keyboard),
  ),
  child: MaterialApp(
    theme: AppTheme.light(),
    home: const TpRootScaffold(
      header: TpRootHeaderConfig(title: Text('測試')),
      body: SizedBox.expand(),
    ),
  ),
);

void main() {
  testWidgets('沒有鍵盤：底部 tab 遮蔽帶存在', (tester) async {
    await tester.pumpWidget(_scene());
    expect(find.byKey(_bandKey), findsOneWidget);
  });

  testWidgets('鍵盤開啟：tab 已隱藏，遮蔽帶也不能留著糊住輸入列', (tester) async {
    await tester.pumpWidget(_scene(keyboard: 300));
    expect(find.byKey(_bandKey), findsNothing);
  });
}
