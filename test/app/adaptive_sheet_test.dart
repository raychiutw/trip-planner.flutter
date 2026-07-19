import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/adaptive.dart';
import 'package:tripline/ui/tp_app_bar.dart';

void main() {
  testWidgets('selection sheet has Cancel, no Done, and one fixed detent', (
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
    expect(sheet.halfSize, 0.93);
    expect(sheet.fullSize, 0.93);
    expect(sheet.showDragIndicator, isFalse);
    expect(sheet.fillThreshold, 0.85);
    expect(sheet.fullSettings, isNull);
    expect(sheet.expandedColor, const Color(0xFFFFFBF5));

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
    expect(sheet.fillThreshold, 0.85);
    expect(sheet.fullSettings, isNull);
    expect(sheet.expandedColor, const Color(0xFFFFFBF5));
  });

  testWidgets('fixed content sheet uses a neutral opaque dark canvas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
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

    final sheet = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    expect(sheet.fillThreshold, 0.85);
    expect(sheet.fullSettings, isNull);
    expect(sheet.expandedColor, const Color(0xFF1C1C1E));
  });

  testWidgets('system Back returns from a nested content-sheet page first', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppContentSheet<void>(
              context,
              title: '帳號',
              builder: (sheetContext) => FilledButton(
                onPressed: () => Navigator.of(sheetContext).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('外觀設定')),
                  ),
                ),
                child: const Text('外觀'),
              ),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('外觀'));
    await tester.pumpAndSettle();
    expect(find.text('外觀設定'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('外觀設定'), findsNothing);
    expect(find.text('帳號'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-sheet-close')), findsOneWidget);
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

  testWidgets('dirty form asks before system Back', (tester) async {
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
              builder: (_) =>
                  TextField(onChanged: (_) => controller.update(dirty: true)),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '京都');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
    expect(find.text('編輯停留點'), findsOneWidget);
  });

  testWidgets('dirty routed form asks before explicit Cancel', (tester) async {
    final controller = AppUnsavedChangesController();
    await tester.pumpWidget(
      MaterialApp(
        home: AppUnsavedChangesGuard(
          controller: controller,
          hasChanges: true,
          child: Scaffold(
            body: FilledButton(
              onPressed: controller.requestPop,
              child: const Text('取消'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
  });

  testWidgets(
    'screen sheet honors a dirty child guard when system Back is pressed',
    (tester) async {
      final controller = AppUnsavedChangesController();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showAppScreenSheet<void>(
                context,
                builder: (_) => AppUnsavedChangesGuard(
                  controller: controller,
                  hasChanges: true,
                  child: const Scaffold(body: Text('編輯行程')),
                ),
              ),
              child: const Text('開啟'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('開啟'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
      expect(find.text('編輯行程'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('app-large-screen-sheet')),
        findsOneWidget,
      );
    },
  );

  testWidgets('screen sheet root detail Back closes the whole sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppScreenSheet<void>(
              context,
              builder: (_) => const Scaffold(
                appBar: TpAppBar(
                  role: TpAppBarRole.detail,
                  title: Text('行程筆記'),
                ),
              ),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
    await tester.pumpAndSettle();

    expect(find.text('行程筆記'), findsNothing);
    expect(find.byKey(const ValueKey('app-large-screen-sheet')), findsNothing);
  });

  testWidgets('screen sheet detail Back honors a dirty child guard', (
    tester,
  ) async {
    final controller = AppUnsavedChangesController();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppScreenSheet<void>(
              context,
              builder: (_) => AppUnsavedChangesGuard(
                controller: controller,
                hasChanges: true,
                child: const Scaffold(
                  appBar: TpAppBar(
                    role: TpAppBarRole.detail,
                    title: Text('編輯行程'),
                  ),
                ),
              ),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
    await tester.pumpAndSettle();

    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
    expect(find.text('編輯行程'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app-large-screen-sheet')),
      findsOneWidget,
    );
  });

  testWidgets('routed form cannot dismiss while submission is active', (
    tester,
  ) async {
    final controller = AppUnsavedChangesController();
    var submitting = true;
    late StateSetter updateHost;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return AppUnsavedChangesGuard(
              controller: controller,
              hasChanges: true,
              dismissalEnabled: !submitting,
              child: Scaffold(
                body: FilledButton(
                  onPressed: controller.requestPop,
                  child: const Text('取消'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('捨棄未儲存的變更？'), findsNothing);

    updateHost(() => submitting = false);
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
  });
}
