import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/ui/swipe_to_delete.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  testWidgets('SwipeToDelete 左滑只揭露按鈕，點擊才刪除', (tester) async {
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SwipeToDelete(
            dismissKey: const ValueKey('swipe-1'),
            onDelete: () async => deleted++,
            child: const SizedBox(
              width: double.infinity,
              height: 60,
              child: Text('row'),
            ),
          ),
        ),
      ),
    );

    final row = find.byKey(const ValueKey('swipe-1'));
    final rowContent = find.text('row');
    final initialLeft = tester.getTopLeft(rowContent).dx;

    await tester.drag(row, const Offset(-20, 0));
    await tester.pumpAndSettle();
    expect(deleted, 0);
    expect(tester.getTopLeft(rowContent).dx, initialLeft);

    await tester.drag(row, const Offset(-320, 0));
    await tester.pumpAndSettle();

    expect(find.text('刪除'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.delete), findsOneWidget);
    expect(deleted, 0);
    expect(tester.getTopLeft(rowContent).dx, closeTo(initialLeft - 92, 0.5));

    await tester.tap(
      find.byKey(
        const ValueKey<Object>(('swipe-delete-action', ValueKey('swipe-1'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(deleted, 1);
    expect(find.text('row'), findsOneWidget);
    expect(tester.getTopLeft(rowContent).dx, initialLeft);
  });

  testWidgets('SwipeToDelete 保留 VoiceOver 刪除 action', (tester) async {
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SwipeToDelete(
            dismissKey: const ValueKey('swipe-semantics'),
            onDelete: () async => deleted++,
            child: const SizedBox(
              width: double.infinity,
              height: 60,
              child: Text('row'),
            ),
          ),
        ),
      ),
    );

    final semantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .singleWhere(
          (widget) =>
              widget.properties.customSemanticsActions?.keys.any(
                (action) => action.label == '刪除',
              ) ??
              false,
        );
    final callback = semantics.properties.customSemanticsActions!.values.single;
    callback();
    await tester.pumpAndSettle();

    expect(deleted, 1);
  });

  testWidgets('同組只保留一列展開', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SlidableAutoCloseBehavior(
          child: Scaffold(
            body: Column(
              children: [
                for (var index = 1; index <= 2; index++)
                  SwipeToDelete(
                    dismissKey: ValueKey('swipe-$index'),
                    onDelete: () async {},
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: Text('row-$index'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final firstLeft = tester.getTopLeft(find.text('row-1')).dx;
    final secondLeft = tester.getTopLeft(find.text('row-2')).dx;
    await tester.drag(
      find.byKey(const ValueKey('swipe-1')),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('row-1')).dx, firstLeft - 92);

    await tester.drag(
      find.byKey(const ValueKey('swipe-2')),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('row-1')).dx, firstLeft);
    expect(tester.getTopLeft(find.text('row-2')).dx, secondLeft - 92);
  });

  testWidgets('列表開始垂直捲動時收合', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SlidableAutoCloseBehavior(
          child: Scaffold(
            body: ListView(
              children: [
                for (var index = 1; index <= 20; index++)
                  SwipeToDelete(
                    dismissKey: ValueKey('swipe-$index'),
                    onDelete: () async {},
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: Text('row-$index'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final firstLeft = tester.getTopLeft(find.text('row-1')).dx;
    await tester.drag(
      find.byKey(const ValueKey('swipe-1')),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('row-1')).dx, firstLeft - 92);

    await tester.drag(find.byType(ListView), const Offset(0, -20));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('row-1')).dx, firstLeft);
  });
}
