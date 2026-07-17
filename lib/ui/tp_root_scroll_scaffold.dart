import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tp_app_bar.dart';

/// Root 頁共用捲動骨架：inline 頁首 + 最多兩個 action + 浮動 tab bar 底部淨空。
///
/// 刻意不用 large title —— 它吃掉 96-108pt，內容卻只是重複 tab bar 已經講過的
/// 頁名。省下的高度換成內容（同一螢幕多看到一張卡）。頁名靠 inline title 與
/// 選中的 tab 共同表達。
class TpRootScrollScaffold extends StatelessWidget {
  const TpRootScrollScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
    this.onRefresh,
  });

  final String title;
  final List<Widget> slivers;
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    assert(actions.length <= 2, 'Root toolbar supports at most two actions.');
    final sideWidth = TpToolbarSlots.sideWidth(
      actionCount: actions.length,
      hasLeading: false,
    );
    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          toolbarHeight: 56,
          collapsedHeight: 56,
          expandedHeight: 56,
          centerTitle: true,
          leadingWidth: sideWidth == 0 ? null : sideWidth,
          leading: TpToolbarSlots.leading(width: sideWidth),
          title: Text(title),
          actions: TpToolbarSlots.actions(width: sideWidth, children: actions),
        ),
        ...slivers,
        SliverToBoxAdapter(
          child: SizedBox(
            key: ValueKey('root-scroll-bottom-inset'),
            height: TpRootTabGeometry.clearance(context) + TpSpacing.s4,
          ),
        ),
      ],
    );

    return Scaffold(
      body: onRefresh == null
          ? scrollView
          : RefreshIndicator.adaptive(onRefresh: onRefresh!, child: scrollView),
    );
  }
}
