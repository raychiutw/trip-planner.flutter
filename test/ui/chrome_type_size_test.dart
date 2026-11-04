/// 字階對照 Apple HIG（正文 17pt）之後，刻意維持較小字級的控制項要有釘死的守門：
/// 有人把它們改回吃 `labelLarge`／`bodyLarge`（17pt）時，chip 一排會放不下、分段控制會退成直排。
/// 為什麼維持原字級見 DESIGN.md §16.3。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_chip.dart';
import 'package:tripline/ui/tp_segmented_control.dart';
import 'package:tripline/ui/tp_tag.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

double? _sizeOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.fontSize;

void main() {
  testWidgets('TpChip、TpTag 標籤維持 15pt（不跟按鈕的 17pt）', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            TpChip(label: '緊急聯絡'),
            TpTag(label: '高風險'),
          ],
        ),
      ),
    );
    expect(_sizeOf(tester, '緊急聯絡'), 15);
    expect(_sizeOf(tester, '高風險'), 15);
  });

  testWidgets('TpSegmentedControl 標籤維持 15pt', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        // 實際畫面是撐滿內容寬（393 − 左右各 16）；Center 只給最小寬度，會一定退成直排。
        SizedBox(
          width: 361,
          child: TpSegmentedControl<String>(
            value: 'forever',
            options: const {
              'forever': '永久',
              'day': '24 小時',
              'week': '7 天',
              'month': '30 天',
              'custom': '自訂',
            },
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(_sizeOf(tester, '永久'), 15);
    // 單列與否不在這裡斷言：widget test 用 Ahem 字型（每字一個方塊），寬度不代表真機；
    // 退成直排的回歸由 share-manage 場景的重拍截圖確認（17pt 時五個選項會退成直排）。
  });
}
