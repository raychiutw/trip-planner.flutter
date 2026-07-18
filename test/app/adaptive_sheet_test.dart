import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/adaptive.dart';

void main() {
  testWidgets('selection sheet has Cancel, no Done, and distinct detents', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showAppSelectionSheet<String>(
                context,
                title: '切換行程',
                builder: (sheetContext, select) => ListTile(
                  title: const Text('東京五日行'),
                  onTap: () => select('trip-1'),
                ),
              );
            },
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsNothing);
    final sheet = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    expect(sheet.initialState, GlassSheetState.full);
    expect(sheet.halfSize, 0.62);
    expect(sheet.fullSize, 0.93);
    expect(sheet.showDragIndicator, isTrue);

    await tester.tap(find.text('東京五日行'));
    await tester.pumpAndSettle();
    expect(result, 'trip-1');
  });

  testWidgets('fixed content sheet has Close and no resize grabber', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppContentSheet<void>(
              context,
              title: '帳號',
              builder: (_) => const Text('帳號內容'),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-sheet-close')), findsOneWidget);
    final sheet = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    expect(sheet.halfSize, 0.93);
    expect(sheet.fullSize, 0.93);
    expect(sheet.showDragIndicator, isFalse);
  });

  testWidgets('dirty form asks before Cancel and stays open when kept', (
    tester,
  ) async {
    final controller = AppSheetFormController();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppFormSheet(
              context,
              title: '編輯停留點',
              submitLabel: '儲存',
              controller: controller,
              builder: (_) => TextField(
                onChanged: (_) =>
                    controller.update(dirty: true, canSubmit: true),
              ),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '京都');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(find.text('編輯停留點'), findsOneWidget);
  });
}
