import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/app/adaptive.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('表單慢拖放手後${reduced ? '直接停穩' : '保留吸附動畫'}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final form = AppSheetFormController();
      addTearDown(form.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showAppFormSheet(
                context,
                title: '編輯',
                submitLabel: '儲存',
                controller: form,
                builder: (_) => const SizedBox.expand(key: ValueKey('表單內容')),
              ),
              child: const Text('開啟'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開啟'));
      await tester.pumpAndSettle();
      final content = find.byKey(const ValueKey('表單內容'));
      final initial = tester.getTopLeft(content).dy;
      expect(MediaQuery.disableAnimationsOf(tester.element(content)), reduced);
      final title = tester.getRect(find.text('編輯'));
      final gesture = await tester.startGesture(
        Offset(title.center.dx, title.top - 10),
      );
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.getTopLeft(content).dy, greaterThan(initial + 20));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final firstFrame = tester.getTopLeft(content).dy;
      await tester.pump(const Duration(milliseconds: 160));
      final laterFrame = tester.getTopLeft(content).dy;
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(content).dy, closeTo(initial, 0.01));
      if (reduced) {
        expect(firstFrame, closeTo(initial, 0.01), reason: '放手下一幀直接到達停穩位置');
        expect(laterFrame, closeTo(initial, 0.01));
      } else {
        expect(firstFrame, isNot(closeTo(initial, 0.01)));
        expect(laterFrame, lessThan(firstFrame));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('降低動態效果時 medium sheet 按住及放手不縮放', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final form = AppSheetFormController();
    addTearDown(form.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppFormSheet(
              context,
              title: '編輯',
              submitLabel: '儲存',
              controller: form,
              builder: (_) => const SizedBox.expand(key: ValueKey('表單內容')),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    final content = find.byKey(const ValueKey('表單內容'));
    final full = tester.getRect(content);
    final title = tester.getRect(find.text('編輯'));
    await tester.timedDragFrom(
      Offset(title.center.dx, title.top - 10),
      const Offset(0, 320),
      const Duration(milliseconds: 800),
    );
    await tester.pumpAndSettle();
    final half = tester.getRect(content);
    expect(half.top, greaterThan(full.top + 100));
    final gesture = await tester.startGesture(tester.getCenter(content));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getRect(content), rectMoreOrLessEquals(half));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getRect(content), rectMoreOrLessEquals(half));
    await tester.pumpAndSettle();
    expect(tester.getRect(content), rectMoreOrLessEquals(half));
    final mediumTitle = tester.getRect(find.text('編輯'));
    await tester.timedDragFrom(
      Offset(mediumTitle.center.dx, mediumTitle.top - 10),
      const Offset(0, -60),
      const Duration(milliseconds: 800),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.getRect(content),
      rectMoreOrLessEquals(half),
      reason: '短上拖回到 medium 後也不殘留伸縮回彈',
    );
  });

  testWidgets('降低動態效果仍可拖到 medium 再上拖至 large，下一幀即停穩', (tester) async {
    await _openReducedMotionForm(tester);
    final content = find.byKey(const ValueKey('動態內容'));
    final full = tester.getRect(content);
    for (final dy in [320.0, -230.0]) {
      final title = tester.getRect(find.text('編輯'));
      await tester.timedDragFrom(
        Offset(title.center.dx, title.top - 10),
        Offset(0, dy),
        const Duration(milliseconds: 800),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final firstFrame = tester.getRect(content);
      await tester.pumpAndSettle();
      expect(firstFrame, rectMoreOrLessEquals(tester.getRect(content)));
      if (dy > 0) {
        expect(firstFrame.top, greaterThan(full.top + 100));
      } else {
        expect(firstFrame, rectMoreOrLessEquals(full));
      }
    }
  });

  testWidgets('降低動態效果的 focus 展開與旋轉直接停穩並保留草稿', (tester) async {
    final draft = TextEditingController(text: '京都草稿');
    addTearDown(draft.dispose);
    await _openReducedMotionForm(
      tester,
      child: ListView(children: [TextField(controller: draft)]),
    );
    final content = find.byKey(const ValueKey('動態內容'));
    final full = tester.getRect(content);
    final title = tester.getRect(find.text('編輯'));
    await tester.timedDragFrom(
      Offset(title.center.dx, title.top - 10),
      const Offset(0, 320),
      const Duration(milliseconds: 800),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(content).top, greaterThan(full.top + 100));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getRect(content), rectMoreOrLessEquals(full));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final withKeyboard = tester.getRect(content);
    await tester.pumpAndSettle();
    expect(tester.getRect(content), rectMoreOrLessEquals(withKeyboard));
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final rotated = tester.getRect(content);
    await tester.pumpAndSettle();
    expect(tester.getRect(content), rectMoreOrLessEquals(rotated));
    expect(rotated.width, greaterThan(full.width));
    expect(find.text('京都草稿'), findsOneWidget);
    expect(
      tester
          .widget<GlassModalSheetScaffold>(find.byType(GlassModalSheetScaffold))
          .controller!
          .currentState,
      GlassSheetState.full,
    );
    expect(MediaQuery.viewInsetsOf(tester.element(content)), EdgeInsets.zero);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<GlassModalSheetScaffold>(find.byType(GlassModalSheetScaffold))
          .controller!
          .currentState,
      GlassSheetState.full,
    );
    expect(MediaQuery.viewInsetsOf(tester.element(content)), EdgeInsets.zero);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(
      rotated,
      rectMoreOrLessEquals(tester.getRect(content)),
      reason: '旋轉後 large 與相同尺寸重新開啟的 large 使用同一停留位置',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('降低動態效果保留多指與取消拖曳，下一次操作仍可停穩', (tester) async {
    await _openReducedMotionForm(tester);
    final content = find.byKey(const ValueKey('動態內容'));
    final original = tester.getRect(content);
    final title = tester.getRect(find.text('編輯'));
    final start = Offset(title.center.dx, title.top - 10);
    final first = await tester.startGesture(start, pointer: 1);
    await first.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 100));
    final dragged = tester.getRect(content);
    expect(dragged.top, greaterThan(original.top + 20));
    final second = await tester.startGesture(
      start + const Offset(20, 60),
      pointer: 2,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(content), rectMoreOrLessEquals(dragged));
    await second.cancel();
    await first.cancel();
    await tester.pumpAndSettle();
    expect(tester.getRect(content), rectMoreOrLessEquals(dragged));
    final newTitle = tester.getRect(find.text('編輯'));
    final next = await tester.startGesture(
      Offset(newTitle.center.dx, newTitle.top - 10),
    );
    await next.moveBy(const Offset(0, -20));
    await tester.pump(const Duration(milliseconds: 100));
    await next.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getRect(content), rectMoreOrLessEquals(original));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('開啟').hitTestable(), findsOneWidget);
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    expect(tester.getRect(content), rectMoreOrLessEquals(original));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet 開啟中切換降低動態效果，可立即取消並恢復吸附動畫', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final reduced = ValueNotifier(false);
    final form = AppSheetFormController();
    addTearDown(reduced.dispose);
    addTearDown(form.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: reduced,
          builder: (context, value, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: value),
            child: child!,
          ),
          child: child,
        ),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppFormSheet(
              context,
              title: '編輯',
              submitLabel: '儲存',
              controller: form,
              builder: (_) => const SizedBox.expand(key: ValueKey('動態內容')),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    final content = find.byKey(const ValueKey('動態內容'));
    final initial = tester.getTopLeft(content).dy;
    for (final setting in [false, true, false]) {
      reduced.value = setting;
      await tester.pumpAndSettle();
      expect(MediaQuery.disableAnimationsOf(tester.element(content)), setting);
      final title = tester.getRect(find.text('編輯'));
      final gesture = await tester.startGesture(
        Offset(title.center.dx, title.top - 10),
      );
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.getTopLeft(content).dy, greaterThan(initial + 20));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getTopLeft(content).dy,
        setting ? closeTo(initial, 0.01) : isNot(closeTo(initial, 0.01)),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(content).dy, closeTo(initial, 0.01));
    }
    expect(tester.takeException(), isNull);
  });

  for (final (dragToReturn, reduced) in [
    (true, false),
    (false, false),
    (true, true),
    (false, true),
  ]) {
    testWidgets(
      'push 的編輯子頁取消保留草稿，${dragToReturn ? '拖曳' : '返回'}後捨棄一次回上一頁（降低動態效果=$reduced）',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final guard = AppUnsavedChangesController();
        var dirty = false;
        var submitting = false;
        final pending = Completer<void>();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
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
      },
    );
  }

  for (final reduced in [false, true]) {
    testWidgets('表單確認去重且送出中拒絕拖曳外點返回，失敗保留輸入（降低動態效果=$reduced）', (tester) async {
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduced,
              // large 停在狀態列之下；外點要落在狀態列帶才真的在 sheet 外。
              padding: const EdgeInsets.only(top: 47),
              viewPadding: const EdgeInsets.only(top: 47),
            ),
            child: child!,
          ),
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
      final scaffold = tester.widget<GlassModalSheetScaffold>(
        find.byType(GlassModalSheetScaffold),
      );
      final sheet = find.byWidget(scaffold.sheet);
      final original = tester.getRect(sheet);
      expect(original.top, greaterThan(20), reason: '外點座標必須在 sheet 之外');
      await tester.tapAt(const Offset(10, 20));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
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
  }

  for (final reduced in [false, true]) {
    testWidgets('表單同一次上拖先展開再捲內容，收鍵盤不清草稿（降低動態效果=$reduced）', (tester) async {
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: AppKeyboardDismissRegion(child: child!),
          ),
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
  }

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

  testWidgets('固定 sheet 頂緣停在狀態列下方溝槽且長清單可捲至末項', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 47, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
          ),
          child: child!,
        ),
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
    final sheet = tester.getRect(find.byKey(const ValueKey('app-large-sheet')));
    // 接近全高：保留狀態列，頂緣只留一道小溝槽；不沿用套件寫死的 90pt。
    expect(sheet.top, greaterThanOrEqualTo(47));
    expect(sheet.top, lessThanOrEqualTo(47 + 12));
    expect(sheet.bottom, greaterThanOrEqualTo(844));
    await tester.scrollUntilVisible(find.text('設定 49'), 400);
    expect(find.text('設定 49').hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-sheet-close')));
    await tester.pumpAndSettle();
    expect(find.text('開啟').hitTestable(), findsOneWidget);
  });

  for (final reduced in [false, true]) {
    testWidgets('固定 sheet 旋轉後依新 safe area 重取接近全高（降低動態效果=$reduced）', (
      tester,
    ) async {
      // 先橫向開啟：狀態列收起、safe area 在左右；轉回直向時若沿用橫向算出的
      // 絕對高度，sheet 會停在畫面中段，才分得出有沒有重取。
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final safeArea = ValueNotifier(
        const EdgeInsets.only(left: 47, right: 47, bottom: 21),
      );
      addTearDown(safeArea.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ValueListenableBuilder(
            valueListenable: safeArea,
            builder: (context, padding, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: padding,
                viewPadding: padding,
                disableAnimations: reduced,
              ),
              child: child!,
            ),
          ),
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
      final sheet = find.byKey(const ValueKey('app-large-sheet'));
      final landscape = tester.getRect(sheet);
      expect(landscape.top, greaterThanOrEqualTo(0));
      expect(landscape.top, lessThanOrEqualTo(12));
      expect(landscape.bottom, greaterThanOrEqualTo(390));

      tester.view.physicalSize = const Size(390, 844);
      safeArea.value = const EdgeInsets.only(top: 47, bottom: 34);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final secondFrame = tester.getRect(sheet);
      await tester.pumpAndSettle();
      final portrait = tester.getRect(sheet);
      expect(portrait.top, greaterThanOrEqualTo(47));
      expect(portrait.top, lessThanOrEqualTo(47 + 12));
      expect(portrait.bottom, greaterThanOrEqualTo(844));
      expect(portrait.width, closeTo(390, 0.5));
      if (reduced) {
        expect(
          secondFrame,
          rectMoreOrLessEquals(portrait),
          reason: '降低動態效果下一幀即停穩',
        );
      }
      expect(find.text('帳號內容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final resizable in [false, true]) {
    testWidgets('${resizable ? '表單' : '選擇'} sheet 的 large 同樣停在狀態列下方，'
        '${resizable ? 'medium 維持套件預設且可來回' : '關閉仍走取消'}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final form = AppSheetFormController();
      addTearDown(form.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 47, bottom: 34),
              viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => resizable
                  ? showAppFormSheet(
                      context,
                      title: '編輯',
                      submitLabel: '儲存',
                      controller: form,
                      builder: (_) => const Center(child: Text('共用內容')),
                    )
                  : showAppSelectionSheet<int>(
                      context,
                      title: '選擇',
                      builder: (_, _) => const Center(child: Text('共用內容')),
                    ),
              child: const Text('開啟'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開啟'));
      await tester.pumpAndSettle();
      final scaffold = tester.widget<GlassModalSheetScaffold>(
        find.byType(GlassModalSheetScaffold),
      );
      final sheet = find.byWidget(scaffold.sheet);
      final large = tester.getRect(sheet);
      expect(large.top, greaterThanOrEqualTo(47));
      expect(large.top, lessThanOrEqualTo(47 + 12));
      expect(large.bottom, greaterThanOrEqualTo(844));
      expect(find.text('共用內容').hitTestable(), findsOneWidget);
      if (resizable) {
        // medium 仍是套件預設的 45%：只有 large 的停留高度換了來源。
        final title = tester.getRect(find.text('編輯'));
        await tester.timedDragFrom(
          Offset(title.center.dx, title.top - 10),
          const Offset(0, 320),
          const Duration(milliseconds: 800),
        );
        await tester.pumpAndSettle();
        final medium = tester.getRect(sheet);
        expect(medium.top, closeTo(844 * (1 - 0.45), 1));
        await tester.timedDragFrom(
          Offset(medium.center.dx, medium.top + 10),
          const Offset(0, -320),
          const Duration(milliseconds: 800),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(sheet), rectMoreOrLessEquals(large));
      }
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('開啟').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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

  // #319 真機（iPhone 14 Pro／iOS 16.6）：深色 sheet 沿用 base `surface` 黑，
  // 落在黑頁面上沒有可辨識邊界；參考影片是 iOS elevated 深灰面板。
  // 依 iOS base／elevated 語意，sheet 內把深色 surface 三階整體上移一階，
  // 淺色維持不變；grouped 卡片因此仍比底色高一階。
  for (final (label, theme) in [
    ('淺色', AppTheme.light()),
    ('深色', AppTheme.dark()),
  ]) {
    testWidgets('$label content sheet 採 elevated 語意層級並保留 grouped 層次', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
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

      final outer = theme.colorScheme;
      final inner = Theme.of(tester.element(find.text('帳號內容'))).colorScheme;
      final sheet = tester.widget<GlassModalSheetScaffold>(
        find.byType(GlassModalSheetScaffold),
      );
      final isDark = theme.brightness == Brightness.dark;
      expect(sheet.expandedColor, inner.surface, reason: '底色跟隨內容語意 surface');
      expect(
        sheet.expandedColor,
        isDark ? outer.surfaceContainerLow : outer.surface,
        reason: isDark ? '深色 sheet 是 elevated 深灰，不是 base 黑' : '淺色不變',
      );
      expect(
        inner.surfaceContainerLow,
        isDark ? outer.surfaceContainerHigh : outer.surfaceContainerLow,
        reason: 'grouped 卡片仍比 sheet 底色高一階',
      );
      expect(
        inner.surfaceContainerHigh,
        isDark ? outer.surfaceContainerHighest : outer.surfaceContainerHigh,
      );
      expect(inner.onSurface, outer.onSurface, reason: '前景色不變');
    });
  }

  testWidgets('selection sheet 與 content sheet 共用同一個 elevated 層級', (
    tester,
  ) async {
    final theme = AppTheme.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppSelectionSheet<String>(
              context,
              title: '切換行程',
              builder: (_, _) => const Text('東京五日行'),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    final outer = theme.colorScheme;
    final inner = Theme.of(tester.element(find.text('東京五日行'))).colorScheme;
    final sheet = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    expect(sheet.expandedColor, outer.surfaceContainerLow);
    expect(inner.surface, outer.surfaceContainerLow, reason: '內容與底色同一層級');
    expect(
      inner.surfaceContainerLow,
      outer.surfaceContainerHigh,
      reason: '只上移一階，不重複套用',
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

Future<void> _openReducedMotionForm(
  WidgetTester tester, {
  Widget? child,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final form = AppSheetFormController();
  addTearDown(form.dispose);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Builder(
        builder: (context) => FilledButton(
          onPressed: () => showAppFormSheet(
            context,
            title: '編輯',
            submitLabel: '儲存',
            controller: form,
            builder: (_) =>
                SizedBox.expand(key: const ValueKey('動態內容'), child: child),
          ),
          child: const Text('開啟'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('開啟'));
  await tester.pumpAndSettle();
}
