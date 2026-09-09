import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/app/adaptive.dart';
import 'package:tripline/ui/tp_app_bar.dart';

void main() {
  for (final dragToReturn in [true, false]) {
    testWidgets('push 的編輯子頁取消保留草稿，${dragToReturn ? '拖曳' : '返回'}後捨棄一次回上一頁', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final guard = AppUnsavedChangesController();
      var dirty = false;
      var submitting = false;
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showAppContentSheet<void>(
                context,
                title: '帳號',
                builder: (sheetContext) => Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).push<void>(
                      MaterialPageRoute(
                        builder: (_) => StatefulBuilder(
                          builder: (context, setState) =>
                              AppUnsavedChangesGuard(
                                controller: guard,
                                hasChanges: dirty,
                                dismissalEnabled: !submitting,
                                child: Scaffold(
                                  body: Column(
                                    children: [
                                      TextField(
                                        onChanged: (_) =>
                                            setState(() => dirty = true),
                                      ),
                                      FilledButton(
                                        onPressed: submitting
                                            ? null
                                            : () async {
                                                setState(
                                                  () => submitting = true,
                                                );
                                                await pending.future;
                                                setState(
                                                  () => submitting = false,
                                                );
                                              },
                                        child: const Text('儲存'),
                                      ),
                                      FilledButton(
                                        onPressed: guard.requestPop,
                                        child: const Text('返回子頁上一層'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    child: const Text('編輯子頁'),
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
      await tester.tap(find.text('編輯子頁'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '保留子頁草稿');
      await tester.pump();
      await tester.tap(find.text('儲存'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('捨棄未儲存的變更？'), findsNothing);
      expect(find.text('保留子頁草稿'), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      final backPosition = tester.getCenter(find.text('返回子頁上一層'));
      await tester.tapAt(backPosition);
      await tester.tapAt(backPosition);
      await tester.pumpAndSettle();
      expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('保留子頁草稿'), findsOneWidget);
      final sheet = find.byKey(const ValueKey('app-large-sheet'));
      final original = tester.getRect(sheet);
      if (dragToReturn) {
        await tester.timedDragFrom(
          Offset(original.center.dx, original.top + 10),
          const Offset(0, 650),
          const Duration(milliseconds: 800),
        );
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
      await tester.tap(find.text('捨棄'));
      await tester.pumpAndSettle();
      expect(find.text('編輯子頁').hitTestable(), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.getRect(sheet), rectMoreOrLessEquals(original));
    });
  }

  testWidgets('表單確認去重且送出中拒絕拖曳外點返回，失敗保留輸入', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final form = AppSheetFormController();
    final pending = Completer<bool>();
    var submissions = 0;
    form.attach(() {
      submissions++;
      return pending.future;
    });
    addTearDown(form.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppFormSheet(
              context,
              title: '編輯',
              submitLabel: '儲存',
              controller: form,
              builder: (_) => TextField(
                onChanged: (_) => form.update(dirty: true, canSubmit: true),
              ),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '不能遺失');
    await tester.pump();
    final cancelPosition = tester.getCenter(find.text('取消'));
    await tester.tapAt(cancelPosition);
    await tester.tapAt(cancelPosition);
    await tester.pumpAndSettle();
    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(find.text('不能遺失'), findsOneWidget);
    await tester.tap(find.text('儲存'));
    await tester.tap(find.text('儲存'));
    await tester.pump();
    expect(submissions, 1);
    expect(form.isSubmitting, isTrue);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final scaffold = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    final sheet = find.byWidget(scaffold.sheet);
    final original = tester.getRect(sheet);
    await tester.timedDragFrom(
      Offset(original.center.dx, original.top + 10),
      const Offset(0, 650),
      const Duration(milliseconds: 800),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(sheet), rectMoreOrLessEquals(original));
    expect(find.text('捨棄未儲存的變更？'), findsNothing);
    expect(find.text('不能遺失'), findsOneWidget);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(form.isSubmitting, isFalse);
    expect(find.text('不能遺失'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('捨棄'));
    await tester.pumpAndSettle();
    expect(find.text('開啟').hitTestable(), findsOneWidget);
  });

  testWidgets('表單同一次上拖先展開再捲內容，收鍵盤不清草稿', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final form = AppSheetFormController();
    final draft = TextEditingController(text: '京都草稿');
    final focus = FocusNode();
    final scroll = ScrollController();
    addTearDown(form.dispose);
    addTearDown(draft.dispose);
    addTearDown(focus.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => AppKeyboardDismissRegion(child: child!),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppFormSheet(
              context,
              title: '編輯',
              submitLabel: '儲存',
              controller: form,
              builder: (_) => ListView(
                controller: scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  TextField(controller: draft, focusNode: focus),
                  for (var i = 0; i < 40; i++) ListTile(title: Text('欄位 $i')),
                ],
              ),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '保留京都草稿');
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    expect(draft.text, '保留京都草稿');
    // 捲回頂端，再從 header 收到 medium；後續上拖從內容內開始。
    await tester.drag(find.byType(ListView), const Offset(0, 200));
    await tester.pumpAndSettle();
    final scaffold = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    final sheet = find.byWidget(scaffold.sheet);
    final fullRect = tester.getRect(sheet);
    await tester.timedDragFrom(
      Offset(fullRect.center.dx, fullRect.top + 10),
      const Offset(0, 320),
      const Duration(milliseconds: 800),
    );
    await tester.pumpAndSettle();
    final halfRect = tester.getRect(sheet);
    expect(halfRect.top, greaterThan(fullRect.top));
    expect(scroll.offset, 0);
    final gesture = await tester.startGesture(
      Offset(halfRect.center.dx, halfRect.bottom - 80),
    );
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(sheet), rectMoreOrLessEquals(fullRect));
    expect(scroll.offset, greaterThan(0), reason: '同一手勢到達 large 後必須交接給清單');
    expect(draft.text, '保留京都草稿');
    expect(tester.takeException(), isNull);
  });

  testWidgets('降低動態效果時 sheet 進場不位移', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppContentSheet<void>(
              context,
              title: '帳號',
              builder: (_) => const Text('內容'),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pump();
    await tester.pump();
    final sheet = find.byKey(const ValueKey('app-large-sheet'));
    final firstFrame = tester.getRect(sheet);
    await tester.pumpAndSettle();
    expect(firstFrame, rectMoreOrLessEquals(tester.getRect(sheet)));
  });

  for (final contentSheet in [false, true]) {
    testWidgets(
      '拖曳關閉 ${contentSheet ? 'content' : 'screen'} sheet 仍先確認子頁草稿且拒絕後復位',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final guard = AppUnsavedChangesController();
        Widget content(BuildContext context) => AppUnsavedChangesGuard(
          controller: guard,
          hasChanges: true,
          child: const Scaffold(body: Text('尚未儲存的草稿')),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => FilledButton(
                onPressed: () => contentSheet
                    ? showAppContentSheet<void>(
                        context,
                        title: '帳號',
                        builder: content,
                      )
                    : showAppScreenSheet<void>(context, builder: content),
                child: const Text('開啟'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('開啟'));
        await tester.pumpAndSettle();
        final sheet = find.byKey(
          ValueKey(contentSheet ? 'app-large-sheet' : 'app-large-screen-sheet'),
        );
        final original = tester.getRect(sheet);
        await tester.timedDragFrom(
          Offset(original.center.dx, original.top + 10),
          const Offset(0, 650),
          const Duration(milliseconds: 800),
        );
        await tester.pumpAndSettle();
        expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(tester.getRect(sheet), rectMoreOrLessEquals(original));
        expect(find.text('尚未儲存的草稿').hitTestable(), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.text('捨棄'));
        await tester.pumpAndSettle();
        expect(find.text('開啟').hitTestable(), findsOneWidget);
      },
    );
  }

  testWidgets('固定 sheet 採公開預設幾何且長清單可捲至末項', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: GlassModalSheetScaffold(
          body: const SizedBox.expand(),
          sheet: const SizedBox.expand(key: ValueKey('reference-sheet')),
          initialState: GlassSheetState.full,
          detents: {GlassSheetDetent.large},
          showDragIndicator: false,
          padding: EdgeInsets.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final reference = tester.getRect(
      find.byKey(const ValueKey('reference-sheet')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppContentSheet<void>(
              context,
              title: '帳號',
              builder: (_) => ListView.builder(
                itemCount: 50,
                itemBuilder: (_, i) => ListTile(title: Text('設定 $i')),
              ),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('app-large-sheet'))),
      reference,
    );
    await tester.scrollUntilVisible(find.text('設定 49'), 400);
    expect(find.text('設定 49').hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-sheet-close')));
    await tester.pumpAndSettle();
    expect(find.text('開啟').hitTestable(), findsOneWidget);
  });

  testWidgets('large sheet uses the opaque Reduce Transparency fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppAccessibilityScope(
        reduceTransparency: true,
        child: MaterialApp(
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
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    final settings = tester
        .widget<GlassModalSheetScaffold>(find.byType(GlassModalSheetScaffold))
        .settings!;
    expect(settings.glassColor.a, 1);
    expect(settings.backerColor?.a, 1);
    expect(settings.platformViewFallbackColor?.a, 1);
    expect(settings.blur, 0);
    expect(settings.thickness, 0);
    expect(settings.refractiveIndex, 1);
  });

  testWidgets('共用鍵盤區域可點外部或拖曳收合，且保留草稿', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppKeyboardDismissRegion(
          child: Scaffold(
            body: ListView(
              children: [
                TextField(
                  key: const ValueKey('keyboard-field'),
                  controller: controller,
                  focusNode: focusNode,
                ),
                TextFieldTapRegion(
                  child: IconButton(
                    key: const ValueKey('field-accessory'),
                    onPressed: () {},
                    icon: const Icon(Icons.mic_none),
                  ),
                ),
                const SizedBox(
                  key: ValueKey('outside-area'),
                  height: 800,
                  child: Text('欄位外'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('keyboard-field')));
    await tester.enterText(find.byType(TextField), '未送出的草稿');
    await tester.tap(find.byKey(const ValueKey('field-accessory')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('欄位外'));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
    expect(controller.text, '未送出的草稿');

    await tester.tap(find.byKey(const ValueKey('keyboard-field')));
    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
    expect(controller.text, '未送出的草稿');
  });

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
    expect(sheet.showDragIndicator, isFalse);
    expect(
      sheet.expandedColor,
      Theme.of(tester.element(find.text('東京五日行'))).colorScheme.surface,
    );

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
    expect(sheet.showDragIndicator, isFalse);
    expect(
      sheet.expandedColor,
      Theme.of(tester.element(find.text('帳號內容'))).colorScheme.surface,
    );
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
    expect(
      sheet.expandedColor,
      Theme.of(tester.element(find.text('帳號內容'))).colorScheme.surface,
    );
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

  testWidgets('regular content sheet Close 不會繞過子頁未儲存保護', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = AppUnsavedChangesController();

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
                    builder: (_) => AppUnsavedChangesGuard(
                      controller: controller,
                      hasChanges: true,
                      child: const Scaffold(
                        appBar: TpAppBar(
                          role: TpAppBarRole.detail,
                          title: Text('編輯個人資料'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('編輯'),
              ),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編輯'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();

    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
    expect(find.text('編輯個人資料'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app-regular-content-sheet')),
      findsOneWidget,
    );
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
    final sheet = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    expect(sheet.showDragIndicator, isTrue);
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
    expect(
      tester
          .widget<GlassModalSheetScaffold>(find.byType(GlassModalSheetScaffold))
          .showDragIndicator,
      isFalse,
    );
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
