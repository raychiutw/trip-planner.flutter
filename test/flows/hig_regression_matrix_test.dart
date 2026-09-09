import 'dart:ui' show Tristate;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

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

/// 公開中性表面設定；另外以像素確認選取表面確實繪製。
Color _selectedPillColor(WidgetTester tester) => tester
    .widget<GlassTabBar>(
      find.descendant(
        of: find.byKey(const ValueKey('apple-root-tab-bar')),
        matching: find.byType(GlassTabBar),
      ),
    )
    .indicatorColor!;

void main() {
  for (final state in _states) {
    testWidgets('日期選擇器中性選取底實際移動且可操作 ${state.name}', (tester) async {
      final boundaryKey = GlobalKey();
      final theme = state.brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark();
      var selected = 1;
      var actions = 0;
      Widget scene(Color background) => MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(
            highContrast: state.increasedContrast,
            disableAnimations: state.reduceMotion,
            textScaler: TextScaler.linear(state.textScale),
          ),
          child: AppAccessibilityScope(
            reduceTransparency: state.reduceTransparency,
            child: GlassAdaptiveScope(
              maxQuality: GlassQuality.minimal,
              child: Center(
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: ColoredBox(
                    color: background,
                    child: SizedBox(
                      width: 320,
                      child: StatefulBuilder(
                        builder: (context, setState) =>
                            TpHorizontalSelector<int>(
                              value: selected,
                              options: const [
                                TpScopeOption(
                                  value: 1,
                                  label: 'DAY 1',
                                  key: ValueKey('pixel-day-1'),
                                ),
                                TpScopeOption(
                                  value: 2,
                                  label: 'DAY 2',
                                  key: ValueKey('pixel-day-2'),
                                ),
                              ],
                              onSelected: (value) => setState(() {
                                selected = value;
                                actions++;
                              }),
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Future<Color> sample(int day) async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final rect = tester.getRect(find.byKey(ValueKey('pixel-day-$day')));
        final point = boundary.globalToLocal(
          Offset(rect.center.dx, rect.top + 4),
        );
        final image = (await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1),
        ))!;
        final data = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
        final color = Color.fromARGB(
          data.getUint8(offset + 3),
          data.getUint8(offset),
          data.getUint8(offset + 1),
          data.getUint8(offset + 2),
        );
        image.dispose();
        return color;
      }

      await tester.pumpWidget(scene(Colors.black));
      await tester.pumpAndSettle();
      final fill = await sample(1);
      final track = await sample(2);
      expect(fill, theme.colorScheme.surfaceContainerHigh);
      expect(track, isNot(fill));
      await tester.tap(find.byKey(const ValueKey('pixel-day-2')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(actions, 1);
      expect(await sample(2), fill);
      expect(await sample(1), track);
      if (state.increasedContrast || state.reduceTransparency) {
        await tester.pumpWidget(scene(Colors.white));
        await tester.pumpAndSettle();
        expect(await sample(2), fill);
        expect(await sample(1), track, reason: '無障礙軌道不可透出後方內容');
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final state in _states) {
    testWidgets('root tab選取表面實際繪製並隨操作移動 ${state.name}', (tester) async {
      final boundaryKey = GlobalKey();
      var selected = 0;
      var selections = 0;
      final focusNodes = List.generate(4, (_) => FocusNode());
      addTearDown(() {
        for (final node in focusNodes) {
          node.dispose();
        }
      });
      final theme = state.brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark();
      await tester.pumpWidget(
        AppAccessibilityScope(
          reduceTransparency: state.reduceTransparency,
          child: MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                highContrast: state.increasedContrast,
                disableAnimations: state.reduceMotion,
                textScaler: TextScaler.linear(state.textScale),
              ),
              child: GlassAdaptiveScope(
                maxQuality: GlassQuality.minimal,
                child: child!,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: SizedBox(
                    width: 390,
                    height: 120,
                    child: StatefulBuilder(
                      builder: (context, setState) => Align(
                        alignment: Alignment.bottomCenter,
                        child: AppleRootTabBar(
                          selectedIndex: selected,
                          focusNodes: focusNodes,
                          onSelected: (value) {
                            selections++;
                            setState(() => selected = value);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<Color> pixel(String label) async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final rect = tester.getRect(find.bySemanticsLabel(label));
        final point = boundary.globalToLocal(
          Offset(rect.center.dx, rect.top + 7),
        );
        final image = (await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1),
        ))!;
        final data = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
        final color = Color.fromARGB(
          data.getUint8(offset + 3),
          data.getUint8(offset),
          data.getUint8(offset + 1),
          data.getUint8(offset + 2),
        );
        image.dispose();
        return color;
      }

      final selectedLabels = tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('apple-root-tab-bar')),
          matching: find.text('聊天'),
        ),
      );
      expect(
        selectedLabels.map((text) => text.style?.color),
        contains(theme.colorScheme.primary),
      );
      final firstSelection = await pixel('聊天');
      final unselected = await pixel('行程');
      expect(
        firstSelection,
        theme.colorScheme.surfaceContainerHigh,
        reason: '中性選取底必須真正畫出，不只設定參數',
      );
      expect(firstSelection, isNot(unselected));
      await tester.tapAt(tester.getCenter(find.bySemanticsLabel('行程')));
      await tester.pumpAndSettle();
      expect(await pixel('行程'), firstSelection);
      expect(await pixel('聊天'), unselected);
      expect(selections, 1);
      final mapNode = tester.getSemantics(find.bySemanticsLabel('地圖'));
      mapNode.owner!.performAction(mapNode.id, ui.SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(selections, 2);
      expect(selected, 2);
      focusNodes[3].requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selections, 3);
      expect(selected, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selections, 4, reason: '再次啟用目前tab也只呼叫一次');

      expect(
        tester
            .getSemantics(find.bySemanticsLabel('收藏'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    });
  }

  for (final state in _states) {
    testWidgets('共用可操作玻璃表面採套件預設呈現 ${state.name}', (tester) async {
      final boundaryKey = GlobalKey();
      var actions = 0;
      final opaque = state.increasedContrast || state.reduceTransparency;
      Widget scene({bool reference = false, Color background = Colors.black}) =>
          AppAccessibilityScope(
            reduceTransparency: state.reduceTransparency,
            child: MaterialApp(
              theme: state.brightness == Brightness.light
                  ? AppTheme.light()
                  : AppTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  highContrast: state.increasedContrast,
                  disableAnimations: state.reduceMotion,
                  textScaler: TextScaler.linear(state.textScale),
                ),
                child: GlassAdaptiveScope(
                  // 一般態固定採同一個支援舊裝置的公開降級路徑，避免非同步 shader
                  // 載入讓兩次像素取樣不同。無障礙態則驗 App 自己選擇的降級。
                  maxQuality: opaque
                      ? GlassQuality.premium
                      : GlassQuality.minimal,
                  child: child!,
                ),
              ),
              home: Center(
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: SizedBox(
                    width: 200,
                    height: 80,
                    child: ColoredBox(
                      color: background,
                      child: Builder(
                        builder: (context) {
                          final button = TextButton(
                            onPressed: () {
                              actions++;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已執行')),
                              );
                            },
                            child: const Text('操作'),
                          );
                          return Scaffold(
                            backgroundColor: Colors.transparent,
                            body: SizedBox.expand(
                              child: reference
                                  ? GlassContainer(
                                      useOwnLayer: true,
                                      allowElevation: true,
                                      clipBehavior: Clip.antiAlias,
                                      shape: const LiquidRoundedSuperellipse(
                                        borderRadius: 28,
                                      ),
                                      child: button,
                                    )
                                  : TpGlassSurface(child: button),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
      Future<List<int>> sample() async {
        await tester.pumpAndSettle();
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        late List<int> pixel;
        await tester.runAsync(() async {
          final layer = boundary.debugLayer! as OffsetLayer;
          final image = await layer.toImage(boundary.paintBounds);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          // 左下方遠離按鈕文字與圓角，取實際合成後的背景。
          final offset = (60 * image.width + 30) * 4;
          pixel = List.generate(4, (i) => data.getUint8(offset + i));
          image.dispose();
        });
        return pixel;
      }

      await tester.pumpWidget(scene(reference: !opaque));
      final referencePixel = await sample();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        scene(background: opaque ? Colors.white : Colors.black),
      );
      final actualPixel = await sample();
      expect(
        actualPixel,
        referencePixel,
        reason: opaque ? '不透明表面不應因後方黑白背景改變' : '共同表面應沿用套件預設材質，不疊加舊版校準填色',
      );
      await tester.tap(find.text('操作'));
      await tester.pump();
      expect(actions, 1);
      expect(find.text('已執行'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
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
      final expectsOpaqueGlass =
          state.increasedContrast || state.reduceTransparency;
      expect(
        headerGlass.settings!.glassColor.a,
        expectsOpaqueGlass ? 1 : lessThan(1),
      );
      // 一般態的邊緣由新版材質處理；提高對比才補可見邊界。
      final headerShape = headerGlass.shape as LiquidRoundedSuperellipse;
      expect(
        headerShape.side.color.a,
        state.increasedContrast ? greaterThan(0.5) : 0,
        reason: '只有提高對比才補實心邊界',
      );

      final scheme = Theme.of(
        tester.element(find.byType(AppleRootTabBar)),
      ).colorScheme;
      (double, double, double) rgb(Color color) => (color.r, color.g, color.b);
      final selector = tester.widget<GlassSegmentedControl>(
        find.byType(GlassSegmentedControl),
      );
      final selectedDayFill = selector.indicatorColor!;
      expect(selectedDayFill, scheme.surfaceContainerHigh);
      expect(
        tester.getSize(find.byKey(const ValueKey('day-2-option'))).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.widget<Text>(find.text('DAY 2')).style?.color,
        scheme.primary,
      );
      if (expectsOpaqueGlass) {
        expect(selector.backgroundColor, scheme.surfaceContainerLow);
        expect(selector.quality, GlassQuality.minimal);
      }

      if (expectsOpaqueGlass) {
        expect(
          _selectedPillColor(tester),
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
        expect(
          rgb(_selectedPillColor(tester)),
          isNot(rgb(scheme.primary)),
          reason: '品牌柔褐不得鋪成 root tab 選取膠囊的背景',
        );
        final tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
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

      // 所有真正渲染的root tab字符都採同一組實心圖示，不依賴選取層實作。
      final icons = tester
          .widgetList<Icon>(
            find.descendant(
              of: find.byKey(const ValueKey('apple-root-tab-bar')),
              matching: find.byType(Icon),
            ),
          )
          .map((icon) => icon.icon)
          .toSet();
      expect(icons, {
        CupertinoIcons.chat_bubble_fill,
        CupertinoIcons.briefcase_fill,
        CupertinoIcons.map_fill,
        CupertinoIcons.heart_fill,
      });

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
              child: TpMediaBackdropScope(
                onMedia: true,
                child: TpRootScaffold(
                  header: TpRootHeaderConfig(
                    title: const Text('地圖'),
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
