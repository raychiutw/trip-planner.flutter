import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/features/shell/apple_root_tab_bar.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_action_item.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_horizontal_selector.dart';
import 'package:tripline/ui/tp_glass_surface.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';
import 'package:tripline/ui/tp_scope_menu.dart';

const _lastContent = ValueKey('hig-last-content');

class _HigState {
  const _HigState({
    required this.brightness,
    this.textScale = 1,
    this.reduceMotion = false,
    this.increasedContrast = false,
    this.reduceTransparency = false,
  });

  final Brightness brightness;
  final double textScale;
  final bool reduceMotion;
  final bool increasedContrast;
  final bool reduceTransparency;

  String get name {
    final appearance = brightness == Brightness.dark ? 'dark' : 'light';
    final text = textScale == 1 ? 'text100' : 'text200';
    final motion = reduceMotion ? 'motion-reduced' : 'motion-full';
    final contrast = increasedContrast
        ? 'contrast-increased'
        : 'contrast-normal';
    final transparency = reduceTransparency
        ? 'transparency-reduced'
        : 'transparency-normal';
    return 'shared-ios-$appearance-$text-$motion-$contrast-$transparency';
  }
}

const _states = [
  _HigState(brightness: Brightness.light),
  _HigState(brightness: Brightness.dark),
  _HigState(brightness: Brightness.light, textScale: 2),
  _HigState(brightness: Brightness.dark, textScale: 2),
  _HigState(brightness: Brightness.light, reduceMotion: true),
  _HigState(brightness: Brightness.dark, reduceMotion: true),
  _HigState(brightness: Brightness.light, increasedContrast: true),
  _HigState(brightness: Brightness.dark, increasedContrast: true),
  _HigState(brightness: Brightness.light, reduceTransparency: true),
  _HigState(brightness: Brightness.dark, reduceTransparency: true),
];

