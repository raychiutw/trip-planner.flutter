import 'dart:math' as math;
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_tag.dart';

Widget _host(Widget child, ThemeData theme, {double textScale = 1}) =>
    MaterialApp(
      theme: theme,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

DecoratedBox _surface(WidgetTester tester) => tester.widget<DecoratedBox>(
  find.descendant(of: find.byType(TpTag), matching: find.byType(DecoratedBox)),
);

void main() {
  group('TpTag', () {
    testWidgets('語意是純文字:不是 button、不可聚焦、沒有停用狀態、沒有 tap 動作', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const TpTag(label: '3 筆'), AppTheme.light()),
      );

      final node = tester.getSemantics(find.text('3 筆'));
      expect(node.label, '3 筆');
      expect(node.flagsCollection.isButton, isFalse);
      expect(node.flagsCollection.isFocused, Tristate.none);
      expect(node.flagsCollection.isEnabled, Tristate.none);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('不含任何點擊手勢', (tester) async {
      await tester.pumpWidget(
        _host(const TpTag(label: '標籤'), AppTheme.light()),
      );
      for (final type in [GestureDetector, InkWell, Focus]) {
        expect(
          find.descendant(of: find.byType(TpTag), matching: find.byType(type)),
          findsNothing,
          reason: '$type',
        );
      }
    });

    for (final (name, theme) in [
      ('淺色', AppTheme.light()),
      ('深色', AppTheme.dark()),
      ('淺色高對比', AppTheme.light(highContrast: true)),
      ('深色高對比', AppTheme.dark(highContrast: true)),
    ]) {
      for (final emphasized in [false, true]) {
        testWidgets('$name emphasized=$emphasized 文字對底色對比 >= 4.5', (
          tester,
        ) async {
          await tester.pumpWidget(
            _host(TpTag(label: '標籤', emphasized: emphasized), theme),
          );
          final fg = tester.widget<Text>(find.text('標籤')).style!.color!;
          expect(fg.a, 1.0, reason: '文字不可半透明(停用樣式的症狀)');
          final fill = (_surface(tester).decoration as BoxDecoration).color!;
          final bg = Color.alphaBlend(fill, theme.scaffoldBackgroundColor);
          expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
        });
      }
    }

    testWidgets('emphasized 與一般樣式視覺不同', (tester) async {
      Future<Color?> fill(bool e) async {
        await tester.pumpWidget(
          _host(TpTag(label: '標籤', emphasized: e), AppTheme.light()),
        );
        return (_surface(tester).decoration as BoxDecoration).color;
      }

      expect(await fill(true), isNot(await fill(false)));
    });

    testWidgets('Dynamic Type 極大字級下在窄寬度換行而不溢位', (tester) async {
      const label = '這是一個很長的標籤文字用來測試換行';
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 120,
            child: Wrap(children: [TpTag(label: label)]),
          ),
          AppTheme.light(),
          textScale: 3,
        ),
      );
      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.size.height, greaterThan(60));
      expect(tester.getSize(find.byType(TpTag)).width, lessThanOrEqualTo(120));
    });
  });
}
