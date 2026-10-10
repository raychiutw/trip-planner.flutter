import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';
import 'package:tripline/ui/tp_segmented_control.dart';

/// #422:AX 字級下分段控制與大標題不得被截斷(不縮字)。
Widget _host(Widget child, {required double scale}) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  const labels = {
    'forever': '永久',
    'd1': '24 小時',
    'd7': '7 天',
    'd30': '30 天',
    'custom': '自訂',
  };

  for (final scale in [2.0, 3.0]) {
    testWidgets('TpSegmentedControl 在 $scale 倍字級每個選項都可見可點', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String value = 'forever';
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => TpSegmentedControl<String>(
              value: value,
              options: labels,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();

      final screen = tester.view.physicalSize;
      for (final label in labels.values) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(screen.width), reason: label);
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(label))
              .didExceedMaxLines,
          isFalse,
          reason: '$label 不得被截斷',
        );
      }
      expect(find.byType(FittedBox), findsNothing);
      for (final entry in labels.entries) {
        await tester.tap(find.text(entry.value));
        await tester.pumpAndSettle();
        expect(value, entry.key, reason: '${entry.value} 要點得到');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TpSegmentedControl 在水平捲動容器(無限寬)內 3.0 倍字級也全部可見', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: TpSegmentedControl<String>(
            value: 'forever',
            options: labels,
            onChanged: (_) {},
          ),
        ),
        scale: 3,
      ),
    );
    await tester.pumpAndSettle();
    for (final label in labels.values) {
      expect(
        tester.getRect(find.text(label)).right,
        lessThanOrEqualTo(393),
        reason: label,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('一般字級維持單列並排', (tester) async {
    await tester.pumpWidget(
      _host(
        TpSegmentedControl<String>(
          value: 'forever',
          options: const {'forever': '永久', 'd1': '24 小時'},
          onChanged: (_) {},
        ),
        scale: 1,
      ),
    );
    expect(
      tester.getCenter(find.text('永久')).dy,
      tester.getCenter(find.text('24 小時')).dy,
    );
  });

  testWidgets('root 大標題在 3.0 倍字級不被截成半截', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(393, 852),
            textScaler: TextScaler.linear(3),
          ),
          child: TpRootScaffold(
            header: TpRootHeaderConfig(title: Text('我的行程')),
            body: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    final title = find.text('我的行程');
    final paragraph = tester.renderObject<RenderParagraph>(title);
    expect(paragraph.didExceedMaxLines, isFalse);
    // header 內容列固定 44pt:標題高度必須放得進去,否則會被上下裁掉。
    expect(
      paragraph.getMaxIntrinsicHeight(double.infinity),
      lessThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });
}
