import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_chip.dart';
import 'package:tripline/ui/tp_filled_button.dart';
import 'package:tripline/ui/tp_picker_field.dart';
import 'package:tripline/ui/tp_progress_bar.dart';
import 'package:tripline/ui/tp_segmented_control.dart';
import 'package:tripline/ui/tp_selection_circle.dart';
import 'package:tripline/ui/tp_tap_target.dart';

Widget _host(Widget child, {ThemeData? theme, bool reduceMotion = false}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

/// Tab 聚焦到第一個可聚焦元件後按下 [key]。
Future<void> _focusAndPress(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  await tester.sendKeyEvent(key);
  await tester.pump();
}

double _thumbX(WidgetTester tester) => tester
    .getTopLeft(
      find.descendant(
        of: find.byKey(const ValueKey('tp-segment-thumb')),
        matching: find.byType(DecoratedBox),
      ),
    )
    .dx;

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

    testWidgets('indeterminate 預設持續動畫;減少動態效果時靜止,切換即時生效', (tester) async {
      const bar = SizedBox(width: 200, child: TpProgressBar());
      await tester.pumpWidget(_host(bar));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(_host(bar, reduceMotion: true));
      await tester.pump(const Duration(seconds: 1)); // 讓路由轉場先結束
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        tester.getSize(find.byKey(const ValueKey('tp-progress-fill'))).width,
        closeTo(100, 0.5),
      );
      await tester.pumpWidget(_host(bar));
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('determinate 轉 indeterminate 才開始動畫,轉回即停', (tester) async {
      double? value = 0.5;
      late StateSetter set;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return SizedBox(width: 200, child: TpProgressBar(value: value));
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1)); // 讓路由轉場先結束
      expect(tester.hasRunningAnimations, isFalse);
      set(() => value = null);
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      set(() => value = 0.5);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // 讓路由轉場先結束
      expect(tester.hasRunningAnimations, isFalse);
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

    testWidgets('語意為 checked 且帶標籤;停用時語意為停用', (tester) async {
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
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('停用時點擊不回呼', (tester) async {
      await tester.pumpWidget(
        _host(
          const TpSelectionCircle(
            selected: false,
            semanticLabel: 'd',
            onChanged: null,
          ),
        ),
      );
      await tester.tap(find.byType(TpSelectionCircle));
      await _focusAndPress(tester, LogicalKeyboardKey.enter);
      expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
    });

    testWidgets('鍵盤:Tab 聚焦後 Enter 與 Space 各回傳一次反向值', (tester) async {
      final seen = <bool>[];
      await tester.pumpWidget(
        _host(
          TpSelectionCircle(
            selected: false,
            semanticLabel: 'k',
            onChanged: seen.add,
          ),
        ),
      );
      await _focusAndPress(tester, LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(seen, [true, true]);
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
    testWidgets('selected 以 primaryContainer 填色加 primary 邊框,並標示 selected 語意', (
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
      final box = deco.decoration as BoxDecoration;
      expect(box.color, theme.colorScheme.primaryContainer);
      expect((box.border as Border).top.color, theme.colorScheme.primary);
      final node = tester.getSemantics(find.byType(TpChip));
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('停用:語意為停用、點擊與鍵盤都不觸發,且不是 Material chip', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const TpChip(label: '停用')));
      expect(
        tester.getSemantics(find.byType(TpChip)).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      await _focusAndPress(tester, LogicalKeyboardKey.enter);
      expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
      handle.dispose();
    });

    testWidgets('鍵盤:Tab 聚焦後 Enter 觸發 onPressed,寬度至少 44', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(TpChip(label: '短', onPressed: () => taps++)),
      );
      expect(
        tester.getSize(find.byType(TpChip)).width,
        greaterThanOrEqualTo(44),
      );
      await _focusAndPress(tester, LogicalKeyboardKey.enter);
      expect(taps, 1);
    });

    testWidgets('點擊觸發 onPressed,高度至少 44', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(TpChip(label: '點我', onPressed: () => taps++)),
      );
      expect(
        tester.getSize(find.byType(TpChip)).height,
        inInclusiveRange(44, 56),
      );
      await tester.tap(find.text('點我'));
      expect(taps, 1);
    });
  });

  group('TpSegmentedControl', () {
    Widget segmented({String value = 'a', ValueChanged<String>? onChanged}) =>
        TpSegmentedControl<String>(
          value: value,
          options: const {'a': '甲', 'b': '乙', 'c': '丙'},
          onChanged: onChanged,
        );

    testWidgets('點擊另一段回傳該值,點目前段同樣回傳', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(_host(segmented(onChanged: picked.add)));
      await tester.tap(find.text('乙'));
      await tester.pumpAndSettle();
      expect(picked, ['b']);
      await tester.tap(find.text('甲'));
      expect(picked, ['b', 'a']);
    });

    testWidgets('value 變動後 thumb 滑到對應段,語意 selected 隨之變化', (tester) async {
      final handle = tester.ensureSemantics();
      var value = 'a';
      late StateSetter set;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return SizedBox(
                width: 300,
                child: segmented(value: value, onChanged: (_) {}),
              );
            },
          ),
        ),
      );
      final before = _thumbX(tester);
      set(() => value = 'c');
      await tester.pumpAndSettle();
      expect(_thumbX(tester), greaterThan(before + 150));
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('丙'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('甲'))
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
      handle.dispose();
    });

    testWidgets('onChanged 為 null:不回呼,語意為停用', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(segmented()));
      await tester.tap(find.text('乙'));
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.bySemanticsLabel('乙'));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('每一段高度至少 44,且整條不會撐滿可用高度', (tester) async {
      await tester.pumpWidget(_host(segmented(onChanged: (_) {})));
      final targets = find.byType(TpTapTarget).evaluate();
      expect(targets, hasLength(3));
      for (final element in targets) {
        expect(element.size!.height, inInclusiveRange(44, 56));
      }
      expect(
        tester.getSize(find.byType(TpSegmentedControl<String>)).height,
        inInclusiveRange(44, 60),
      );
    });

    testWidgets('鍵盤:Tab 聚焦後 Enter／Space 觸發該段回呼', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(_host(segmented(onChanged: picked.add)));
      await _focusAndPress(tester, LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(picked, ['a', 'a']);
    });

    testWidgets('停用時 Tab 不聚焦、Enter 不觸發', (tester) async {
      await tester.pumpWidget(_host(segmented()));
      await _focusAndPress(tester, LogicalKeyboardKey.enter);
      expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
    });

    testWidgets('thumb 一般以動畫滑動;減少動態效果時立即到位', (tester) async {
      Future<double> thumbAfterShortPump({required bool reduce}) async {
        var value = 'a';
        late StateSetter set;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          _host(
            StatefulBuilder(
              builder: (context, setState) {
                set = setState;
                return SizedBox(
                  width: 300,
                  child: segmented(value: value, onChanged: (_) {}),
                );
              },
            ),
            reduceMotion: reduce,
          ),
        );
        await tester.pumpAndSettle();
        set(() => value = 'c');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        return _thumbX(tester);
      }

      final animated = await thumbAfterShortPump(reduce: false);
      final instant = await thumbAfterShortPump(reduce: true);
      expect(instant, greaterThan(animated + 20));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1)); // 讓路由轉場先結束
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('TpPickerField', () {
    Widget field({
      String? value = 'a',
      ValueChanged<String>? onChanged,
      bool compact = false,
    }) => TpPickerField<String>(
      label: '類型',
      value: value,
      options: const {'a': '甲', 'b': '乙'},
      onChanged: onChanged,
      compact: compact,
    );

    testWidgets('顯示目前值,點擊開 action sheet 並回傳選擇', (tester) async {
      String? picked;
      await tester.pumpWidget(_host(field(onChanged: (v) => picked = v)));
      expect(find.text('甲'), findsOneWidget);
      await tester.tap(find.byType(TpPickerField<String>));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('乙'));
      await tester.pumpAndSettle();
      expect(picked, 'b');
    });

    testWidgets('停用時點擊不開 sheet,語意為停用', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(field()));
      await tester.tap(find.byType(TpPickerField<String>));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      final node = tester.getSemantics(find.bySemanticsLabel('類型'));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('鍵盤:Tab 聚焦後 Enter 開 sheet', (tester) async {
      await tester.pumpWidget(_host(field(onChanged: (_) {})));
      await _focusAndPress(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
    });

    testWidgets('compact 點擊區寬高至少 44,即使目前值很短', (tester) async {
      await tester.pumpWidget(_host(field(compact: true, onChanged: (_) {})));
      final size = tester.getSize(find.byType(TpTapTarget));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('value 不在 options 或為 null 時顯示 placeholder,不是空白', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(field(value: 'zzz', onChanged: (_) {})));
      expect(find.text('未選擇'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('類型')).value, '未選擇');
      await tester.pumpWidget(
        _host(field(value: null, compact: true, onChanged: (_) {})),
      );
      expect(find.text('未選擇'), findsOneWidget);
      handle.dispose();
    });
  });

  group('TpFilledButton', () {
    testWidgets('點擊觸發 onPressed,顏色走 colorScheme,不是 Material 鈕', (tester) async {
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

    testWidgets('停用時語意為停用', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const TpFilledButton(label: '重試', onPressed: null)),
      );
      await tester.tap(find.text('重試'));
      final node = tester.getSemantics(find.bySemanticsLabel('重試'));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('鍵盤:聚焦後 Enter 觸發,高度至少 44', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(TpFilledButton(label: '重試', onPressed: () => taps++)),
      );
      expect(
        tester.getSize(find.byType(CupertinoButton)).height,
        greaterThanOrEqualTo(44),
      );
      await _focusAndPress(tester, LogicalKeyboardKey.enter);
      expect(taps, 1);
    });
  });
}
