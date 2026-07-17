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

/// HIG toolbar 的 36pt 可見圓形材質；外層維持 44pt 點擊區。
class TpToolbarActionSurface extends StatelessWidget {
  const TpToolbarActionSurface({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        key: const ValueKey('tp-toolbar-action-surface'),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh.withValues(alpha: 0.78),
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: 36,
          child: Icon(icon, size: 20, color: colors.onSurface),
        ),
      ),
    );
  }
}

class TpToolbarIconButton extends StatelessWidget {
  const TpToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: TpToolbarActionSurface(icon: icon),
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
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: PopupMenuButton<T>(
        enabled: enabled,
        tooltip: tooltip,
        constraints: const BoxConstraints.tightFor(width: 248),
        menuPadding: const EdgeInsets.symmetric(vertical: 5),
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: Colors.white.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.22 : 0.92,
            ),
          ),
        ),
        onSelected: onSelected,
        itemBuilder: (_) => items,
        child: const TpToolbarActionSurface(icon: CupertinoIcons.ellipsis),
      ),
    );
  }
}
