import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/adaptive.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_action_item.dart';
import 'package:tripline/ui/tp_app_bar.dart';

void main() {
  testWidgets('standalone app bar never implies a leading action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: TpAppBar(role: TpAppBarRole.standalone, title: Text('邀請')),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(find.byKey(const ValueKey('tp-app-bar-close')), findsNothing);
    expect(find.text('取消'), findsNothing);
  });

  testWidgets('detail app bar pops one route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  appBar: TpAppBar(
                    role: TpAppBarRole.detail,
                    title: Text('外觀'),
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

    expect(find.text('開啟'), findsOneWidget);
    expect(find.text('外觀'), findsNothing);
  });

  testWidgets('modal form exposes Cancel and the explicit submit verb', (
    tester,
  ) async {
    var cancelled = false;
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.modalForm,
            title: const Text('編輯行程'),
            onCancel: () => cancelled = true,
            primaryActionLabel: '儲存',
            onPrimaryAction: () => saved = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('取消'));
    await tester.tap(find.text('儲存'));

    expect(cancelled, isTrue);
    expect(saved, isTrue);
  });

  testWidgets('sheet header centers its title between optional controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TpSheetHeader(
                title: '選擇行程',
                leading: SizedBox.square(
                  dimension: TpSpacing.tapMin,
                  child: Text('取消'),
                ),
                trailing: SizedBox.square(
                  dimension: TpSpacing.tapMin,
                  child: Icon(CupertinoIcons.xmark),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final header = tester.getRect(find.byType(TpSheetHeader));
    final screen = tester.getRect(find.byType(Scaffold));
    final trailing = tester.getRect(find.byIcon(CupertinoIcons.xmark));
    expect(header.width, screen.width);
    expect(trailing.right, closeTo(header.right - TpSpacing.s4, 0.1));
    expect(tester.getSize(find.byType(TpSheetHeader)).height, 56);
    expect(
      tester.getCenter(find.text('選擇行程')).dx,
      closeTo(tester.getCenter(find.byType(TpSheetHeader)).dx, 0.1),
    );
    expect(
      tester.getSize(find.byIcon(CupertinoIcons.xmark)).height,
      lessThanOrEqualTo(TpSpacing.tapMin),
    );
  });

  testWidgets(
    'TpAppBar delegates layout to GlassAppBar and keeps title left aligned',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: TpAppBar(
              role: TpAppBarRole.standalone,
              title: const Text('行程'),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.person)),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(GlassAppBar), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      final appBar = tester.widget<GlassAppBar>(find.byType(GlassAppBar));
      expect(appBar.centerTitle, isFalse);
      expect(
        tester.getCenter(find.text('行程')).dx,
        lessThan(tester.getCenter(find.byType(GlassAppBar)).dx),
      );
      final actionRects = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .map((widget) => tester.getRect(find.byWidget(widget)))
          .toList();
      expect(actionRects, hasLength(2));
      expect(actionRects.last.left - actionRects.first.right, 8);
    },
  );

  testWidgets(
    'TpMoreMenuButton waits for glass menu to close before dispatching a route action',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: TpAppBar(
              role: TpAppBarRole.standalone,
              title: const Text('行程'),
              actions: [
                TpMoreMenuButton<String>(
                  key: const ValueKey('more-menu'),
                  items: const [
                    TpActionItem(
                      key: ValueKey('open-sheet'),
                      value: 'sheet',
                      label: '開啟視窗',
                      icon: Icons.open_in_new,
                    ),
                  ],
                  onSelected: (value) => selected = value,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('more-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-sheet')));
      await tester.pump();

      expect(selected, isNull);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(selected, 'sheet');

      await tester.tap(find.byKey(const ValueKey('more-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('open-sheet')), findsOneWidget);
    },
  );

  testWidgets(
    'TpMoreMenuButton shares one primary glass style between trigger and menu',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            appBar: TpAppBar(
              role: TpAppBarRole.standalone,
              title: const Text('行程'),
              actions: [
                TpMoreMenuButton<String>(
                  key: const ValueKey('primary-more-menu'),
                  items: const [
                    TpActionItem(
                      value: 'notes',
                      label: '筆記',
                      icon: Icons.description_outlined,
                    ),
                  ],
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      final trigger = tester.widget<GlassButton>(
        find.descendant(
          of: find.byKey(const ValueKey('primary-more-menu')),
          matching: find.byType(GlassButton),
        ),
      );
      final menu = tester.widget<GlassMenu>(find.byType(GlassMenu));
      expect(trigger.settings, same(menu.settings));
      expect(
        menu.settings?.glassColor,
        TpColorsLight.accentBg.withValues(alpha: 0.68),
      );

      await tester.tap(find.byKey(const ValueKey('primary-more-menu')));
      await tester.pumpAndSettle();
      final item = tester.widget<GlassMenuItem>(find.byType(GlassMenuItem));
      expect(item.iconColor, TpColorsLight.accentDeep);
      expect(item.titleStyle?.color, TpColorsLight.accentDeep);
    },
  );

  testWidgets(
    'More menu preserves divider, destructive role, and disabled state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: TpAppBar(
              role: TpAppBarRole.standalone,
              title: const Text('行程'),
              actions: [
                TpMoreMenuButton<String>(
                  key: const ValueKey('semantic-more-menu'),
                  items: const [
                    TpActionItem(
                      value: 'edit',
                      label: '行程資料',
                      icon: CupertinoIcons.pencil,
                    ),
                    TpActionItem(
                      value: 'delete',
                      label: '刪除行程',
                      icon: CupertinoIcons.delete,
                      dividerBefore: true,
                      role: TpActionRole.destructive,
                      enabled: false,
                    ),
                  ],
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('semantic-more-menu')));
      await tester.pumpAndSettle();

      expect(find.byType(GlassMenuDivider), findsOneWidget);
      final items = tester.widgetList<GlassMenuItem>(
        find.byType(GlassMenuItem),
      );
      expect(items, hasLength(2));
      expect(items.last.isDestructive, isTrue);
      expect(items.last.enabled, isFalse);
      expect(items.last.height, TpSpacing.tapMin);
    },
  );

  testWidgets(
    'expanded option uses shared glass sheet with centered compact header',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => unawaited(
                    showAppScreenSheet<void>(
                      context,
                      builder: (_) => const Scaffold(
                        appBar: TpAppBar(
                          role: TpAppBarRole.standalone,
                          title: Text('隱私權與存取'),
                        ),
                        body: Text('展開內容'),
                      ),
                    ),
                  ),
                  child: const Text('展開'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('展開'));
      await tester.pumpAndSettle();

      expect(find.byType(GlassModalSheetScaffold), findsOneWidget);
      final appBar = tester.widget<GlassAppBar>(find.byType(GlassAppBar));
      expect(appBar.centerTitle, isTrue);

      final screenCenter = tester.getCenter(find.byType(MaterialApp)).dx;
      final titleRect = tester.getRect(find.text('隱私權與存取'));
      expect(titleRect.center.dx, closeTo(screenCenter, 1));
      expect(
        find.byKey(const ValueKey('app-large-sheet-drag-indicator')),
        findsNothing,
      );
      expect(
        tester
            .widget<GlassModalSheetScaffold>(
              find.byType(GlassModalSheetScaffold),
            )
            .showDragIndicator,
        isFalse,
      );
      expect(
        DefaultTextStyle.of(tester.element(find.text('隱私權與存取'))).style.fontSize,
        greaterThanOrEqualTo(20),
      );
    },
  );

  testWidgets('large sheet modal form fits Cancel and its submit action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => unawaited(
                showAppScreenSheet<void>(
                  context,
                  builder: (_) => Scaffold(
                    appBar: TpAppBar(
                      role: TpAppBarRole.modalForm,
                      title: const Text('編輯行程'),
                      onCancel: () {},
                      primaryActionLabel: '儲存',
                      onPrimaryAction: () {},
                    ),
                  ),
                ),
              ),
              child: const Text('展開表單'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('展開表單'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('tp-app-bar-cancel')), findsOneWidget);
    expect(find.text('儲存'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-large-sheet-close')), findsNothing);
  });
}
