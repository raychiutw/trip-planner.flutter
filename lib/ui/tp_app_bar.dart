import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

abstract final class TpToolbarSlots {
  static double sideWidth({
    required int actionCount,
    required bool hasLeading,
  }) {
    final slotCount = actionCount > (hasLeading ? 1 : 0)
        ? actionCount
        : (hasLeading ? 1 : 0);
    return slotCount * TpSpacing.tapMin;
  }

  static Widget? leading({required double width, Widget? action}) {
    if (width == 0) return null;
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: action == null
            ? null
            : SizedBox.square(dimension: TpSpacing.tapMin, child: action),
      ),
    );
  }

  static List<Widget> actions({
    required double width,
    required List<Widget> children,
  }) {
    if (width == 0) return const [];
    return [
      SizedBox(
        width: width,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (final child in children)
              SizedBox.square(dimension: TpSpacing.tapMin, child: child),
          ],
        ),
      ),
    ];
  }
}

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
    final route = ModalRoute.of(context);
    final scaffold = Scaffold.maybeOf(context);
    final Widget? leadingAction;
    if (!automaticallyImplyLeading) {
      leadingAction = null;
    } else if (scaffold?.hasDrawer ?? false) {
      leadingAction = const DrawerButton();
    } else if (route?.impliesAppBarDismissal ?? false) {
      leadingAction = route is PageRoute<dynamic> && route.fullscreenDialog
          ? const CloseButton()
          : const BackButton();
    } else {
      leadingAction = null;
    }
    final sideWidth = TpToolbarSlots.sideWidth(
      actionCount: actions.length,
      hasLeading: leadingAction != null,
    );
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: sideWidth == 0 ? null : sideWidth,
      leading: TpToolbarSlots.leading(width: sideWidth, action: leadingAction),
      centerTitle: true,
      title: DefaultTextStyle.merge(
        key: const ValueKey('tp-app-bar-title'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: title,
      ),
      actions: TpToolbarSlots.actions(width: sideWidth, children: actions),
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
