import 'package:flutter/material.dart';

/// 根分頁捲動骨架：inline 頁首（標題 + 最多兩個功能鍵）＋ 浮動 tab bar 底部淨空。
///
/// 根頁的頁首規格與底部 inset 只從這裡出。spec 明訂「禁止畫面自行硬編底部 inset」，
/// 但三個根頁各自硬編（16／112／112）—— 其中兩處直接破版。
///
/// 頁首恆為 inline、不放大：大標題在手機上吃掉可觀的垂直空間，且只有部分頁面有
/// 大標題會讓 app 讀起來像兩套設計。
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

  /// 頁首右側功能鍵；icon-only 者須自帶 tooltip 或 semantics label。
  final List<Widget> actions;

  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    assert(actions.length <= 2, 'Root toolbar supports at most two actions.');
    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: actions,
        ),
        ...slivers,
        // 底部淨空：AppShell 開 extendBody，Flutter 已把浮動 tab bar 的實測高度灌進
        // MediaQuery.padding.bottom（scaffold.dart _BodyBuilder），讀它即可 —— 硬編
        // 常數在任何裝置都不會剛好對（實際是 safe area + 8 + 64）。
        SliverToBoxAdapter(
          child: SizedBox(
            key: const ValueKey('root-scroll-bottom-inset'),
            width: double.infinity,
            height: MediaQuery.paddingOf(context).bottom,
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
