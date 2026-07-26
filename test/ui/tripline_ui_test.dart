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
    final menu = tester.widget<RawMenuAnchor>(
      find.descendant(
        of: find.byType(TpMoreMenuButton<int>),
        matching: find.byType(RawMenuAnchor),
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

  testWidgets('TpHorizontalSelector 使用單一半透明軌 + 一塊選取填色與 13pt DAY 字級', (
    tester,
  ) async {
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
    // 軌與選取膠囊都是自己畫的半透明填色 + `BackdropFilter` —— LiquidGlass
    // shader 會把 tint 衰減到約 14%，巢狀玻璃的顏色又會被母層吃掉，兩者
    // 都讓顏色變得不可控。
    expect(selectedPillFill(tester, selector).a, closeTo(0.92, 0.001));
    expect(
      find.descendant(of: selector, matching: find.byType(BackdropFilter)),
      findsOneWidget,
      reason: '半透明軌要真的模糊背後內容',
    );
    expect(
      find.descendant(of: selector, matching: find.byType(GlassButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: selector, matching: find.byType(GlassContainer)),
      findsNothing,
    );
    expect(tester.getSize(selector).height, TpSpacing.tapMin);
    expect(find.text('DAY 01'), findsOneWidget);
    expect(tester.widget<Text>(find.text('DAY 01')).style?.fontSize, 13);
    expect(find.byKey(const ValueKey('tp-selector-divider-0')), findsNothing);
    await tester.tap(find.bySemanticsLabel('DAY 01'));
    expect(selected, 1);
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
            home: TpRootScaffold(
              header: TpRootHeaderConfig(
                title: const Text('地圖'),
                platformViewBackdrop: onMedia,
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
          expect(
            glass.settings!.glassColor.a,
            closeTo(isDark ? 0.48 : 0.40, 0.01),
            reason: reason,
          );
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
          home: TpRootScaffold(
            header: TpRootHeaderConfig(
              platformViewBackdrop: onMedia,
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
    final pill = selectedPillFill(
      tester,
      find.byKey(const ValueKey('day-selector')),
    );

    // 膠囊底走中性語意層，品牌柔褐不再當背景鋪滿。
    (double, double, double) rgb(Color c) => (c.r, c.g, c.b);
    // Apple 分段控制項：選取膠囊比軌更亮（淺色是白），靠浮起表達選取。
    expect(rgb(pill), rgb(scheme.surface));
    expect(rgb(pill), isNot(rgb(scheme.primary)));

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

  testWidgets('日期選擇器欄寬改量測，長標籤不截斷且 Dynamic Type 只計一次', (tester) async {
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

  testWidgets('導覽玻璃的兩種配方同源，媒體背景只做平面化', (tester) async {
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

    expect(standard.glassColor.a, closeTo(0.40, 0.01));
    expect(map.glassColor.a, closeTo(tpMediaScrimOpacity, 0.01));
    // 媒體背景是刻意的清透變體：平面化（無色散、低折射率）避免 platform
    // view 上出現彩邊與扭曲；其餘光學參數與一般背景同源。
    expect(map.blur, standard.blur);
    expect(map.standardOpacityMultiplier, standard.standardOpacityMultiplier);
    expect(map.chromaticAberration, 0);
    expect(map.refractiveIndex, 1.06);
    expect(standard.chromaticAberration, greaterThan(0));
    expect(standard.refractiveIndex, greaterThan(1.06));
    // 邊緣光兩邊都要開著，否則又得靠描邊補回來。
    expect(map.ambientRim, greaterThan(0));
    expect(standard.ambientRim, greaterThan(0));
  });

  testWidgets('選擇器不因所在背景而改變外觀：地圖上與一般頁面同一塊實心軌', (tester) async {
    // 軌是實心的，所以沒有 platform view 疑慮 —— 先前那顆
    // `platformViewBackdrop` 參數已隨玻璃一起移除。
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

    expect(find.byType(GlassContainer), findsNothing);
    expect(
      trackFill(tester, find.byKey(const ValueKey('selector-a'))),
      trackFill(tester, find.byKey(const ValueKey('selector-b'))),
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

    // 選取底色本來就是自己畫的實心填色，Reduce Transparency 下同樣成立 ——
    // 它不經過玻璃 shader，所以不會被衰減。
    // 範圍收到選取項：Reduce Transparency 下軌道自己也會退成 ShapeDecoration。
    final pill = selectedPillFill(
      tester,
      find.byKey(const ValueKey('reduce-transparency-day-1')),
    );
    expect(pill.a, 1);
    expect(pill, AppTheme.light().colorScheme.surface);
    expect(
      find.descendant(
        of: find.byType(TpHorizontalSelector<int>),
        matching: find.byType(GlassButton),
      ),
      findsNothing,
      reason: '巢狀玻璃的顏色會被軌道母層吃掉，選取態不得再用 GlassButton',
    );
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

  testWidgets('選擇器是 Apple 分段控制項：Gray6 實心軌 + 比軌更亮的膠囊', (tester) async {
    // 玻璃軌在純色頁面上等於無色（導覽配方的 tint 淺色是 `surface`＝白），
    // 看不出「這是一組四選一」。改成 iOS `UISegmentedControl` 的實心軌。
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TpHorizontalSelector<int>(
            key: const ValueKey('segmented'),
            value: 1,
            options: const [
              TpScopeOption(value: 0, label: 'DAY 1'),
              TpScopeOption(
                value: 1,
                label: 'DAY 2',
                key: ValueKey('segmented-day-2'),
              ),
            ],
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scheme = AppTheme.light().colorScheme;
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('segmented')),
        matching: find.byType(GlassContainer),
      ),
      findsNothing,
      reason: '不走 LiquidGlass shader —— 它會把 tint 衰減到顏色不可控',
    );
    expect(
      trackFill(tester, find.byKey(const ValueKey('segmented'))),
      scheme.surfaceContainerLow.withValues(alpha: 0.80),
      reason: '軌是半透明的，內容要能透出來',
    );
    expect(
      selectedPillFill(tester, find.byKey(const ValueKey('segmented-day-2'))),
      scheme.surface.withValues(alpha: 0.92),
      reason: '淺色的選取膠囊比軌更亮（Apple 是靠浮起表達選取）',
    );
  });

  testWidgets('選取膠囊是實際畫上去的填色，不倚賴會被母層吃掉的玻璃 tint', (tester) async {
    // 軌道是 `GlassContainer(useOwnLayer: true)`，會建立 LiquidGlassLayer；
    // 巢狀在裡面的子玻璃會被合併進母層，子層自己的 `glassColor` 不生效。
    // 模擬器實測：選取態與未選在淺色下都是 #FFFFFF（差 0），深色是
    // #080808 vs #040404（差 4/255），改子層 alpha 逐位元零差異。
    // 所以選取指示器必須是真的畫上去的不透明填色。
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TpHorizontalSelector<int>(
            value: 1,
            options: const [
              TpScopeOption(value: 0, label: 'DAY 1'),
              TpScopeOption(
                value: 1,
                label: 'DAY 2',
                key: ValueKey('fill-day-2'),
              ),
            ],
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scheme = AppTheme.light().colorScheme;
    final decorated = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('fill-day-2')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final fills = decorated
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .where((deco) => deco.color != null)
        .toList();
    expect(fills, isNotEmpty, reason: '選取態要有一層自己畫的 ShapeDecoration 填色');
    expect(fills.single.color, scheme.surface.withValues(alpha: 0.92));
  });

  testWidgets('深色日期 selector 的選取膠囊同樣是中性語意層，不鋪品牌柔褐', (tester) async {
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

    final scheme = AppTheme.dark().colorScheme;
    final pill = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('dark-day-1')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .where((deco) => deco.color != null)
        .single
        .color!;
    expect(
      (pill.r, pill.g, pill.b),
      (
        scheme.surfaceContainerHighest.r,
        scheme.surfaceContainerHighest.g,
        scheme.surfaceContainerHighest.b,
      ),
    );
    expect(
      (pill.r, pill.g, pill.b),
      isNot((
        TpSystemColorsDark.tint.r,
        TpSystemColorsDark.tint.g,
        TpSystemColorsDark.tint.b,
      )),
    );
    // 深色的軌是半透明的 systemGray6，內容要能透出來。
    expect(
      trackFill(tester, find.byType(TpHorizontalSelector<int>)),
      scheme.surfaceContainerLow.withValues(alpha: 0.72),
    );
    expect(find.byType(GlassContainer), findsNothing);
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

/// 取選取膠囊自己畫的填色。
///
/// 選取態不是玻璃：軌道用 `useOwnLayer: true` 建立 LiquidGlassLayer，巢狀
/// 在裡面的子玻璃會被合併進母層，子層自己的 `glassColor` 畫不出來。
Color selectedPillFill(WidgetTester tester, Finder scope) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: scope, matching: find.byType(DecoratedBox)),
    )
    .map((box) => box.decoration)
    .whereType<ShapeDecoration>()
    .where((deco) => deco.color != null)
    .last
    .color!;

/// 取選擇器軌道自己畫的填色（最外層那一塊）。
Color trackFill(WidgetTester tester, Finder scope) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: scope, matching: find.byType(DecoratedBox)),
    )
    .map((box) => box.decoration)
    .whereType<ShapeDecoration>()
    .where((deco) => deco.color != null)
    .first
    .color!;