void main() {
  for (final state in _states) {
    testWidgets('${state.name} keeps shared HIG geometry and behavior', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_MatrixApp(state: state));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('tp-root-glass-header')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('apple-root-tab-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-1-option')), findsOneWidget);
      expect(tester.takeException(), isNull);

      expect(
        tester.getSize(find.byKey(const ValueKey('tp-root-header-action-0'))),
        const Size(44, 44),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('account-avatar-button'))),
        const Size(44, 44),
      );

      await tester.ensureVisible(find.byKey(const ValueKey('day-2-option')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('day-2-option')));
      await tester.pumpAndSettle();
      final dayTwo = tester.getSemantics(
        find.byKey(const ValueKey('day-2-option')),
      );
      expect(
        dayTwo.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );

      final headerGlass = tester.widget<GlassContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('tp-root-glass-header')),
          matching: find.byType(GlassContainer),
        ),
      );
      final fallbackAlpha = headerGlass.settings!.platformViewFallbackColor!.a;
      final expectsOpaqueGlass =
          state.increasedContrast || state.reduceTransparency;
      expect(
        fallbackAlpha,
        expectsOpaqueGlass
            ? greaterThanOrEqualTo(0.95)
            : closeTo(state.brightness == Brightness.dark ? 0.48 : 0.40, 0.01),
      );
      final isDark = state.brightness == Brightness.dark;
      expect(headerGlass.settings!.blur, expectsOpaqueGlass ? 0 : 16);
      // 導覽配方與共用玻璃表面已收斂為同一組參數。
      expect(
        headerGlass.settings!.thickness,
        expectsOpaqueGlass ? 0 : (isDark ? 28 : 24),
      );
      expect(
        headerGlass.settings!.refractiveIndex,
        expectsOpaqueGlass ? 1 : 1.15,
      );

      // 邊緣交還材質：這三個參數若沒設定，shader 的邊緣光是關掉的，
      // 就得再描一條實心線補回來 —— 那正是「貼紙感」的來源。
      if (!expectsOpaqueGlass) {
        expect(
          headerGlass.settings!.ambientRim,
          greaterThan(0),
          reason: '環境邊緣光必須有值',
        );
        expect(
          headerGlass.settings!.glowIntensity,
          greaterThan(0),
          reason: '光暈強度必須有值',
        );
      }

      // 一般模式描一條細邊；提高對比才換成明顯的實心邊。原本相信「移除描邊
      // 後由材質接手」，模擬器實測材質並沒有接手（差值恆為 0），Apple 是 +30。
      final headerShape = headerGlass.shape as LiquidRoundedSuperellipse;
      expect(
        headerShape.side.color.a,
        state.increasedContrast ? greaterThan(0.5) : closeTo(0.12, 0.001),
        reason: '一般模式要有一條對齊 Apple 強度的細邊',
      );

      // 日期選擇器的軌道走同一條規則。軌本身改成半透明填色 +
      // `BackdropFilter`，不再是 LiquidGlass —— shader 會把 tint 衰減到約
      // 14%，導覽配方的 tint 在淺色又是 `surface`（白），疊在白色頁面上等於
      // 無色，實測軌與頁面同為 #FFFFFF。
      final trackDecoration = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(TpHorizontalSelector<int>),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<ShapeDecoration>()
          .first;
      final trackShape = trackDecoration.shape as LiquidRoundedSuperellipse;
      (double, double, double) rgb(Color c) => (c.r, c.g, c.b);
      expect(
        trackShape.side.color.a,
        state.increasedContrast ? greaterThan(0.5) : closeTo(0.12, 0.001),
        reason: '選擇器軌道的描邊規則應與導覽 chrome 一致',
      );

      // 品牌柔褐只出現在前景：選取膠囊在一般模式與無障礙 fallback 都是中性語意層。
      final scheme = Theme.of(
        tester.element(find.byType(AppleRootTabBar)),
      ).colorScheme;
      // 選取膠囊是自己畫的填色，不是巢狀玻璃 —— 巢狀玻璃的 `glassColor` 會被
      // 軌道的 LiquidGlassLayer 吃掉，模擬器實測改 alpha 逐位元零差異。
      final selectedDayFill = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byKey(const ValueKey('day-2-option')),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<ShapeDecoration>()
          .where((deco) => deco.color != null)
          .single
          .color!;

      // 對照 iOS 26 電話 app 通話記錄實測：深色膠囊 #363636。
      final selectedBase = isDark
          ? scheme.surfaceContainerHighest
          : scheme.surface;
      expect(
        rgb(selectedDayFill),
        rgb(selectedBase),
        reason: '日期選擇器的選取膠囊是中性語意層，比軌更亮',
      );
      expect(
        selectedDayFill.a,
        expectsOpaqueGlass ? 1 : closeTo(isDark ? 0.90 : 0.92, 0.001),
        reason: '一般模式半透明讓內容透出；無障礙 fallback 收斂為不透明',
      );
      expect(
        find.descendant(
          of: find.byType(TpHorizontalSelector<int>),
          matching: find.byType(BackdropFilter),
        ),
        expectsOpaqueGlass ? findsNothing : findsOneWidget,
      );

      if (expectsOpaqueGlass) {
        final tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
        expect(
          tabBar.indicatorColor,
          scheme.surfaceContainerHigh.withValues(alpha: 1),
          reason: '無障礙 fallback 仍收斂為中性不透明，避免大面積品牌色',
        );
      } else {
        expect(
          rgb(selectedDayFill),
          isNot(rgb(scheme.primary)),
          reason: '品牌柔褐不得鋪成選取膠囊的背景',
        );

        // 選取指示一律「中性底 + tint 前景」。iOS 26 電話 app 實測:選取膠囊
        // 是 #363636 中性灰(比容器亮約 20 階),系統藍在字符與標籤上 ——
        // 強調色在前景,不在背景(ADR-0004 取代 ADR-0003)。
        final tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
        expect(
          rgb(tabBar.indicatorColor!),
          isNot(rgb(scheme.primary)),
          reason: '品牌柔褐不得鋪成 root tab 選取膠囊的背景',
        );
        expect(
          tabBar.selectedIconColor,
          scheme.primary,
          reason: '選取字符走品牌 tint,不是坐在柔褐上的 onPrimary',
        );
      }

      // 未選字符與標籤同色。實測我們先前 icon #919197(中灰)、label
      // #F9F9FB(近白),同一顆 tab 內不一致;Apple 兩者都是近白。
      final rootBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
      expect(
        rootBar.unselectedIconColor,
        rootBar.unselectedLabelColor,
        reason: '未選的字符與標籤必須同色',
      );

      // 未選取態也是實心字符：兩態同字符、靠 tint 區分，不做 outline↔filled 切換。
      final rootTabs = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
      for (final tab in rootTabs.tabs) {
        expect(
          (tab.activeIcon! as Icon).icon,
          (tab.icon! as Icon).icon,
          reason: 'root tab 的選取態與未選取態必須是同一個字符',
        );
      }

      // 品牌色改走前景：選取態的標籤是 tint，未選取維持中性次要前景。
      expect(
        tester.widget<Text>(find.text('DAY 2')).style?.color,
        scheme.primary,
        reason: '選取態的標籤應是品牌 tint',
      );
      expect(
        tester.widget<Text>(find.text('DAY 1')).style?.color,
        scheme.onSurfaceVariant,
        reason: '未選取態維持中性次要前景',
      );

      // 欄寬改量測後，放大字級仍不得讓選項低於最小點擊尺寸。
      for (final key in ['day-1-option', 'day-2-option']) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(44), reason: key);
        expect(size.height, greaterThanOrEqualTo(44), reason: key);
      }

      // 選取態保留項目原本的字符，勾選另外顯示。
      await tester.tap(find.byKey(const ValueKey('matrix-more-menu')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('matrix-menu-selected')),
          matching: find.byIcon(CupertinoIcons.sort_down),
        ),
        findsOneWidget,
        reason: '已選取的項目仍應顯示它原本的字符',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('matrix-menu-selected')),
          matching: find.byIcon(CupertinoIcons.check_mark),
        ),
        findsOneWidget,
        reason: '勾選要另外顯示，而不是取代原字符',
      );
      await tester.tapAt(const Offset(20, 400));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('matrix-menu-selected')),
        findsNothing,
        reason: '選單應已關閉，避免殘留面板影響後續斷言',
      );

      // 範圍選單走自己的版面，選取呈現需各自驗證。
      await tester.ensureVisible(
        find.byKey(const ValueKey('matrix-scope-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('matrix-scope-menu')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('matrix-scope-selected')),
          matching: find.byIcon(CupertinoIcons.list_bullet),
        ),
        findsOneWidget,
        reason: '已選取的範圍仍應顯示它原本的字符',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('matrix-scope-selected')),
          matching: find.byIcon(CupertinoIcons.check_mark),
        ),
        findsOneWidget,
        reason: '勾選要另外顯示，而不是取代原字符',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('matrix-scope-plain')),
          matching: find.byIcon(CupertinoIcons.check_mark),
        ),
        findsNothing,
        reason: '未選取的項目不應出現勾選',
      );
      await tester.tapAt(const Offset(20, 60));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -1200),
        2500,
      );
      await tester.pumpAndSettle();
      final lastContent = tester.getRect(find.byKey(_lastContent));
      final rootTab = tester.getRect(
        find.byKey(const ValueKey('apple-root-tab-bar')),
      );
      expect(lastContent.bottom, lessThanOrEqualTo(rootTab.top));
      expect(tester.takeException(), isNull);

      // 媒體背景情境（地圖等 platform view）：同一組無障礙狀態下，清透玻璃要有
      // 暗化層、字符改亮色。地圖圖磚恆為亮色，不能靠 app 的明暗模式判斷。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        AppAccessibilityScope(
          reduceTransparency: state.reduceTransparency,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: state.brightness == Brightness.dark
                ? AppTheme.dark()
                : AppTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 844),
                padding: const EdgeInsets.only(top: 47),
                textScaler: TextScaler.linear(state.textScale),
                disableAnimations: state.reduceMotion,
                highContrast: state.increasedContrast,
              ),
              child: TpRootScaffold(
                header: TpRootHeaderConfig(
                  title: const Text('地圖'),
                  platformViewBackdrop: true,
                  actions: [
                    TpToolbarIconButton(
                      icon: CupertinoIcons.share,
                      tooltip: '分享',
                      onPressed: () {},
                    ),
                  ],
                ),
                body: const TpRootScrollView(
                  slivers: [SliverToBoxAdapter(child: Text('地圖內容'))],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mediaGlass = tester.widget<GlassContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('tp-root-glass-header')),
          matching: find.byType(GlassContainer),
        ),
      );
      if (expectsOpaqueGlass) {
        expect(
          mediaGlass.settings!.glassColor.a,
          1,
          reason: '媒體背景的無障礙 fallback 仍要收斂成不透明',
        );
      } else {
        expect(
          mediaGlass.settings!.glassColor,
          Colors.black.withValues(alpha: tpMediaScrimOpacity),
          reason: '媒體背景要用清透玻璃加暗化層',
        );
        expect(
          IconTheme.of(tester.element(find.byIcon(CupertinoIcons.share))).color,
          Colors.white,
          reason: '暗化之後字符要用亮色，深淺兩種模式都可讀',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}

class _MatrixApp extends StatelessWidget {
  const _MatrixApp({required this.state});

  final _HigState state;

  @override
  Widget build(BuildContext context) {
    final theme = state.brightness == Brightness.dark
        ? AppTheme.dark()
        : AppTheme.light();
    return AppAccessibilityScope(
      reduceTransparency: state.reduceTransparency,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            padding: const EdgeInsets.only(top: 47),
            viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
            textScaler: TextScaler.linear(state.textScale),
            disableAnimations: state.reduceMotion,
            highContrast: state.increasedContrast,
          ),
          child: const _MatrixScene(),
        ),
      ),
    );
  }
}

