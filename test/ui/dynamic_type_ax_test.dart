import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/dynamic_type.dart';
import 'package:tripline/ui/swipe_to_delete.dart';
import 'package:tripline/ui/tp_settings_group.dart';

/// AX 字級(TextScaler 3.0 以上)下共用元件不得縮字、截斷或溢位。
Widget _host(Widget child, {double scale = 3.2}) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void _noop() {}

void main() {
  testWidgets('SwipeToDelete 動作鈕在 AX 字級不用 FittedBox 縮字', (tester) async {
    await tester.pumpWidget(
      _host(
        SwipeToDelete(
          dismissKey: const ValueKey('row'),
          onDelete: () async {},
          child: const SizedBox(height: 200, child: Text('內容')),
        ),
      ),
    );
    await tester.drag(find.byKey(const ValueKey('row')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    final action = find.byKey(
      const ValueKey<Object>(('swipe-delete-action', ValueKey('row'))),
    );
    expect(action, findsOneWidget);
    expect(
      find.descendant(of: action, matching: find.byType(FittedBox)),
      findsNothing,
      reason: '不得以縮小字級處理溢位',
    );
    // 動作鈕寬度容得下放大後的「刪除」,不靠縮字。
    expect(
      tester.getSize(action).width,
      greaterThanOrEqualTo(tester.getSize(find.text('刪除')).width),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TpSettingsRow 在 AX 字級完整顯示 value,不省略號、不被腰斬', (tester) async {
    const value = '有效至 2026/12/31 之前都可以使用的很長數值';
    await tester.pumpWidget(
      _host(
        const TpSettingsGroup(
          children: [TpSettingsRow(title: '登入裝置', value: value, onTap: _noop)],
        ),
      ),
    );
    final text = tester.widget<Text>(find.text(value));
    expect(text.maxLines, isNull);
    final paragraph = tester.renderObject<RenderParagraph>(find.text(value));
    expect(paragraph.didExceedMaxLines, isFalse);
    // value 獨佔整行寬度,而不是與標題各半。
    final rowWidth = tester.getSize(find.byType(TpSettingsRow)).width;
    expect(tester.getSize(find.text(value)).width, greaterThan(rowWidth / 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scaledTapMin 隨字級放大且不低於 44', (tester) async {
    late double at1;
    late double at3;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            at3 = scaledTapMin(context);
            return const SizedBox();
          },
        ),
        scale: 3,
      ),
    );
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            at1 = scaledTapMin(context);
            return const SizedBox();
          },
        ),
        scale: 1,
      ),
    );
    expect(at1, 44);
    expect(at3, greaterThan(100));
  });
}
