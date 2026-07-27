import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_action_item.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_glass_surface.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';

Widget _app(Widget home, {MediaQueryData? mediaQueryData}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: mediaQueryData ?? const MediaQueryData(),
      child: home,
    ),
  );
}

TpRootScaffold _root({int actionCount = 0, Widget? body}) {
  return TpRootScaffold(
    header: TpRootHeaderConfig(
      title: const Text('京都五日行'),
      actions: [
        for (var index = 0; index < actionCount; index++)
          if (index == 1)
            TpMoreMenuButton<int>(
              key: ValueKey('source-action-$index'),
              onSelected: (_) {},
              items: const [
                TpActionItem(value: 1, icon: Icons.more_horiz, label: '更多'),
              ],
            )
          else
            SizedBox.square(
              key: ValueKey('source-action-$index'),
              dimension: 44,
            ),
      ],
    ),
    body:
        body ??
        const ColoredBox(key: ValueKey('full-bleed-body'), color: Colors.blue),
  );
}

void main() {
  testWidgets('root header supports a standard leading navigation action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        TpRootScaffold(
          header: TpRootHeaderConfig(
            leading: TpToolbarIconButton(
              key: const ValueKey('root-leading'),
              plain: true,
              icon: Icons.chevron_left,
              tooltip: '返回',
              onPressed: () {},
            ),
            title: const Text('單一行程'),
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('root-leading')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('root-leading'))),
      const Size(44, 44),
    );
    // 返回鍵與行程名稱是**同一組**,包在同一顆膠囊裡 —— 對照 iOS 26
    // 「訊息」app 的 `‹ 121`:返回與它所屬的內容是一組,不是兩顆各自浮著。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tp-glass-surface')),
        matching: find.byKey(const ValueKey('tp-root-header-leading')),
      ),
      findsOneWidget,
      reason: '返回鍵要與標題同一顆膠囊',
    );
    // 群組內的返回鍵不得再自帶玻璃 —— 那就是 #162 消滅掉的玻璃疊玻璃。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tp-root-header-leading')),
        matching: find.byKey(const ValueKey('tp-toolbar-glass-button')),
      ),
      findsNothing,
      reason: '群組內的返回鍵不該有自己的玻璃底',
    );
    // 返回鍵與標題之間要有間距,不能擠在一起。
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('tp-root-header-title'))).dx -
          tester.getRect(find.byKey(const ValueKey('root-leading'))).right,
      greaterThanOrEqualTo(TpSpacing.s1),
      reason: '返回鍵與標題之間要留間距',
    );
    // 標題排在返回鍵右邊(同一顆膠囊內)。
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('tp-root-header-title'))).dx,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('root-leading'))).right,
      ),
    );
  });

  testWidgets(
    'root scroll dismisses the keyboard when results start scrolling',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TpRootScaffold(
            header: const TpRootHeaderConfig(title: Text('收藏')),
            body: const TpRootScrollView(
              slivers: [SliverToBoxAdapter(child: SizedBox(height: 1200))],
            ),
          ),
        ),
      );

      final scrollView = tester.widget<CustomScrollView>(
        find.byKey(const ValueKey('tp-root-scroll-view')),
      );
      expect(
        scrollView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    },
  );

  testWidgets('Reduce Motion 下重點 root tab 會立即回頂端', (tester) async {
    final reselects = ValueNotifier<int>(0);
    addTearDown(reselects.dispose);
    await tester.pumpWidget(
      _app(
        TpRootReselectScope(
          notifier: reselects,
          child: _root(
            body: const TpRootScrollView(
              slivers: [SliverToBoxAdapter(child: SizedBox(height: 1200))],
            ),
          ),
        ),
        mediaQueryData: const MediaQueryData(disableAnimations: true),
      ),
    );

    final scrollView = find.byKey(const ValueKey('tp-root-scroll-view'));
    await tester.drag(scrollView, const Offset(0, -300));
    await tester.pump();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: scrollView, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.pixels, greaterThan(0));

    reselects.value++;
    await tester.pump();

    expect(scrollable.position.pixels, 0);
  });

  testWidgets('root header is one fixed capsule over full bleed content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _root(),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 44),
        ),
      ),
    );

    final header = find.byKey(const ValueKey('tp-root-glass-header'));
    expect(header, findsOneWidget);
    expect(tester.getRect(header).top, 52);
    expect(tester.getRect(header).left, 16);
    expect(tester.getSize(header).height, 64);
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(TpAccountAvatarButton), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('account-avatar-button'))),
      const Size(44, 44),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('full-bleed-body'))).dy,
      0,
    );
  });

  testWidgets('root header 是各自獨立的膠囊，不是一整片玻璃板', (tester) async {
    // iOS 26 的頂部只有按鈕群是玻璃，標題與背景之間沒有玻璃板
    // （WWDC25 明講玻璃不取樣玻璃）。標題自己包一顆膠囊，動作與頭像
    // 各包一顆，中間的空隙直接透出內容。依據見 ADR-0004。
    await tester.pumpWidget(_app(_root(actionCount: 2)));

    final header = find.byKey(const ValueKey('tp-root-glass-header'));
    final titleCapsule = find.byKey(const ValueKey('tp-root-header-title'));
    expect(find.descendant(of: header, matching: titleCapsule), findsOneWidget);
    // 標題自己坐在一顆玻璃膠囊裡。
    expect(
      find.ancestor(of: titleCapsule, matching: find.byType(TpGlassSurface)),
      findsOneWidget,
      reason: '標題要有自己的膠囊',
    );
    // **玻璃不疊玻璃**：頭像與動作本身就是玻璃圓鈕，不得再落在玻璃板裡。
    expect(
      find.ancestor(
        of: find.byType(TpAccountAvatarButton),
        matching: find.byType(TpGlassSurface),
      ),
      findsNothing,
      reason: '頭像不得包在玻璃板裡（玻璃不取樣玻璃）',
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('tp-root-header-action-0')),
        matching: find.byType(TpGlassSurface),
      ),
      findsNothing,
      reason: '動作不得包在玻璃板裡',
    );
    // 同一列的膠囊要等高。真機實測標題膠囊 63.7pt、三顆圓鈕都是 44pt ——
    // 拆膠囊時標題只給了內距、讓 `headlineSmall` 自己撐高度。
    final titleHeight = tester
        .getRect(find.byKey(const ValueKey('tp-glass-surface')))
        .height;
    for (final key in ['tp-root-header-action-0', 'account-avatar-button']) {
      expect(
        tester.getRect(find.byKey(ValueKey(key))).height,
        closeTo(titleHeight, 0.5),
        reason: '$key 與標題膠囊不等高',
      );
    }

    // 標題膠囊與頭像之間要留出空隙 —— 那是內容透出來的地方。
    final titleRight = tester.getRect(titleCapsule).right;
    final avatarLeft = tester.getRect(find.byType(TpAccountAvatarButton)).left;
    expect(avatarLeft, greaterThan(titleRight), reason: '膠囊之間要有空隙');
    expect(
      find.byKey(const ValueKey('tp-root-header-action-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tp-root-header-action-1')),
      findsOneWidget,
    );
    expect(find.byType(TpAccountAvatarButton), findsOneWidget);
    await tester.pumpWidget(_app(_root(actionCount: 3)));
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('root text action keeps the full label and intrinsic width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        TpRootScaffold(
          header: TpRootHeaderConfig(
            title: const Text('調整順序'),
            actions: [
              TpToolbarTextButton(label: '完成', onPressed: () {}),
              TpMoreMenuButton<int>(
                onSelected: (_) {},
                items: const [
                  TpActionItem(value: 1, icon: Icons.more_horiz, label: '更多'),
                ],
              ),
            ],
          ),
          body: const SizedBox.expand(),
        ),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2),
        ),
      ),
    );

    final action = find.byKey(const ValueKey('tp-root-header-action-0'));
    expect(
      find.descendant(of: action, matching: find.text('完成')),
      findsOneWidget,
    );
    expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(action).width, greaterThan(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scroll content starts clear then passes under fixed header', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        TpRootScaffold(
          header: const TpRootHeaderConfig(title: Text('我的行程')),
          body: TpRootScrollView(
            slivers: [
              SliverList.builder(
                itemCount: 30,
                itemBuilder: (context, index) => SizedBox(
                  height: 56,
                  child: Text(index == 0 ? '第一筆' : '第 ${index + 1} 筆'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final header = find.byKey(const ValueKey('tp-root-glass-header'));
    final headerBefore = tester.getRect(header);
    expect(
      tester.getRect(find.text('第一筆')).top,
      greaterThan(headerBefore.bottom),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
    await tester.pump();

    expect(tester.getRect(header), headerBefore);
    // 遮蔽帶不是 opt-in：沒有旗標的 root scaffold 也要有，六個畫面才一致。
    // 它做了什麼（糊掉、淡出、不吃觸控）由 tp_root_header_band_test 量像素驗。
    final band = tester.getRect(
      find.byKey(const ValueKey('tp-root-header-band')),
    );
    expect(band.top, 0);
    expect(band.bottom, greaterThan(headerBefore.bottom));
  });

  testWidgets('200 percent text keeps HIG action targets and spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _root(actionCount: 2),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2),
        ),
      ),
    );

    final header = tester.getRect(
      find.byKey(const ValueKey('tp-root-glass-header')),
    );
    final first = tester.getRect(
      find.byKey(const ValueKey('tp-root-header-action-0')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('tp-root-header-action-1')),
    );
    final account = tester.getRect(
      find.byKey(const ValueKey('account-avatar-button')),
    );
    expect(first.size, const Size(44, 44));
    expect(second.size, const Size(44, 44));
    expect(account.size, const Size(44, 44));
    expect(second.left - first.right, 8);
    expect(account.left - second.right, 8);
    // 拆成獨立膠囊後，右側動作直接貼齊 header 的內容邊界 —— 原本那 16pt
    // 是玻璃板自己的內距，板子沒了自然歸零。頁面邊距仍由 scaffold 的
    // `horizontalInset` 提供。
    expect(header.right - account.right, 0);
    expect(find.text('京都五日行'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
