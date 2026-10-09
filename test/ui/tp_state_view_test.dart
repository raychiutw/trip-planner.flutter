import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/ui/tp_state_view.dart';

import '../helpers/semantics_flags.dart';

void main() {
  testWidgets('loading 狀態與 TpLoadingIndicator 是 liveRegion 且帶名稱', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: TpStateView(kind: TpStateKind.loading, title: '正在載入'),
              ),
              Expanded(child: TpLoadingIndicator(label: '正在載入地圖')),
            ],
          ),
        ),
      ),
    );

    expect(tester.isLiveRegionOf(find.text('正在載入')), isTrue);
    expect(find.bySemanticsLabel('正在載入地圖'), findsOneWidget);
    expect(tester.isLiveRegionOf(find.bySemanticsLabel('正在載入地圖')), isTrue);
    handle.dispose();
  });

  testWidgets('error 狀態不自帶 liveRegion（避免與呼叫端重複朗讀）', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TpStateView(kind: TpStateKind.error, title: '載入失敗'),
        ),
      ),
    );
    expect(tester.isLiveRegionOf(find.text('載入失敗')), isFalse);
    handle.dispose();
  });
}
