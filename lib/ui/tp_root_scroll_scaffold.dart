import 'package:flutter/material.dart';

import '../theme/tokens.dart';

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
    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar.large(
          pinned: true,
          automaticallyImplyLeading: false,
          toolbarHeight: 56,
          collapsedHeight: 56,
          expandedHeight: 108,
          centerTitle: true,
          title: Text(title),
          actions: actions,
        ),
        ...slivers,
        SliverToBoxAdapter(
          child: SizedBox(
            key: ValueKey('root-scroll-bottom-inset'),
            height: TpRootTabGeometry.expandedHeight(context) + TpSpacing.s4,
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
