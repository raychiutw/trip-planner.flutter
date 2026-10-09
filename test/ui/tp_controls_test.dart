import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_chip.dart';
import 'package:tripline/ui/tp_filled_button.dart';
import 'package:tripline/ui/tp_picker_field.dart';
import 'package:tripline/ui/tp_progress_bar.dart';
import 'package:tripline/ui/tp_segmented_control.dart';
import 'package:tripline/ui/tp_selection_circle.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('TpProgressBar', () {
    testWidgets('determinate 填滿比例等於 value,語意帶百分比', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 200,
            child: TpProgressBar(value: 0.25, semanticLabel: '上傳進度'),
          ),
        ),
      );
      final fill = tester.getSize(
        find.byKey(const ValueKey('tp-progress-fill')),
      );
      expect(fill.width, closeTo(50, 0.5));
      final node = tester.getSemantics(find.bySemanticsLabel('上傳進度'));
      expect(node.value, '25%');
      handle.dispose();
    });

    testWidgets('填色取自 colorScheme.primary,軌道取自 outlineVariant', (tester) async {
      final theme = AppTheme.light();
      await tester.pumpWidget(
        _host(
          const SizedBox(width: 200, child: TpProgressBar(value: 0.5)),
          theme: theme,
        ),
      );
      final fill = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('tp-progress-fill')),
      );
      expect(
        (fill.decoration as BoxDecoration).color,
        theme.colorScheme.primary,
      );
      final track = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('tp-progress-track')),
      );
      expect(
        (track.decoration as BoxDecoration).color,
        theme.colorScheme.outlineVariant,
      );
    });

    testWidgets('indeterminate 預設語意為載入中且沒有百分比', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const SizedBox(width: 200, child: TpProgressBar())),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('載入中'));
      expect(node.value, '');
      handle.dispose();
    });

    testWidgets('value 超出範圍會 clamp', (tester) async {
      await tester.pumpWidget(
        _host(const SizedBox(width: 100, child: TpProgressBar(value: 3))),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('tp-progress-fill'))).width,
        100,
      );
    });
  });

  group('TpSelectionCircle', () {
    testWidgets('選取時畫實心勾選圓,未選時畫空心圓,點擊回傳反向值', (tester) async {
      bool? changed;
      var value = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _host(
            TpSelectionCircle(
              selected: value,
              semanticLabel: '選取 A',
              onChanged: (v) {
                changed = v;
                setState(() => value = v);
              },
            ),
          ),
        ),
      );
      expect(find.byIcon(CupertinoIcons.circle), findsOneWidget);
      await tester.tap(find.byType(TpSelectionCircle));
      await tester.pump();
      expect(changed, isTrue);
      expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsOneWidget);
    });

    testWidgets('語意為 checked 且帶標籤;停用時不可點', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const TpSelectionCircle(
            selected: true,
            semanticLabel: '選取 B',
            onChanged: null,
          ),
        ),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('選取 B'));
      expect(node.flagsCollection.isChecked, CheckedState.isTrue);
      handle.dispose();
    });

    testWidgets('點擊區至少 44x44', (tester) async {
      await tester.pumpWidget(
        _host(
          TpSelectionCircle(
            selected: false,
            semanticLabel: 'x',
            onChanged: (_) {},
          ),
        ),
      );
      final size = tester.getSize(find.byType(TpSelectionCircle));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('TpChip', () {
    testWidgets('selected 以 primaryContainer 填色並標示 selected 語意', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final theme = AppTheme.light();
      await tester.pumpWidget(
        _host(
          TpChip(label: '景點', selected: true, onPressed: () {}),
          theme: theme,
        ),
      );
      final deco = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(TpChip),
          matching: find.byKey(const ValueKey('tp-chip-surface')),
        ),
      );
      expect(
        (deco.decoration as BoxDecoration).color,
        theme.colorScheme.primaryContainer,
      );
      final node = tester.getSemantics(find.byType(TpChip));
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('onPressed 為 null 時停用,且不是 Material chip', (tester) async {
      await tester.pumpWidget(_host(const TpChip(label: '停用')));
      await tester.tap(find.byType(TpChip));
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('點擊觸發 onPressed,高度至少 44', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(TpChip(label: '點我', onPressed: () => taps++)),
      );
      expect(
        tester.getSize(find.byType(TpChip)).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.text('點我'));
      expect(taps, 1);
    });
  });

  group('TpSegmentedControl', () {
    testWidgets('切換時回傳新值,底層是 CupertinoSlidingSegmentedControl', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _host(
          TpSegmentedControl<String>(
            value: 'a',
            options: const {'a': '甲', 'b': '乙'},
            onChanged: (v) => picked = v,
          ),
        ),
      );
      expect(
        find.byType(CupertinoSlidingSegmentedControl<String>),
        findsOneWidget,
      );
      await tester.tap(find.text('乙'));
      await tester.pumpAndSettle();
      expect(picked, 'b');
    });

    testWidgets('onChanged 為 null 時不回呼', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _host(
          const TpSegmentedControl<String>(
            value: 'a',
            options: {'a': '甲', 'b': '乙'},
            onChanged: null,
          ),
        ),
      );
      await tester.tap(find.text('乙'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(picked, isNull);
    });
  });

  group('TpPickerField', () {
    testWidgets('顯示目前值,點擊開 action sheet 並回傳選擇', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _host(
          TpPickerField<String>(
            label: '類型',
            value: 'a',
            options: const {'a': '甲', 'b': '乙'},
            onChanged: (v) => picked = v,
          ),
        ),
      );
      expect(find.text('甲'), findsOneWidget);
      await tester.tap(find.byType(TpPickerField<String>));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('乙'));
      await tester.pumpAndSettle();
      expect(picked, 'b');
    });

    testWidgets('停用時點擊不開 sheet', (tester) async {
      await tester.pumpWidget(
        _host(
          const TpPickerField<String>(
            label: '類型',
            value: 'a',
            options: {'a': '甲', 'b': '乙'},
            onChanged: null,
          ),
        ),
      );
      await tester.tap(find.byType(TpPickerField<String>));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
    });
  });

  group('TpFilledButton', () {
    testWidgets('底層是 CupertinoButton,顏色走 colorScheme', (tester) async {
      final theme = AppTheme.light();
      var taps = 0;
      await tester.pumpWidget(
        _host(
          TpFilledButton(label: '重試', onPressed: () => taps++),
          theme: theme,
        ),
      );
      final button = tester.widget<CupertinoButton>(
        find.byType(CupertinoButton),
      );
      expect(button.color, theme.colorScheme.primary);
      await tester.tap(find.text('重試'));
      expect(taps, 1);
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
