import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/ui/swipe_to_delete.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  testWidgets('SwipeToDelete：左滑觸發 onDelete,return false 保留 child', (
    tester,
  ) async {
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SwipeToDelete(
            dismissKey: const ValueKey('swipe-1'),
            onDelete: () async => deleted++,
            child: const SizedBox(height: 60, child: Text('row')),
          ),
        ),
      ),
    );

    final deleteSemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .singleWhere(
          (widget) =>
              widget.properties.customSemanticsActions?.keys.any(
                (action) => action.label == '刪除',
              ) ??
              false,
        );
    deleteSemantics.properties.customSemanticsActions!.values.single();
    await tester.pump();
    expect(deleted, 1);
    deleted = 0;

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('row')),
    );
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();

    expect(find.text('刪除'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.delete), findsOneWidget);

    await gesture.moveBy(const Offset(-320, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(deleted, 1);
    expect(
      find.text('row'),
      findsOneWidget,
    ); // return false → child 仍在,靠 invalidate 移除
  });
}
