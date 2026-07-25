import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/app/adaptive.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_action_item.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_glass_surface.dart';

/// 選單項目是面板內的 `TextButton` —— 改用 `RawMenuAnchor` 後不再有
/// Material 的 `MenuItemButton` 可以直接查型別。
Finder _menuItems() => find.descendant(
  of: find.byKey(const ValueKey('tp-menu-panel')),
  matching: find.byType(TextButton),
);

const _menuPanel = ValueKey('tp-menu-panel');

Widget _menuHost({
  required List<TpActionItem<String>> items,
  required ValueChanged<String> onSelected,
  double textScale = 1,
  Alignment alignment = Alignment.topRight,
}) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: Align(
      alignment: alignment,
      child: TpMoreMenuButton<String>(
        key: const ValueKey('host-more-menu'),
        items: items,
        onSelected: onSelected,
      ),
    ),
  ),
);

void main() {
  group('選單改以 RawMenuAnchor 承載', () {
    const items = [
      TpActionItem(value: 'a', label: '筆記', icon: Icons.description_outlined),
      TpActionItem(value: 'b', label: '列印', icon: Icons.print),
    ];

    testWidgets('點選單外面任何地方都可關閉', (tester) async {
      await tester.pumpWidget(_menuHost(items: items, onSelected: (_) {}));
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(_menuPanel), findsOneWidget);

      // 點在遠離面板的左下角。
      await tester.tapAt(const Offset(20, 560));
      await tester.pumpAndSettle();
      expect(find.byKey(_menuPanel), findsNothing);
    });

    testWidgets('Esc 可關閉，方向鍵可走動', (tester) async {
      String? selected;
      await tester.pumpWidget(
        _menuHost(items: items, onSelected: (value) => selected = value),
      );
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();

      // 方向鍵把焦點移進面板，Enter 啟動落點的那一項 —— 只驗「不丟例外」
      // 是恆真的，拿掉 shortcuts 也不會丟例外。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 'a', reason: '方向鍵要走到第一項，Enter 要能啟動它');

      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_menuPanel), findsNothing);
    });

    testWidgets('項目朗讀為按鈕，停用項目的停用原因仍被朗讀', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _menuHost(
          items: const [
            TpActionItem(
              value: 'move',
              label: '移動到其他日',
              icon: Icons.calendar_today,
              semanticLabel: '移動到其他日，只有一天時無法移動',
              enabled: false,
            ),
          ],
          onSelected: (_) {},
        ),
      );
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();

      final flags = tester
          .getSemantics(find.bySemanticsLabel('移動到其他日，只有一天時無法移動'))
          .getSemanticsData()
          .flagsCollection;
      expect(flags.isButton, isTrue, reason: '項目要被朗讀為按鈕');
      expect(flags.isEnabled, Tristate.isFalse, reason: '停用狀態要傳達出去');
      handle.dispose();
    });

    testWidgets('文字縮放 1.0／1.3／2.0 下，點擊命中的都是該項目自己的值', (tester) async {
      for (final scale in [1.0, 1.3, 2.0]) {
        String? selected;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _menuHost(
            items: items,
            textScale: scale,
            onSelected: (value) => selected = value,
          ),
        );
        await tester.tap(find.byKey(const ValueKey('host-more-menu')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('列印'));
        await tester.pumpAndSettle();
        expect(selected, 'b', reason: 'textScale=$scale 必須嚴格命中自己的值');
      }
    });

    testWidgets('寬度依內容決定，短標籤不撐空白', (tester) async {
      Future<double> widthFor(List<TpActionItem<String>> menuItems) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _menuHost(items: menuItems, onSelected: (_) {}),
        );
        await tester.tap(find.byKey(const ValueKey('host-more-menu')));
        await tester.pumpAndSettle();
        return tester.getSize(find.byKey(_menuPanel)).width;
      }

      final short = await widthFor(items);
      final long = await widthFor(const [
        TpActionItem(value: 'a', label: '把這個停留點複製到另一個行程的某一天', icon: Icons.copy),
      ]);
      expect(long, greaterThan(short), reason: '長標籤要有更寬的面板');
      expect(short, lessThan(long), reason: '短標籤不該撐到跟長標籤一樣寬');
    });

    testWidgets('空間不足往上翻時，scale 原點改為底部對齊', (tester) async {
      ScaleTransition panelScale() => tester.widget<ScaleTransition>(
        find.ancestor(
          of: find.byKey(_menuPanel),
          matching: find.byType(ScaleTransition),
        ),
      );

      // 觸發鈕在頂端 → 往下展開，原點在頂端。
      await tester.pumpWidget(_menuHost(items: items, onSelected: (_) {}));
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pump();
      expect(panelScale().alignment, Alignment.topRight);

      // 觸發鈕在底端 → 往上翻，原點必須跟著改成底部，否則面板會從遠離
      // 觸發鈕的那一端長出來。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _menuHost(
          items: items,
          onSelected: (_) {},
          alignment: Alignment.bottomRight,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pump();
      expect(panelScale().alignment, Alignment.bottomRight);
    });

    testWidgets('選單開啟期間畫面被外部換掉，不殘留攔截層', (tester) async {
      await tester.pumpWidget(_menuHost(items: items, onSelected: (_) {}));
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(_menuPanel), findsOneWidget);

      // 等同 root tab 在選單開著時被切走。刻意不用 TextButton —— 它會與選單
      // 項目的 element 被重用，`AnimatedDefaultTextStyle` 插值失敗的例外會蓋掉
      // 這支測試真正要驗的東西。
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              key: const ValueKey('after-switch'),
              behavior: HitTestBehavior.opaque,
              onTap: () => tapped = true,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_menuPanel), findsNothing);
      await tester.tap(find.byKey(const ValueKey('after-switch')));
      expect(tapped, isTrue, reason: '殘留的 TapRegion 會把這一下點擊吃掉');
    });
  });

  testWidgets('表單主要動作是 prominent，著色在底色而不是字符', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.modalForm,
            title: const Text('編輯行程'),
            onCancel: () {},
            primaryActionLabel: '儲存',
            onPrimaryAction: () {},
          ),
        ),
      ),
    );

    final scheme = AppTheme.light().colorScheme;
    final primary = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('tp-app-bar-primary-action')),
        matching: find.byType(TextButton),
      ),
    );
    const resting = <WidgetState>{};
    expect(
      primary.style?.backgroundColor?.resolve(resting),
      scheme.primary,
      reason: '著色在底色',
    );
    expect(
      primary.style?.foregroundColor?.resolve(resting),
      scheme.onPrimary,
      reason: '底色著色後，文字改用 onPrimary 才有對比',
    );

    // 一列只有一個 prominent，且置於尾端。
    final prominentButtons = tester
        .widgetList<TpToolbarTextButton>(find.byType(TpToolbarTextButton))
        .where((button) => button.prominent)
        .toList();
    expect(prominentButtons.length, 1);
    expect(prominentButtons.single.label, '儲存');

    // 取消是次要動作，維持純文字。
    final cancel = tester.widget<TextButton>(
      find.ancestor(of: find.text('取消'), matching: find.byType(TextButton)),
    );
    expect(cancel.style?.backgroundColor?.resolve(resting), isNull);
  });

  testWidgets('群組容器包住更多選單時，header 的動作額度判斷仍成立', (tester) async {
    // 改寫前這裡會 assert：`action is TpMoreMenuButton` 對群組容器不成立。
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.detail,
            title: const Text('行程'),
            actions: [
              TpToolbarIconButton(
                icon: CupertinoIcons.share,
                tooltip: '分享',
                onPressed: () {},
              ),
              TpToolbarActionGroup(
                children: [
                  TpMoreMenuButton<int>(
                    items: const [
                      TpActionItem(value: 1, label: '列印', icon: Icons.print),
                    ],
                    onSelected: (_) {},
                  ),
                  TpToolbarIconButton(
                    icon: CupertinoIcons.add,
                    tooltip: '新增',
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('tp-toolbar-action-group')),
      findsOneWidget,
    );
  });

  testWidgets(
    'TpToolbarGlassButton resolves custom settings for Reduce Transparency',
    (tester) async {
      const customSettings = LiquidGlassSettings(
        glassColor: Color(0x332196F3),
        blur: 24,
        thickness: 20,
        refractiveIndex: 1.2,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AppAccessibilityScope(
            reduceTransparency: true,
            child: Scaffold(
              body: TpToolbarGlassButton(
                tooltip: '更多',
                onPressed: () {},
                glassSettings: customSettings,
                child: const Icon(Icons.more_horiz),
              ),
            ),
          ),
        ),
      );

      final settings = tester
          .widget<GlassButton>(find.byType(GlassButton))
          .settings!;
      expect(settings.glassColor.a, 1);
      expect(settings.backerColor?.a, 1);
      expect(settings.platformViewFallbackColor?.a, 1);
      expect(settings.blur, 0);
      expect(settings.thickness, 0);
      expect(settings.refractiveIndex, 1);
    },
  );

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

  testWidgets('detail 固定 bar 只退一層路由且不再自動附加帳號入口', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            TpAccountActionScope(onOpen: (_) {}, child: child!),
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
    expect(find.byKey(const ValueKey('account-avatar-button')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
    await tester.pumpAndSettle();

    expect(find.text('開啟'), findsOneWidget);
    expect(find.text('外觀'), findsNothing);
  });

  testWidgets('固定 bar 的帳號入口改由呼叫端明文提供', (tester) async {
    var accountOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TpAccountActionScope(
          onOpen: (_) => accountOpened = true,
          child: child!,
        ),
        home: const Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.detail,
            title: Text('共編設定'),
            accountEntry: TpAccountAvatarButton(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-avatar-button')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('account-avatar-button'))),
      const Size(44, 44),
    );
    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    expect(accountOpened, isTrue);
  });

  testWidgets('內容 header 的帳號入口不佔用一般動作額度', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            TpAccountActionScope(onOpen: (_) {}, child: child!),
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.detail,
            title: const Text('共編設定'),
            actions: [
              TpToolbarIconButton(
                icon: CupertinoIcons.arrow_clockwise,
                tooltip: '重新整理',
                onPressed: () {},
              ),
            ],
            accountEntry: const TpAccountAvatarButton(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('account-avatar-button')), findsOneWidget);
    expect(find.byTooltip('重新整理'), findsOneWidget);
    // 帳號入口自成一組，固定排在最右側。
    expect(
      tester.getCenter(find.byKey(const ValueKey('account-avatar-button'))).dx,
      greaterThan(tester.getCenter(find.byTooltip('重新整理')).dx),
    );
  });

  testWidgets('內容 header 兩個一般動作沒有更多選單時仍拒收', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.detail,
            title: const Text('共編設定'),
            actions: [
              TpToolbarIconButton(
                icon: CupertinoIcons.arrow_clockwise,
                tooltip: '重新整理',
                onPressed: () {},
              ),
              TpToolbarIconButton(
                icon: CupertinoIcons.share,
                tooltip: '分享',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('帳號入口誤放進 actions 會被擋下', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.detail,
            title: Text('共編設定'),
            actions: [TpAccountAvatarButton()],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
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

  testWidgets('modal form keeps the complete Cancel label at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.modalForm,
            title: const Text('編輯停留點'),
            onCancel: () {},
            primaryActionLabel: '儲存',
            onPrimaryAction: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('取消'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('tp-app-bar-cancel'))).width,
      greaterThan(64),
    );
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
      expect(find.byType(RawMenuAnchor), findsOneWidget);
      expect(find.byType(GlassMenu), findsNothing);
      await tester.tap(find.byKey(const ValueKey('open-sheet')));
      await tester.pumpAndSettle();
      expect(selected, 'sheet');

      await tester.tap(find.byKey(const ValueKey('more-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('open-sheet')), findsOneWidget);
    },
  );

  testWidgets('選單觸發鈕與面板都走中性語意層，不再是品牌褐玻璃', (tester) async {
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
    final scheme = AppTheme.light().colorScheme;
    (double, double, double) rgb(Color c) => (c.r, c.g, c.b);

    // 觸發鈕本體與按壓高亮走中性導覽玻璃，不再是品牌褐。
    expect(rgb(trigger.settings!.glassColor), isNot(rgb(scheme.primary)));
    expect(
      rgb(trigger.settings!.glassColor),
      isNot(rgb(scheme.primaryContainer)),
    );
    // 面板表面也是中性語意層。
    expect(
      rgb(menuSurface.glassSettings!.glassColor),
      rgb(scheme.surfaceContainerHigh),
    );

    final item = tester.widget<TextButton>(_menuItems());
    expect(
      item.style?.foregroundColor?.resolve(<WidgetState>{}),
      TpSystemColorsLight.label,
    );
    expect(
      find.descendant(
        of: _menuItems(),
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsOneWidget,
    );
  });

  testWidgets('深色選單的項目文字是標籤色，不再是品牌 tint', (tester) async {
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
    final item = tester.widget<TextButton>(_menuItems());
    expect(
      item.style?.foregroundColor?.resolve(<WidgetState>{}),
      TpSystemColorsDark.label,
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
      final items = tester.widgetList<TextButton>(_menuItems());
      expect(items, hasLength(2));
      expect(
        items.last.style?.foregroundColor?.resolve(<WidgetState>{}),
        Theme.of(tester.element(find.byType(RawMenuAnchor))).colorScheme.error,
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
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
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
    expect(
      tester.getSize(find.byKey(const ValueKey('tp-app-bar-cancel'))).width,
      greaterThan(64),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('tp-app-bar-primary-action')))
          .width,
      greaterThan(64),
    );
    expect(find.byKey(const ValueKey('app-large-sheet-close')), findsNothing);
  });
}
