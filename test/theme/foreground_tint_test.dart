import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/adaptive.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_chip.dart';
import 'package:tripline/ui/tp_filled_button.dart';
import 'package:tripline/ui/tp_picker_field.dart';
import 'package:tripline/ui/tp_selection_circle.dart';

/// 淺色前景文字／圖示統一用深棕 tintDeep，tint 只留給底色與邊線；
/// 確認框破壞性動作用 App 色票 destructive，不是 Cupertino 的 systemRed。
/// 深色不得改變。

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) =>
    tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: Center(child: child)),
      ),
    );

Color? _textColor(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)).first,
  );
  return rich.text.style?.color;
}

Future<Color?> _confirmColor(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppConfirm(
            context,
            title: '刪除這個行程？',
            confirmLabel: '刪除',
            isDestructive: true,
          ),
          child: const Text('開'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('開'));
  await tester.pumpAndSettle();
  return tester
      .widget<RichText>(
        find
            .descendant(
              of: find.descendant(
                of: find.byType(CupertinoDialogAction),
                matching: find.text('刪除'),
              ),
              matching: find.byType(RichText),
            )
            .first,
      )
      .text
      .style
      ?.color;
}

void main() {
  group('確認框破壞性動作', () {
    testWidgets('淺色：實際渲染 destructive #D70015，不是 systemRed', (tester) async {
      final c = await _confirmColor(tester, AppTheme.light());
      expect(c, TpSystemColorsLight.destructive);
      expect(c, isNot(const Color(0xFFFF3B30)));
    });

    testWidgets('深色不變：#FF6961', (tester) async {
      expect(
        await _confirmColor(tester, AppTheme.dark()),
        TpSystemColorsDark.destructive,
      );
    });
  });

  group('淺色前景', () {
    testWidgets('colorScheme.primary 一律是 tintDeep（含一般狀態）', (tester) async {
      expect(
        AppTheme.light().colorScheme.primary,
        TpSystemColorsLight.tintDeep,
      );
      expect(
        AppTheme.light(highContrast: true).colorScheme.primary,
        TpSystemColorsLight.tintDeep,
      );
    });

    testWidgets('picker 目前值文字、選取圓圈圖示、選中 chip 文字＝tintDeep', (tester) async {
      await _pump(
        tester,
        AppTheme.light(),
        Column(
          children: [
            TpPickerField<String>(
              label: '排序',
              compact: true,
              value: 'a',
              options: const {'a': '最近'},
              onChanged: (_) {},
            ),
            TpSelectionCircle(selected: true, onChanged: (_) {}),
            TpChip(label: '東京', selected: true, onPressed: () {}),
          ],
        ),
      );
      expect(_textColor(tester, '最近'), TpSystemColorsLight.tintDeep);
      expect(_textColor(tester, '東京'), TpSystemColorsLight.tintDeep);
      expect(
        tester
            .widget<Icon>(find.byIcon(CupertinoIcons.checkmark_circle_fill))
            .color,
        TpSystemColorsLight.tintDeep,
      );
    });

    testWidgets('一般前景：TextButton／NavigationBar 選中／AppBar 前景＝tintDeep', (
      tester,
    ) async {
      final t = AppTheme.light();
      const deep = TpSystemColorsLight.tintDeep;
      expect(t.textButtonTheme.style?.foregroundColor?.resolve({}), deep);
      expect(t.appBarTheme.foregroundColor, deep);
      expect(
        t.navigationBarTheme.labelTextStyle?.resolve({
          WidgetState.selected,
        })?.color,
        deep,
      );
      expect(
        t.navigationBarTheme.iconTheme?.resolve({WidgetState.selected})?.color,
        deep,
      );
    });

    testWidgets('非文字用途仍是 tint：主要按鈕底、選中 chip 邊線', (tester) async {
      await _pump(
        tester,
        AppTheme.light(),
        Column(
          children: [
            TpFilledButton(label: '儲存', onPressed: () {}),
            TpChip(label: '東京', selected: true, onPressed: () {}),
          ],
        ),
      );
      final button = tester.widget<CupertinoButton>(
        find.byType(CupertinoButton),
      );
      expect(button.color, TpSystemColorsLight.tint);
      final chip = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('tp-chip-surface')),
      );
      expect(
        ((chip.decoration as BoxDecoration).border as Border).top.color,
        TpSystemColorsLight.tint,
      );
      expect(
        AppTheme.light().filledButtonTheme.style?.backgroundColor?.resolve({}),
        TpSystemColorsLight.tint,
      );
    });
  });

  group('深色不變', () {
    testWidgets('前景與底色皆維持 Dark.tint', (tester) async {
      expect(AppTheme.dark().colorScheme.primary, TpSystemColorsDark.tint);
      await _pump(
        tester,
        AppTheme.dark(),
        Column(
          children: [
            TpPickerField<String>(
              label: '排序',
              compact: true,
              value: 'a',
              options: const {'a': '最近'},
              onChanged: (_) {},
            ),
            TpFilledButton(label: '儲存', onPressed: () {}),
          ],
        ),
      );
      expect(_textColor(tester, '最近'), TpSystemColorsDark.tint);
      expect(
        tester.widget<CupertinoButton>(find.byType(CupertinoButton)).color,
        TpSystemColorsDark.tint,
      );
    });
  });
}
