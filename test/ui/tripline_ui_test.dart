import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/features/trips/trip_title_button.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_action_item.dart';
import 'package:tripline/ui/tp_bottom_accessory.dart';
import 'package:tripline/ui/tp_content_surface.dart';
import 'package:tripline/ui/tp_glass_surface.dart';
import 'package:tripline/ui/tp_horizontal_selector.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';
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

  testWidgets('TpSettingsRow 帶 value 時 chevron 仍貼齊右緣', (tester) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TpSettingsGroup(
            children: [
              TpSettingsRow(title: '外觀', value: '跟隨系統', onTap: () {}),
              TpSettingsRow(title: '通知', onTap: () {}),
            ],
          ),
        ),
      ),
    );

    final chevrons = find.byIcon(CupertinoIcons.chevron_forward);
    expect(chevrons, findsNWidgets(2));
    final rowRight = tester.getRect(find.byType(TpSettingsRow).first).right;
    final chevronWithValue = tester.getRect(chevrons.first);
    final chevronWithoutValue = tester.getRect(chevrons.last);

    expect(
      chevronWithValue.right,
      moreOrLessEquals(chevronWithoutValue.right, epsilon: 0.5),
    );
    expect(
      chevronWithValue.right,
      moreOrLessEquals(rowRight - TpSpacing.s4, epsilon: 0.5),
    );
    expect(
      tester.getRect(find.text('跟隨系統')).right,
      moreOrLessEquals(chevronWithValue.left - TpSpacing.s2, epsilon: 0.5),
    );
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
    final buttons = tester.getRect(find.byType(IconButton).first);
    final more = tester.getRect(find.byType(IconButton).last);
    expect(buttons.width, greaterThanOrEqualTo(44));
    expect(more.width, greaterThanOrEqualTo(44));
    expect(more.left - buttons.right, greaterThanOrEqualTo(8));
    expect(
      tester.getTopLeft(find.text('行程標題')).dx,
      greaterThanOrEqualTo(tester.getTopLeft(find.byType(GlassAppBar)).dx),
    );
    expect(
      tester.getRect(find.text('行程標題')).right,
      lessThan(tester.getRect(find.byIcon(Icons.edit)).left),
    );
  });

  testWidgets('TpHorizontalSelector 保留穩定操作 key、DAY 字級與點選', (tester) async {
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
              TpScopeOption(value: 1, label: 'DAY 01', key: ValueKey('day-1')),
            ],
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    final selector = find.byKey(const ValueKey('day-selector'));
    expect(
      tester.getSize(selector).height,
      greaterThanOrEqualTo(TpSpacing.tapMin),
    );
    expect(find.byKey(const ValueKey('day-overview')), findsOneWidget);
    expect(find.byKey(const ValueKey('day-1')), findsOneWidget);
    expect(find.text('DAY 01'), findsOneWidget);
    expect(tester.widget<Text>(find.text('DAY 01')).style?.fontSize, 13);
    expect(find.byKey(const ValueKey('tp-selector-divider-0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('day-1')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  testWidgets('日期選擇器以公開套件控制項共用導覽材質', (tester) async {
    // #155 把軌換成 `BackdropFilter` 的理由是「玻璃在純色頁面上等於無色」——
    // 那是**模擬器**的假象（模擬器不渲染 LiquidGlass 的材質邊緣光），真機上
    // 玻璃膠囊清楚可見。#169 改回玻璃，材質參數與頂部膠囊、底部 tab 同源。
    late LiquidGlassSettings chrome;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              chrome = tpNavigationGlassSettings(context);
              return TpHorizontalSelector<int>(
                key: const ValueKey('glass-track'),
                value: 1,
                options: const [
                  TpScopeOption(value: 0, label: 'DAY 1'),
                  TpScopeOption(value: 1, label: 'DAY 2'),
                ],
                onSelected: (_) {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selector = find.byKey(const ValueKey('glass-track'));
    final glass = tester.widget<GlassSegmentedControl>(
      find.descendant(
        of: selector,
        matching: find.byType(GlassSegmentedControl),
      ),
    );
    expect(glass.settings, chrome);
    expect(glass.selectionAlignment, SegmentSelectionAlignment.center);
    expect(glass.dragBehavior, SegmentDragBehavior.scroll);
    expect(
      find.descendant(of: selector, matching: find.byType(GlassContainer)),
      findsNothing,
    );
  });

  testWidgets('bar 字符依底下內容亮度切換，媒體背景加暗化層', (tester) async {
    for (final isDark in [false, true]) {
      final theme = isDark ? AppTheme.dark() : AppTheme.light();
      for (final onMedia in [false, true]) {
        // 換主題要先清場，否則 element tree 被重用、拿到上一輪的玻璃設定。
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: TpMediaBackdropScope(
              onMedia: onMedia,
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
                  slivers: [SliverToBoxAdapter(child: Text('內容'))],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final reason = 'isDark=$isDark onMedia=$onMedia';
        final glass = tester.widget<GlassContainer>(
          find.descendant(
            of: find.byKey(const ValueKey('tp-root-glass-header')),
            matching: find.byType(GlassContainer),
          ),
        );

        if (onMedia) {
          // 清透玻璃加約 35% 暗化層 —— 地圖圖磚恆為亮色，深淺模式都要暗化。
          expect(
            glass.settings!.glassColor,
            Colors.black.withValues(alpha: tpMediaScrimOpacity),
            reason: reason,
          );
        } else {
          expect(glass.settings!.glassColor.a, lessThan(1), reason: reason);
        }

        // 字符走單色標籤語意色，媒體背景上改亮色 —— 不是依 app 的明暗模式。
        final iconColor = IconTheme.of(
          tester.element(find.byIcon(CupertinoIcons.share)),
        ).color;
        expect(
          iconColor,
          onMedia ? Colors.white : theme.colorScheme.onSurface,
          reason: reason,
        );
      }
    }
  });

  testWidgets('標題下拉箭頭是次要文字色，標題本身維持標籤色', (tester) async {
    for (final onMedia in [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: TpMediaBackdropScope(
            onMedia: onMedia,
            child: TpRootScaffold(
              header: TpRootHeaderConfig(
                title: TripTitleButton(
                  currentTripId: 'trip-1',
                  currentTitle: '沖繩四日',
                  trips: const [
                    TripSummary(tripId: 'trip-1', name: '沖繩四日'),
                    TripSummary(tripId: 'trip-2', name: '東京三日'),
                  ],
                  onSelected: (_) {},
                ),
              ),
              body: const TpRootScrollView(
                slivers: [SliverToBoxAdapter(child: Text('內容'))],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final reason = 'onMedia=$onMedia';
      final expectedTitle = onMedia
          ? Colors.white
          : AppTheme.light().colorScheme.onSurface;

      // 標題維持標籤色（媒體背景上是暗化後的亮色）。
      final titleButton = tester.widget<TextButton>(
        find.ancestor(of: find.text('沖繩四日'), matching: find.byType(TextButton)),
      );
      expect(
        titleButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
        expectedTitle,
        reason: reason,
      );

      // 箭頭是次要提示，必須比標題淡 —— 不能與標題同色。
      final chevron = tester.widget<Icon>(
        find.byIcon(CupertinoIcons.chevron_down),
      );
      expect(chevron.color, isNotNull, reason: reason);
      expect(
        chevron.color!.a,
        lessThan(expectedTitle.a),
        reason: '$reason：箭頭與標題同色就看不出主次',
      );
      expect(chevron.color!.a, closeTo(0.6, 0.01), reason: reason);
      expect(
        (chevron.color!.r, chevron.color!.g, chevron.color!.b),
        (expectedTitle.r, expectedTitle.g, expectedTitle.b),
        reason: '$reason：箭頭沿用 bar 前景色，只降不透明度',
      );
    }
  });

  testWidgets('日期選擇器選取態是中性膠囊加品牌 tint 前景', (tester) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TpHorizontalSelector<int>(
            key: const ValueKey('day-selector'),
            value: 1,
            options: const [
              TpScopeOption(value: 0, label: '總覽'),
              TpScopeOption(value: 1, label: 'DAY 1'),
            ],
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final scheme = AppTheme.light().colorScheme;
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<GlassSegmentedControl>(find.byType(GlassSegmentedControl))
          .indicatorColor,
      scheme.surfaceContainerHigh,
    );
    // 品牌色只出現在前景；未選取維持中性次要前景。
    expect(
      tester.widget<Text>(find.text('DAY 1')).style?.color,
      scheme.primary,
    );
    expect(
      tester.widget<Text>(find.text('總覽')).style?.color,
      scheme.onSurfaceVariant,
    );
  });

  testWidgets('日期選擇器長標籤不截斷且 Dynamic Type 只計一次', (tester) async {
    const short = '全';
    const mid = 'DAY 1';
    const long = '2026/07/25（六）';

    Future<Map<String, double>> widthsAt(double scale) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: TpHorizontalSelector<int>(
              value: 0,
              options: const [
                TpScopeOption(value: 0, label: short, key: ValueKey('w-short')),
                TpScopeOption(value: 1, label: mid, key: ValueKey('w-mid')),
                TpScopeOption(value: 2, label: long, key: ValueKey('w-long')),
              ],
              onSelected: (_) {},
            ),
          ),
          textScale: scale,
        ),
      );
      await tester.pump();
      return {
        for (final key in ['w-short', 'w-mid', 'w-long'])
          key: tester.getSize(find.byKey(ValueKey(key))).width,
      };
    }

    final at1 = await widthsAt(1);

    // 量測取代字元數階梯：標籤越長欄位越寬，不再是同一級距擠在一起。
    expect(at1['w-long']!, greaterThan(at1['w-mid']!));
    expect(at1['w-mid']!, greaterThan(at1['w-short']!));

    // 量測後短標籤仍不得低於最小點擊尺寸。
    expect(at1['w-short']!, greaterThanOrEqualTo(TpSpacing.tapMin));

    // 長標籤要有足夠欄位，不被 ellipsis 截斷、不折行。
    final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
    expect(paragraph.didExceedMaxLines, isFalse);

    final at2 = await widthsAt(2);
    for (final entry in at2.entries) {
      expect(
        entry.value,
        greaterThanOrEqualTo(TpSpacing.tapMin),
        reason: entry.key,
      );
    }

    // Dynamic Type 只被計入一次：量測本身已含縮放，若再乘一次會逼近四倍。
    final ratio = at2['w-long']! / at1['w-long']!;
    expect(ratio, greaterThan(1.5));
    expect(ratio, lessThan(3));
  });

  testWidgets('導覽玻璃的兩種配方同源，媒體背景保留暗化層', (tester) async {
    // 這組斷言原本掛在日期選擇器上，但選擇器已改成實心分段控制項、不再用
    // 玻璃。配方本身仍由頁首與 root tab bar 使用，所以改成直接對配方斷言，
    // 不透過任何 widget。
    late LiquidGlassSettings standard;
    late LiquidGlassSettings map;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) {
            standard = tpNavigationGlassSettings(context);
            map = tpNavigationGlassSettings(
              context,
              recipe: TpNavigationGlassRecipe.platformView,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(standard.glassColor.a, lessThan(1));
    expect(map.glassColor.a, closeTo(tpMediaScrimOpacity, 0.01));
    // 兩種情境共用新版光學預設，媒體背景另外保留可讀暗化層。
    expect(map.blur, standard.blur);
    expect(map.chromaticAberration, standard.chromaticAberration);
    expect(map.refractiveIndex, standard.refractiveIndex);
  });

  testWidgets('選擇器不因所在背景而改變外觀：地圖上與一般頁面同一塊玻璃軌', (tester) async {
    // 軌不隨背景切配方 —— 先前那顆 `platformViewBackdrop` 參數已移除，
    // 兩處必須拿到逐項相同的材質設定。
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Column(
            children: [
              for (final key in ['selector-a', 'selector-b'])
                TpHorizontalSelector<int>(
                  key: ValueKey(key),
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

    expect(find.byType(GlassSegmentedControl), findsNWidgets(2));
    expect(
      tester
          .widget<GlassSegmentedControl>(
            find.descendant(
              of: find.byKey(const ValueKey('selector-a')),
              matching: find.byType(GlassSegmentedControl),
            ),
          )
          .settings,
      tester
          .widget<GlassSegmentedControl>(
            find.descendant(
              of: find.byKey(const ValueKey('selector-b')),
              matching: find.byType(GlassSegmentedControl),
            ),
          )
          .settings,
    );
  });

  testWidgets('Reduce Transparency 使用不透明且無模糊的 selector 選取底色', (tester) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TpHorizontalSelector<int>(
            value: 1,
            options: const [
              TpScopeOption(value: 0, label: '總覽'),
              TpScopeOption(
                value: 1,
                label: 'DAY 1',
                key: ValueKey('reduce-transparency-day-1'),
              ),
            ],
            onSelected: (_) {},
          ),
        ),
        reduceTransparency: true,
      ),
    );

    final control = tester.widget<GlassSegmentedControl>(
      find.byType(GlassSegmentedControl),
    );
    expect(control.quality, GlassQuality.minimal);
    expect(
      control.backgroundColor,
      AppTheme.light().colorScheme.surfaceContainerLow,
    );
    expect(
      control.indicatorColor,
      AppTheme.light().colorScheme.surfaceContainerHigh,
    );
  });

  testWidgets('降低動態效果時日期選擇器的置中捲動不經過中間位置', (tester) async {
    tester.view.physicalSize = const Size(240, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 1;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: GlassAccessibilityScope(
              reduceMotion: true,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return TpHorizontalSelector<int>(
                    value: selected,
                    options: [
                      for (var day = 1; day <= 12; day++)
                        TpScopeOption(value: day, label: 'DAY $day'),
                    ],
                    onSelected: (value) => setState(() => selected = value),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.text('DAY 1')).dx;
    update(() => selected = 9);
    await tester.pump();
    final positions = <double>[];
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      positions.add(tester.getTopLeft(find.text('DAY 1')).dx);
    }
    final last = positions.last;
    expect(last, lessThan(first - 100));
    expect(
      positions.every((x) => (x - first).abs() < 0.1 || (x - last).abs() < 0.1),
      isTrue,
    );
  });

  testWidgets('日期選擇器同數量選項重排後仍顯示選中 Day', (tester) async {
    tester.view.physicalSize = const Size(240, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> show(List<int> days) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: TpHorizontalSelector<int>(
              key: const ValueKey('reordered-selector'),
              value: 1,
              options: [
                for (final day in days)
                  TpScopeOption(
                    value: day,
                    label: 'DAY $day',
                    key: ValueKey('reordered-$day'),
                  ),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(List.generate(12, (index) => index + 1));
    await show([for (var day = 2; day <= 12; day++) day, 1]);
    final viewport = tester.getRect(
      find.byKey(const ValueKey('reordered-selector')),
    );
    final selected = tester.getRect(find.byKey(const ValueKey('reordered-1')));
    expect(selected.left, greaterThanOrEqualTo(viewport.left));
    expect(selected.right, lessThanOrEqualTo(viewport.right));
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

  testWidgets('日期選擇器水平拖曳只瀏覽，點選才更新 Day', (tester) async {
    tester.view.physicalSize = const Size(240, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 1;
    var calls = 0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TpHorizontalSelector<int>(
              value: selected,
              options: [
                for (var day = 1; day <= 12; day++)
                  TpScopeOption(
                    value: day,
                    label: 'DAY $day',
                    key: ValueKey('drag-$day'),
                  ),
              ],
              onSelected: (value) => setState(() {
                selected = value;
                calls++;
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final start = tester.getTopLeft(find.text('DAY 1'));
    await tester.drag(
      find.byType(TpHorizontalSelector<int>),
      const Offset(-150, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('DAY 1')).dx, lessThan(start.dx));
    expect(calls, 0);
    expect(selected, 1);
    await tester.ensureVisible(find.byKey(const ValueKey('drag-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drag-5')));
    await tester.pumpAndSettle();
    expect(selected, 5);
    expect(calls, 1);
  });

  testWidgets('目前 Day 可再次點選與讀屏啟用，水平拖曳不觸發回呼', (tester) async {
    tester.view.physicalSize = const Size(240, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TpHorizontalSelector<int>(
            value: 1,
            options: [
              for (var day = 1; day <= 12; day++)
                TpScopeOption(
                  value: day,
                  label: 'DAY $day',
                  semanticsLabel: '第 $day 天，共 12 天',
                  key: ValueKey('reselect-$day'),
                ),
            ],
            onSelected: (_) => calls++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('reselect-1')),
      const Offset(-70, 0),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.ensureVisible(find.byKey(const ValueKey('reselect-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reselect-1')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(calls, 1);
    final node = tester.getSemantics(find.bySemanticsLabel('第 1 天，共 12 天'));
    final actionId = CustomSemanticsAction.getIdentifier(
      const CustomSemanticsAction(label: '重新選取目前範圍'),
    );
    expect(
      node.getSemanticsData().customSemanticsActionIds,
      contains(actionId),
    );
    node.owner!.performAction(
      node.id,
      ui.SemanticsAction.customAction,
      actionId,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(calls, 2);
    final unlabeledActions = <SemanticsNode>[];
    void collect(SemanticsNode current) {
      final data = current.getSemanticsData();
      if (data.flagsCollection.isButton &&
          data.hasAction(ui.SemanticsAction.tap) &&
          data.label.isEmpty) {
        unlabeledActions.add(current);
      }
      current.visitChildren((child) {
        collect(child);
        return true;
      });
    }

    collect(tester.getSemantics(find.byType(TpHorizontalSelector<int>)));
    expect(unlabeledActions, isEmpty, reason: '每個可啟用的 Day 節點都必須有完整標籤，不增加空白按鈕');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(calls, 4);
  });

  testWidgets('日期選擇器點選後左右鍵可切換且邊界不溢出', (tester) async {
    var selected = 1;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TpHorizontalSelector<int>(
              value: selected,
              options: const [
                TpScopeOption(value: 1, label: 'DAY 1'),
                TpScopeOption(value: 2, label: 'DAY 2'),
              ],
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('DAY 1'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(selected, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(selected, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  testWidgets('深色日期選擇器保留完整 Day 語意與讀屏啟用', (tester) async {
    final semantics = tester.ensureSemantics();

    var selected = 1;
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TpHorizontalSelector<int>(
              value: selected,
              options: const [
                TpScopeOption(
                  value: 1,
                  label: 'DAY 1',
                  semanticsLabel: '第 1 天，共 2 天',
                ),
                TpScopeOption(
                  value: 2,
                  label: 'DAY 2',
                  semanticsLabel: '第 2 天，共 2 天',
                ),
              ],
              onSelected: (value) => setState(() {
                selected = value;
                calls++;
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.bySemanticsLabel('第 2 天，共 2 天'));
    node.owner!.performAction(node.id, ui.SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(calls, 1);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('第 2 天，共 2 天'))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    expect(
      tester.widget<Text>(find.text('DAY 2')).style?.color,
      AppTheme.dark().colorScheme.primary,
    );
    semantics.dispose();
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
              children: [
                TpMediaBackdropScope(
                  onMedia: true,
                  child: TpBottomAccessory(child: Text('horizontal pages')),
                ),
              ],
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
    expect(
      glass.settings?.glassColor,
      Colors.black.withValues(alpha: tpMediaScrimOpacity),
    );
    expect(find.byType(AnimatedContainer), findsNothing);

    // 對照組:沒有媒體背景時 accessory 要讀到 false,不是寫死 true。
    await tester.pumpWidget(
      app(
        const Scaffold(
          body: Stack(
            children: [
              TpMediaBackdropScope(
                onMedia: false,
                child: TpBottomAccessory(child: Text('plain')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final plainGlass = tester.widget<GlassContainer>(
      find.descendant(
        of: find.byType(TpBottomAccessory),
        matching: find.byType(GlassContainer),
      ),
    );
    expect(plainGlass.platformViewBackdrop, isFalse);
  });
}
