import 'package:flutter/cupertino.dart' show CupertinoDatePicker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_compact_time_field.dart';

/// 記錄每個欄位回報出來的值 —— 「沒滾動就不得回寫」靠它驗。
final _startChanges = <TimeOfDay>[];
final _endChanges = <TimeOfDay>[];

class _RouteCounter extends NavigatorObserver {
  int pushed = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed += 1;
    super.didPush(route, previousRoute);
  }
}

class _Host extends StatefulWidget {
  const _Host({
    this.start,
    this.end,
    this.showEnd = false,
    this.clearable = false,
  });

  final TimeOfDay? start;
  final TimeOfDay? end;
  final bool showEnd;
  final bool clearable;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final _group = TpTimeFieldGroup();
  late TimeOfDay? _start = widget.start;
  late TimeOfDay? _end = widget.end;

  @override
  void dispose() {
    _group.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TpCompactTimeField(
          key: const ValueKey('start-field'),
          buttonKey: const ValueKey('start'),
          clearKey: const ValueKey('start-clear'),
          label: '開始',
          value: _start,
          group: _group,
          onChanged: (value) {
            _startChanges.add(value);
            setState(() => _start = value);
          },
          onCleared: widget.clearable
              ? () => setState(() => _start = null)
              : null,
        ),
        if (widget.showEnd)
          TpCompactTimeField(
            key: const ValueKey('end-field'),
            buttonKey: const ValueKey('end'),
            label: '結束',
            value: _end,
            group: _group,
            onChanged: (value) {
              _endChanges.add(value);
              setState(() => _end = value);
            },
          ),
      ],
    );
  }
}

