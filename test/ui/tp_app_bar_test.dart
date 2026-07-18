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
import 'package:tripline/ui/tp_glass_surface.dart';

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
    'TpMoreMenuButton uses a native anchored menu and dispatches once',
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
      expect(find.byType(MenuAnchor), findsOneWidget);
      expect(find.byType(GlassMenu), findsNothing);
      await tester.tap(find.byKey(const ValueKey('open-sheet')));
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
                      selected: true,
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
      await tester.tap(find.byKey(const ValueKey('primary-more-menu')));
      await tester.pumpAndSettle();
      expect(find.byType(TpGlassSurface), findsOneWidget);
      final menuSurface = tester.widget<TpGlassSurface>(
        find.byType(TpGlassSurface),
      );
      expect(trigger.settings, same(menuSurface.glassSettings));
      final item = tester.widget<MenuItemButton>(find.byType(MenuItemButton));
      expect(
        item.style?.foregroundColor?.resolve(<WidgetState>{}),
        TpColorsLight.foreground,
      );
      expect(
        find.descendant(
          of: find.byType(MenuItemButton),
          matching: find.byIcon(CupertinoIcons.check_mark),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Dark More menu uses the Tripline primary foreground', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.standalone,
            title: const Text('行程'),
            actions: [
              TpMoreMenuButton<String>(
                key: const ValueKey('dark-more-menu'),
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

    await tester.tap(find.byKey(const ValueKey('dark-more-menu')));
    await tester.pumpAndSettle();
    final item = tester.widget<MenuItemButton>(find.byType(MenuItemButton));
    expect(
      item.style?.foregroundColor?.resolve(<WidgetState>{}),
      TpColorsDark.accent,
    );
  });

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

      expect(find.byType(Divider), findsOneWidget);
      final items = tester.widgetList<MenuItemButton>(
        find.byType(MenuItemButton),
      );
      expect(items, hasLength(2));
      expect(
        items.last.style?.foregroundColor?.resolve(<WidgetState>{}),
        Theme.of(tester.element(find.byType(MenuAnchor))).colorScheme.error,
      );
      expect(items.last.onPressed, isNull);
      expect(
        items.last.style?.minimumSize?.resolve(<WidgetState>{})?.height,
        TpSpacing.tapMin,
      );
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
