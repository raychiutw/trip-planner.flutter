import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/adaptive_content.dart';

void main() {
  Future<void> setWindowSize(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
  }

  testWidgets('寬螢幕內容置中且不超過指定寬度', (tester) async {
    await setWindowSize(tester, const Size(1200, 800));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppAdaptiveContent(
            maxWidth: AppContentWidth.form,
            contentKey: ValueKey('content'),
            child: ColoredBox(color: Colors.red),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('content'))).width, 720);
    expect(tester.getTopLeft(find.byKey(const ValueKey('content'))).dx, 240);
  });

  testWidgets('手機內容維持全寬', (tester) async {
    await setWindowSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppAdaptiveContent(
            maxWidth: AppContentWidth.form,
            contentKey: ValueKey('content'),
            child: ColoredBox(color: Colors.red),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('content'))).width, 390);
    expect(tester.getTopLeft(find.byKey(const ValueKey('content'))).dx, 0);
  });
}
