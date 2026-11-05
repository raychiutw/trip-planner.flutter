import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_inline_banner.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget banner) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: banner),
    ),
  );

  testWidgets('紅底橫幅：errorContainer 底色、圓角 12、liveRegion 語意', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      const TpInlineBanner(key: ValueKey('b'), message: '已載入最新版本'),
    );
    final scheme = Theme.of(
      tester.element(find.byType(TpInlineBanner)),
    ).colorScheme;
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('b')),
        matching: find.byType(Container),
      ),
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, scheme.errorContainer);
    expect(decoration.borderRadius, BorderRadius.circular(12));
    expect(
      tester.getSemantics(find.text('已載入最新版本')).label,
      contains('已載入最新版本'),
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('b')))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('有 action 時靠右顯示在文字下方', (tester) async {
    await pump(
      tester,
      TpInlineBanner(
        message: '訊息',
        action: TextButton(onPressed: () {}, child: const Text('重試')),
      ),
    );
    expect(
      tester.getTopLeft(find.text('重試')).dy,
      greaterThan(tester.getBottomLeft(find.text('訊息')).dy - 1),
    );
    expect(
      tester.getTopRight(find.byType(TextButton)).dx,
      greaterThan(tester.getCenter(find.text('訊息')).dx),
    );
  });
}
