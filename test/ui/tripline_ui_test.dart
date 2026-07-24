import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_action_item.dart';
import 'package:tripline/ui/tp_bottom_accessory.dart';
import 'package:tripline/ui/tp_content_surface.dart';
import 'package:tripline/ui/tp_glass_surface.dart';
import 'package:tripline/ui/tp_horizontal_selector.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';
import 'package:tripline/ui/tp_scope_menu.dart';
import 'package:tripline/ui/tp_settings_group.dart';
import 'package:tripline/ui/tp_state_view.dart';

Widget app(
  Widget child, {
  double textScale = 1,
  bool reduceTransparency = false,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: AppAccessibilityScope(
      reduceTransparency: reduceTransparency,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('TpStateView error 保留訊息與單一 recovery action', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TpStateView(
            kind: TpStateKind.error,
            title: '無法載入行程',
            message: '請檢查連線後再試一次。',
            actionLabel: '重試',
            onAction: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text('無法載入行程'), findsOneWidget);
    expect(find.text('請檢查連線後再試一次。'), findsOneWidget);
    await tester.tap(find.text('重試'));
    expect(retries, 1);
  });

  testWidgets('TpSettingsGroup 在 200% 文字仍保留 44pt row 與 disclosure', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: TpSettingsGroup(
              title: '安全性',
              children: [
                TpSettingsRow(
                  title: '登入裝置',
                  subtitle: '管理目前登入中的裝置',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        textScale: 2,
      ),
    );

    expect(find.text('登入裝置'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_forward), findsOneWidget);
    expect(
      tester.getSize(find.byType(TpSettingsRow)).height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TpSettingsGroup 在 iOS Large 使用 HIG 設定列字級', (tester) async {
    await tester.pumpWidget(
      app(
        const Scaffold(
          body: TpSettingsGroup(
            title: '偏好',
            children: [
              TpSettingsRow(title: '外觀', subtitle: '跟隨系統', value: '自動'),
            ],
          ),
        ),
      ),
    );

    expect(tester.widget<Text>(find.text('偏好')).style?.fontSize, 13);
    expect(tester.widget<Text>(find.text('外觀')).style?.fontSize, 17);
    expect(tester.widget<Text>(find.text('跟隨系統')).style?.fontSize, 15);
    expect(tester.widget<Text>(find.text('自動')).style?.fontSize, 15);
  });

  testWidgets('TpSettingsGroup 分隔線左右各縮排 16pt', (tester) async {
    await tester.pumpWidget(
      app(
        const Scaffold(
          body: TpSettingsGroup(
            children: [
              TpSettingsRow(title: '外觀'),
              TpSettingsRow(title: '通知'),
            ],
          ),
        ),
      ),
    );

    final divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.indent, TpSpacing.s4);
    expect(divider.endIndent, TpSpacing.s4);
  });

  testWidgets('TpContentSurface 是內容材質而不是 glass', (tester) async {
    await tester.pumpWidget(
      app(
        const Scaffold(
          body: TpContentSurface(semanticLabel: '東京行程', child: Text('東京行程')),
        ),
      ),
    );

    final surface = find.byType(TpContentSurface);
    expect(surface, findsOneWidget);
    expect(
      find.descendant(of: surface, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
  });

  testWidgets('TpRootScaffold 頁首固定為 C1 單一 64pt glass 膠囊', (tester) async {
    // 大標題吃掉 96-108pt 卻只重複 tab bar 已經講過的頁名。root 頁改為 inline，
    // 省下的高度換成內容（同一螢幕多看到一張卡）。
    await tester.pumpWidget(
      app(
        const TpRootScaffold(
          header: TpRootHeaderConfig(
            title: Text('我的行程'),
            actions: [
              IconButton(onPressed: null, icon: Icon(Icons.upload_outlined)),
            ],
          ),
          body: TpRootScrollView(
            slivers: [SliverToBoxAdapter(child: Text('內容'))],
          ),
        ),
      ),
    );

    expect(find.text('我的行程'), findsWidgets);
    expect(
      find.byKey(const ValueKey('root-scroll-bottom-inset')),
      findsOneWidget,
    );
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('tp-root-glass-header'))),
      const Size(768, 64),
    );
  });

  testWidgets('TpAppBar more 使用水平 ellipsis 且維持 44pt target', (tester) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.standalone,
            title: const Text('行程'),
            actions: [
              TpMoreMenuButton<int>(
                items: const [
                  TpActionItem(value: 1, label: '列印', icon: Icons.print),
                ],
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(CupertinoIcons.ellipsis), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(
      tester.getSize(find.byType(TpMoreMenuButton<int>)).height,
      greaterThanOrEqualTo(44),
    );
    final menu = tester.widget<MenuAnchor>(
      find.descendant(
        of: find.byType(TpMoreMenuButton<int>),
        matching: find.byType(MenuAnchor),
      ),
    );
    expect(menu.useRootOverlay, isTrue);
    expect(find.byType(GlassMenu), findsNothing);
    final toolbarGlass = find.descendant(
      of: find.byType(TpMoreMenuButton<int>),
      matching: find.byKey(const ValueKey('tp-toolbar-glass-button')),
    );
    expect(toolbarGlass, findsOneWidget);
    expect(tester.getSize(toolbarGlass), const Size(44, 44));
  });

  testWidgets('TpAppBar 在窄螢幕與 200% 文字強制單行截斷', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        const Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.standalone,
            title: Text('沖繩家族旅行超長名稱與完整行程設定'),
            actions: [IconButton(onPressed: null, icon: Icon(Icons.edit))],
          ),
        ),
        textScale: 2,
      ),
    );

    final titleStyle = tester
        .widgetList<DefaultTextStyle>(
          find.descendant(
            of: find.byKey(const ValueKey('tp-app-bar-title')),
            matching: find.byType(DefaultTextStyle),
          ),
        )
        .firstWhere(
          (style) =>
              style.maxLines == 1 && style.overflow == TextOverflow.ellipsis,
        );
    expect(titleStyle.maxLines, 1);
    expect(titleStyle.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TpAppBar 兩個 trailing actions 時標題仍固定靠左', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        const Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.standalone,
            title: Text('行程標題'),
            actions: [
              IconButton(onPressed: null, icon: Icon(Icons.edit)),
              IconButton(onPressed: null, icon: Icon(Icons.more_horiz)),
            ],
          ),
        ),
      ),
    );

    final appBar = tester.widget<GlassAppBar>(find.byType(GlassAppBar));
    expect(appBar.leading, isNull);
    expect(appBar.centerTitle, isFalse);
    expect(appBar.actions, hasLength(1));
    expect(
      (appBar.actions!.single as SizedBox).width,
      TpSpacing.tapMin * 2 + TpSpacing.s2,
    );
    expect(tester.getTopLeft(find.text('行程標題')).dx, closeTo(16, 0.1));
  });

  testWidgets('TpScopeMenu 顯示目前值並回傳新選項', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TpScopeMenu<int>(
            label: '地圖 · 總覽',
            value: selected,
            options: const [
              TpScopeOption(value: 0, label: '總覽'),
              TpScopeOption(value: 1, label: 'DAY 01'),
            ],
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('地圖 · 總覽'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAY 01'));
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  testWidgets(
    'TpHorizontalSelector 使用單一 GlassContainer + active GlassButton 與 13pt DAY 字級',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: TpHorizontalSelector<int>(
              key: const ValueKey('day-selector'),
              value: selected,
              options: const [
                TpScopeOption(
                  value: 0,
                  label: '總覽',
                  key: ValueKey('day-overview'),
                ),
                TpScopeOption(
                  value: 1,
                  label: 'DAY 01',
                  key: ValueKey('day-1'),
                ),
              ],
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );

      final selector = find.byKey(const ValueKey('day-selector'));
      expect(
        find.descendant(of: selector, matching: find.byType(GlassButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: selector, matching: find.byType(GlassContainer)),
        findsOneWidget,
      );
      expect(tester.getSize(selector).height, TpSpacing.tapMin);
      expect(find.text('DAY 01'), findsOneWidget);
      expect(tester.widget<Text>(find.text('DAY 01')).style?.fontSize, 13);
      expect(find.byKey(const ValueKey('tp-selector-divider-0')), findsNothing);
      await tester.tap(find.bySemanticsLabel('DAY 01'));
      expect(selected, 1);
    },
  );

  testWidgets(
    'navigation selector keeps one optical recipe over a platform view',
    (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Column(
              children: [
                TpHorizontalSelector<int>(
                  key: const ValueKey('standard-navigation-selector'),
                  value: 1,
                  options: const [
                    TpScopeOption(value: 0, label: '總覽'),
                    TpScopeOption(value: 1, label: 'DAY 1'),
                  ],
                  onSelected: (_) {},
                ),
                TpHorizontalSelector<int>(
                  key: const ValueKey('map-navigation-selector'),
                  platformViewBackdrop: true,
                  value: 1,
                  options: const [
                    TpScopeOption(value: 0, label: '總覽'),
                    TpScopeOption(value: 1, label: 'DAY 1'),
                  ],
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      GlassContainer trackFor(String key) => tester.widget<GlassContainer>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(GlassContainer),
        ),
      );

      final standard = trackFor('standard-navigation-selector');
      final map = trackFor('map-navigation-selector');
      expect(standard.platformViewBackdrop, isFalse);
      expect(map.platformViewBackdrop, isTrue);
      expect(standard.settings?.glassColor.a, closeTo(0.40, 0.01));
      expect(map.settings?.glassColor.a, closeTo(0.56, 0.01));
      expect(map.settings?.thickness, standard.settings?.thickness);
      expect(map.settings?.blur, standard.settings?.blur);
      expect(map.settings?.lightIntensity, standard.settings?.lightIntensity);
      expect(map.settings?.ambientStrength, standard.settings?.ambientStrength);
      expect(map.settings?.refractiveIndex, standard.settings?.refractiveIndex);
      expect(map.settings?.saturation, standard.settings?.saturation);
      expect(
        map.settings?.standardOpacityMultiplier,
        standard.settings?.standardOpacityMultiplier,
      );

      final selected = tester.widget<GlassButton>(
        find.descendant(
          of: find.byKey(const ValueKey('standard-navigation-selector')),
          matching: find.byType(GlassButton),
        ),
      );
      expect(selected.settings?.blur, standard.settings?.blur);
      expect(
        selected.settings?.refractiveIndex,
        standard.settings?.refractiveIndex,
      );
    },
  );

  testWidgets('Reduce Transparency 使用不透明且無模糊的 selector 選取底色', (tester) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TpHorizontalSelector<int>(
            value: 1,
            options: const [
              TpScopeOption(value: 0, label: '總覽'),
              TpScopeOption(value: 1, label: 'DAY 1'),
            ],
            onSelected: (_) {},
          ),
        ),
        reduceTransparency: true,
      ),
    );

    final selected = tester.widget<GlassButton>(find.byType(GlassButton));
    expect(selected.settings?.blur, 0);
    expect(selected.settings?.glassColor.a, 1);
  });

  testWidgets('TpHorizontalSelector 讓長列表的初始選項保持可見', (tester) async {
    tester.view.physicalSize = const Size(240, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        Scaffold(
          body: TpHorizontalSelector<int>(
            key: const ValueKey('long-day-selector'),
            value: 8,
            options: [
              for (var day = 0; day < 10; day++)
                TpScopeOption(
                  value: day,
                  label: day == 0
                      ? '總覽'
                      : 'DAY ${day.toString().padLeft(2, '0')}',
                  key: ValueKey('long-day-$day'),
                ),
            ],
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selector = tester.getRect(
      find.byKey(const ValueKey('long-day-selector')),
    );
    final selected = tester.getRect(find.byKey(const ValueKey('long-day-8')));
    expect(selected.left, greaterThanOrEqualTo(selector.left));
    expect(selected.right, lessThanOrEqualTo(selector.right));
  });

  testWidgets('TpHorizontalSelector rejects cross-page actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TpHorizontalSelector<int>(
            value: 1,
            options: const [
              TpScopeOption(value: -1, label: '行程', isAction: true),
              TpScopeOption(value: 1, label: 'DAY 1'),
            ],
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('深色日期 selector 使用 Liquid Glass 暖褐 thumb，不使用金色實心底', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: TpHorizontalSelector<int>(
            value: 1,
            options: const [
              TpScopeOption(value: 0, label: '總覽'),
              TpScopeOption(
                value: 1,
                label: 'DAY 1',
                key: ValueKey('dark-day-1'),
              ),
            ],
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final thumb = tester.widget<GlassButton>(find.byType(GlassButton));
    expect(
      thumb.settings?.glassColor,
      TpSystemColorsDark.tint.withValues(alpha: 0.24),
    );
    final track = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(track.settings?.chromaticAberration, 0);
  });

  testWidgets('TpBottomAccessory 自行避讓 root tab 並維持固定高度', (tester) async {
    const bottomInset = 34.0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              padding: EdgeInsets.only(
                bottom: TpRootTabGeometry.expandedHeightFor(bottomInset),
              ),
              viewPadding: const EdgeInsets.only(bottom: bottomInset),
            ),
            child: const Stack(
              children: [TpBottomAccessory(child: Text('horizontal pages'))],
            ),
          ),
        ),
      ),
    );

    final accessory = find.byType(TpBottomAccessory);
    expect(tester.getSize(accessory).height, TpBottomAccessory.height);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      screenHeight - tester.getRect(accessory).bottom,
      TpRootTabGeometry.expandedHeightFor(bottomInset) + TpSpacing.s1,
    );
    expect(find.text('horizontal pages'), findsOneWidget);
    expect(
      find.descendant(of: accessory, matching: find.byType(TpGlassSurface)),
      findsOneWidget,
    );
    final glass = tester.widget<GlassContainer>(
      find.descendant(of: accessory, matching: find.byType(GlassContainer)),
    );
    expect(glass.platformViewBackdrop, isTrue);
    expect(glass.settings?.chromaticAberration, 0);
    expect(find.byType(AnimatedContainer), findsNothing);
  });
}
