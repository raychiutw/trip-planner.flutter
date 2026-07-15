import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class TpAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TpAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.automaticallyImplyLeading = true,
  });

  final Widget title;
  final List<Widget> actions;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    assert(actions.length <= 2, 'Toolbar supports at most two actions.');
    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: true,
      title: DefaultTextStyle.merge(
        key: const ValueKey('tp-app-bar-title'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: title,
      ),
      actions: actions,
    );
  }
}

class TpMoreMenuButton<T> extends StatelessWidget {
  const TpMoreMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.enabled = true,
    this.tooltip = '更多',
  });

  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;
  final bool enabled;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: PopupMenuButton<T>(
        enabled: enabled,
        tooltip: tooltip,
        icon: const Icon(CupertinoIcons.ellipsis),
        onSelected: onSelected,
        itemBuilder: (_) => items,
      ),
    );
  }
}