class _MatrixScene extends StatefulWidget {
  const _MatrixScene();

  @override
  State<_MatrixScene> createState() => _MatrixSceneState();
}

class _MatrixSceneState extends State<_MatrixScene> {
  var _day = 1;
  var _rootTab = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: TpRootScaffold(
        showSoftEdge: true,
        header: TpRootHeaderConfig(
          title: const Text('京都五日行'),
          actions: [
            TpToolbarGlassButton(
              tooltip: '筆記',
              onPressed: () {},
              child: const Icon(CupertinoIcons.doc_text, size: 20),
            ),
            TpMoreMenuButton<int>(
              key: const ValueKey('matrix-more-menu'),
              onSelected: (_) {},
              items: const <TpActionItem<int>>[
                TpActionItem<int>(
                  key: ValueKey('matrix-menu-selected'),
                  value: 1,
                  icon: CupertinoIcons.sort_down,
                  label: '最新',
                  selected: true,
                ),
                TpActionItem<int>(
                  key: ValueKey('matrix-menu-plain'),
                  value: 2,
                  icon: CupertinoIcons.sort_up,
                  label: '最舊',
                ),
              ],
            ),
          ],
        ),
        body: TpRootScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.list(
                children: [
                  TpHorizontalSelector<int>(
                    value: _day,
                    options: const [
                      TpScopeOption(
                        value: 1,
                        label: 'DAY 1',
                        key: ValueKey('day-1-option'),
                      ),
                      TpScopeOption(
                        value: 2,
                        label: 'DAY 2',
                        key: ValueKey('day-2-option'),
                      ),
                      TpScopeOption(value: 3, label: 'DAY 3'),
                    ],
                    onSelected: (value) => setState(() => _day = value),
                  ),
                  const SizedBox(height: 16),
                  TpScopeMenu<int>(
                    key: const ValueKey('matrix-scope-menu'),
                    label: '行程',
                    value: 1,
                    options: const [
                      TpScopeOption(
                        value: 1,
                        label: '行程',
                        icon: CupertinoIcons.list_bullet,
                        key: ValueKey('matrix-scope-selected'),
                      ),
                      TpScopeOption(
                        value: 2,
                        label: '地圖',
                        icon: CupertinoIcons.map,
                        key: ValueKey('matrix-scope-plain'),
                      ),
                    ],
                    onSelected: (_) {},
                  ),
                  const SizedBox(height: 16),
                  for (var index = 0; index < 12; index++)
                    Card(
                      key: index == 11 ? _lastContent : null,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(index == 0 ? '清水寺' : '行程景點 ${index + 1}'),
                        subtitle: const Text('10:00–11:30 · 景點'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppleRootTabBar(
        selectedIndex: _rootTab,
        onSelected: (index) => setState(() => _rootTab = index),
      ),
    );
  }
}
