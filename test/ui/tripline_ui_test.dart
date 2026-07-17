import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_bottom_accessory.dart';
import 'package:tripline/ui/tp_content_surface.dart';
import 'package:tripline/ui/tp_horizontal_selector.dart';
import 'package:tripline/ui/tp_root_scroll_scaffold.dart';
import 'package:tripline/ui/tp_scope_menu.dart';
import 'package:tripline/ui/tp_settings_group.dart';
import 'package:tripline/ui/tp_state_view.dart';

Widget app(Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
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

  testWidgets('TpRootScrollScaffold 頁首恆為 inline 56，不放大也不收合', (tester) async {
    // 大標題吃掉 96-108pt 卻只重複 tab bar 已經講過的頁名。root 頁改為 inline，
    // 省下的高度換成內容（同一螢幕多看到一張卡）。
    await tester.pumpWidget(
      app(
        const TpRootScrollScaffold(
          title: '我的行程',
          actions: [
            IconButton(onPressed: null, icon: Icon(Icons.upload_outlined)),
            IconButton(onPressed: null, icon: Icon(Icons.swap_vert)),
          ],
          slivers: [SliverToBoxAdapter(child: Text('內容'))],
        ),
      ),
    );

    expect(find.text('我的行程'), findsWidgets);
    expect(
      find.byKey(const ValueKey('root-scroll-bottom-inset')),
      findsOneWidget,
    );
    final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(appBar.toolbarHeight, 56);
    expect(appBar.collapsedHeight, 56);
    // 展開高度必須等於 collapsed —— 有落差就是大標題還在。
    expect(appBar.expandedHeight, 56);
    expect(appBar.centerTitle, isTrue);
    expect(appBar.leadingWidth, TpSpacing.tapMin * 2);
    expect(appBar.actions, hasLength(1));
    expect((appBar.actions!.single as SizedBox).width, TpSpacing.tapMin * 2);

    // 實測頁首佔用高度：inline 56，不是 large 的 108。
    expect(tester.getSize(find.byType(AppBar)).height, 56);
  });

  testWidgets('TpAppBar more 使用水平 ellipsis 且維持 44pt target', (tester) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          appBar: TpAppBar(
            title: const Text('行程'),
            actions: [
              TpMoreMenuButton<int>(
                items: const [PopupMenuItem(value: 1, child: Text('列印'))],
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
            title: Text('沖繩家族旅行超長名稱與完整行程設定'),
            actions: [IconButton(onPressed: null, icon: Icon(Icons.edit))],
          ),
        ),
        textScale: 2,
      ),
    );

    final titleStyle = tester.widget<DefaultTextStyle>(
      find.byKey(const ValueKey('tp-app-bar-title')),
    );
    expect(titleStyle.maxLines, 1);
    expect(titleStyle.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TpAppBar 兩個 trailing actions 仍維持幾何置中', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        const Scaffold(
          appBar: TpAppBar(
            automaticallyImplyLeading: false,
            title: Text('行程標題'),
            actions: [
              IconButton(onPressed: null, icon: Icon(Icons.edit)),
              IconButton(onPressed: null, icon: Icon(Icons.more_horiz)),
            ],
          ),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.automaticallyImplyLeading, isFalse);
    expect(appBar.leadingWidth, TpSpacing.tapMin * 2);
    expect(appBar.actions, hasLength(1));
    expect((appBar.actions!.single as SizedBox).width, TpSpacing.tapMin * 2);
    expect(tester.getCenter(find.text('行程標題')).dx, closeTo(160, 0.1));
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

  testWidgets('TpHorizontalSelector 提供玻璃水平選項與 44pt target', (tester) async {
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
      find.descendant(of: selector, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('day-overview'))).height,
      greaterThanOrEqualTo(TpSpacing.tapMin),
    );
    await tester.tap(find.byKey(const ValueKey('day-1')));
    expect(selected, 1);
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

  testWidgets('TpBottomAccessory 自行避讓 root tab 並維持固定高度', (tester) async {
    const bottomInset = 34.0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(
                bottom:
                    TpRootTabGeometry.expandedBarHeight +
                    TpRootTabGeometry.bottomSpacing +
                    bottomInset,
              ),
              viewPadding: EdgeInsets.only(bottom: bottomInset),
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
      TpRootTabGeometry.expandedHeightFor(bottomInset) + TpSpacing.s3,
    );
    expect(find.text('horizontal pages'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);
  });
}