Future<_RouteCounter> _pump(
  WidgetTester tester, {
  TimeOfDay? start = const TimeOfDay(hour: 9, minute: 0),
  TimeOfDay? end,
  bool showEnd = false,
  bool clearable = false,
  bool alwaysUse24HourFormat = false,
  double textScale = 1.0,
  ThemeData? theme,
}) async {
  final observer = _RouteCounter();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      navigatorObservers: [observer],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          alwaysUse24HourFormat: alwaysUse24HourFormat,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: _Host(
            start: start,
            end: end,
            showEnd: showEnd,
            clearable: clearable,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return observer;
}

double _wheelFontSize(WidgetTester tester) {
  final text = tester.widget<Text>(
    find
        .descendant(
          of: find.byType(CupertinoDatePicker),
          matching: find.byType(Text),
        )
        .first,
  );
  return text.style!.fontSize!;
}

void main() {
  setUp(() {
    _startChanges.clear();
    _endChanges.clear();
  });

  testWidgets('值是一顆膠囊按鈕，走品牌柔褐淡底 + 柔褐前景', (tester) async {
    final theme = AppTheme.light();
    await _pump(tester, theme: theme);

    final button = tester.widget<TextButton>(
      find.byKey(const ValueKey('start')),
    );
    expect(
      button.style!.backgroundColor!.resolve(<WidgetState>{}),
      theme.colorScheme.primaryContainer,
    );
    expect(
      button.style!.foregroundColor!.resolve(<WidgetState>{}),
      theme.colorScheme.onPrimaryContainer,
    );
    expect(button.style!.shape!.resolve(<WidgetState>{}), isA<StadiumBorder>());
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('start')),
        matching: find.text('9:00 AM'),
      ),
      findsOneWidget,
    );
    expect(find.text('開始'), findsOneWidget);
  });

  testWidgets('點膠囊在原地展開輪盤，不開任何 modal / sheet / route', (tester) async {
    final observer = await _pump(tester);
    expect(find.byType(CupertinoDatePicker), findsNothing);
    final pushedBefore = observer.pushed;
    final barriersBefore = find.byType(ModalBarrier).evaluate().length;

    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('start-field')),
        matching: find.byType(CupertinoDatePicker),
      ),
      findsOneWidget,
    );
    // 開 modal／sheet 會多推一條 route 並多一層 barrier；就地展開兩者都不變。
    expect(observer.pushed, pushedBefore);
    expect(find.byType(ModalBarrier).evaluate().length, barriersBefore);
  });

  testWidgets('再點一次收合，展開與收合都是動畫不是硬切', (tester) async {
    await _pump(tester);
    final collapsed = tester
        .getSize(find.byKey(const ValueKey('start-field')))
        .height;

    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final mid = tester
        .getSize(find.byKey(const ValueKey('start-field')))
        .height;
    await tester.pumpAndSettle();
    final expanded = tester
        .getSize(find.byKey(const ValueKey('start-field')))
        .height;

    expect(mid, greaterThan(collapsed));
    expect(mid, lessThan(expanded));

    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('start-field'))).height,
      collapsed,
    );
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });

  testWidgets('同一群組的兩顆不會同時展開', (tester) async {
    await _pump(
      tester,
      end: const TimeOfDay(hour: 11, minute: 0),
      showEnd: true,
    );

    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('end')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('end-field')),
        matching: find.byType(CupertinoDatePicker),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('start-field')),
        matching: find.byType(CupertinoDatePicker),
      ),
      findsNothing,
    );
  });

  testWidgets('展開時輪盤上方有一條 hairline 分隔線', (tester) async {
    final theme = AppTheme.light();
    await _pump(tester, theme: theme);
    expect(
      find.byKey(const ValueKey('tp-compact-time-hairline')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();

    final hairline = tester.widget<Divider>(
      find.byKey(const ValueKey('tp-compact-time-hairline')),
    );
    expect(hairline.thickness, lessThanOrEqualTo(1.0));
    expect(hairline.color, theme.colorScheme.outlineVariant);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('tp-compact-time-hairline')))
          .dy,
      lessThan(tester.getTopLeft(find.byType(CupertinoDatePicker)).dy),
    );
  });

  testWidgets('選取列走中性語意層，不鋪品牌色', (tester) async {
    final theme = AppTheme.light();
    await _pump(tester, theme: theme);
    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();

    final overlays = find.byKey(const ValueKey('tp-compact-time-selection'));
    expect(overlays, findsWidgets);
    final decoration =
        tester.widgetList<Container>(overlays).first.decoration!
            as BoxDecoration;
    final color = decoration.color!;
    expect(color, isNot(theme.colorScheme.primary));
    expect(color, isNot(theme.colorScheme.primaryContainer));
    // 中性 = RGB 三個通道相等（品牌柔褐三通道不等）。
    expect(color.r, color.g);
    expect(color.g, color.b);
  });

  testWidgets('12 小時制時輪盤跟隨系統，出現 AM／PM 欄', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.use24hFormat, isFalse);
    expect(picker.minuteInterval, 5);
    expect(find.text('AM'), findsWidgets);
  });

  testWidgets('24 小時制時輪盤跟隨系統，沒有 AM／PM 欄', (tester) async {
    await _pump(tester, alwaysUse24HourFormat: true);
    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.use24hFormat, isTrue);
    expect(find.text('AM'), findsNothing);
    expect(find.text('PM'), findsNothing);
  });

  testWidgets('輪盤起始位置 round 到 5 分鐘倍數', (tester) async {
    await _pump(tester, start: const TimeOfDay(hour: 9, minute: 7));
    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.minuteInterval, 5);
    expect(picker.initialDateTime.hour, 9);
    expect(picker.initialDateTime.minute, 5);
  });

  testWidgets('展開再收合不得靜默竄改既有值：09:07 仍是 09:07', (tester) async {
    await _pump(tester, start: const TimeOfDay(hour: 9, minute: 7));

    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();

    expect(_startChanges, isEmpty);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('start')),
        matching: find.text('9:07 AM'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('切換到另一顆而被動收合，也不得竄改既有值', (tester) async {
    await _pump(
      tester,
      start: const TimeOfDay(hour: 9, minute: 7),
      end: const TimeOfDay(hour: 11, minute: 3),
      showEnd: true,
    );

    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('end')));
    await tester.pumpAndSettle();

    expect(_startChanges, isEmpty);
    expect(_endChanges, isEmpty);
  });

  testWidgets('使用者滾動輪盤才回寫新值', (tester) async {
    await _pump(tester, start: const TimeOfDay(hour: 9, minute: 7));
    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();

    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2000, 1, 1, 10, 10));
    await tester.pumpAndSettle();

    expect(_startChanges, [const TimeOfDay(hour: 10, minute: 10)]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('start')),
        matching: find.text('10:10 AM'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('輪盤可用拖曳操作，滾動後回寫', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, -60));
    await tester.pumpAndSettle();

    expect(_startChanges, isNotEmpty);
  });

  testWidgets('Dynamic Type 放到最大級，輪盤文字與列高跟著放大且不爆版', (tester) async {
    Future<(double, double, double)> measure(double textScale) async {
      // 先卸載，否則 pumpWidget 會沿用同一個 State（連帶沿用展開狀態）。
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, textScale: textScale);
      await tester.tap(find.byKey(const ValueKey('start')));
      await tester.pumpAndSettle();
      return (
        _wheelFontSize(tester),
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .itemExtent,
        tester.getSize(find.byType(CupertinoDatePicker)).height,
      );
    }

    final (baseFont, baseExtent, baseHeight) = await measure(1.0);
    final (bigFont, bigExtent, bigHeight) = await measure(3.0);

    expect(bigFont, greaterThan(baseFont));
    expect(bigExtent, greaterThan(baseExtent));
    expect(bigHeight, greaterThan(baseHeight));
    expect(tester.takeException(), isNull);
  });

  testWidgets('VoiceOver：按鈕念得出目前值與「點兩下展開」，展開後改念收合', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    var data = tester
        .getSemantics(find.byKey(const ValueKey('start')))
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.label, contains('9:00 AM'));
    expect(data.hint, contains('點兩下展開'));

    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();
    data = tester
        .getSemantics(find.byKey(const ValueKey('start')))
        .getSemanticsData();
    expect(data.hint, contains('點兩下收合'));

    handle.dispose();
  });

  testWidgets('鍵盤可達：Tab 可 focus、空白鍵可展開', (tester) async {
    await _pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
  });

  testWidgets('清除鈕仍可把值清成未設定', (tester) async {
    await _pump(tester, clearable: true);

    await tester.tap(find.byKey(const ValueKey('start-clear')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('start')),
        matching: find.text('未設定'),
      ),
      findsOneWidget,
    );
  });
}
