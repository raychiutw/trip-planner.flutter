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

    await tester.drag(find.text('row'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(deleted, 1);
    expect(
      find.text('row'),
      findsOneWidget,
    ); // return false → child 仍在,靠 invalidate 移除
  });
}
