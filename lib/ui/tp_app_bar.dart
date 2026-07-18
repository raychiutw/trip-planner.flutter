import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/tokens.dart';
import 'tp_action_item.dart';
import 'tp_glass_surface.dart';

enum TpAppBarRole { standalone, detail, modalContent, modalForm }

/// The single typography owner for titles rendered inside compact headers.
class TpHeaderTitle extends StatelessWidget {
  const TpHeaderTitle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: Theme.of(context).textTheme.headlineSmall,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    child: child,
  );
}

/// The single spacing owner for one or more compact header actions.
class TpHeaderActionRow extends StatelessWidget {
  const TpHeaderActionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.end,
    spacing: TpSpacing.s2,
    children: children,
  );
}

class TpToolbarTextButton extends StatelessWidget {
  const TpToolbarTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TpSpacing.tapMin,
        minHeight: TpSpacing.tapMin,
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(TpSpacing.tapMin, TpSpacing.tapMin),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        onPressed: onPressed,
        child: Text(label, maxLines: 1),
      ),
    );
  }
}

/// Header 共用的 44pt 圓形套件 Liquid Glass 按鈕。
class TpToolbarGlassButton extends StatelessWidget {
  const TpToolbarGlassButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.platformViewBackdrop = false,
    this.glassSettings,
    this.rimColor,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool platformViewBackdrop;
  final LiquidGlassSettings? glassSettings;
  final Color? rimColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: GlassButton.custom(
          key: const ValueKey('tp-toolbar-glass-button'),
          label: tooltip,
          width: TpSpacing.tapMin,
          height: TpSpacing.tapMin,
          enabled: onPressed != null,
          onTap: onPressed ?? () {},
          useOwnLayer: true,
          quality: GlassQuality.standard,
          platformViewBackdrop: platformViewBackdrop,
          interactionScale: 1.03,
          stretch: 0.12,
          shape: LiquidRoundedSuperellipse(
            borderRadius: 22,
            side: BorderSide(
              color:
                  rimColor ??
                  Colors.white.withValues(alpha: isDark ? 0.30 : 0.72),
            ),
          ),
          settings: glassSettings ?? tpNavigationGlassSettings(context),
          child: child,
        ),
      ),
    );
  }
}

/// Marks routes that are pushed inside the near-full-height sheet navigator.
class TpLargeSheetNavigationScope extends InheritedWidget {
  const TpLargeSheetNavigationScope({
    super.key,
    required this.onClose,
    required super.child,
  });

  final VoidCallback onClose;

  static TpLargeSheetNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TpLargeSheetNavigationScope>();

  @override
  bool updateShouldNotify(TpLargeSheetNavigationScope oldWidget) => false;
}

/// Pops the current nested route, or closes its owning near-full-height sheet
/// when the nested navigator is already at its root page.
Future<void> closeAppRouteOrSheet(BuildContext context) async {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    await navigator.maybePop();
    return;
  }
  TpLargeSheetNavigationScope.maybeOf(context)?.onClose();
}

abstract final class TpToolbarSlots {
  static double textActionWidth(
    BuildContext context,
    TpToolbarTextButton action,
  ) {
    final textStyle = Theme.of(context).textTheme.labelLarge;
    final painter = TextPainter(
      text: TextSpan(text: action.label, style: textStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final intrinsicWidth = painter.width + 20;
    return intrinsicWidth < TpSpacing.tapMin
        ? TpSpacing.tapMin
        : intrinsicWidth;
  }

  static double sideWidth({
    required int actionCount,
    required bool hasLeading,
  }) {
    final slotCount = actionCount > (hasLeading ? 1 : 0)
        ? actionCount
        : (hasLeading ? 1 : 0);
    if (slotCount == 0) return 0;
    return slotCount * TpSpacing.tapMin + (slotCount - 1) * TpSpacing.s2;
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

  static double actionsWidth(BuildContext context, List<Widget> children) {
    if (children.isEmpty) return 0;
    return children.fold<double>(
          0,
          (width, child) =>
              width +
              (child is TpToolbarTextButton
                  ? textActionWidth(context, child)
                  : TpSpacing.tapMin),
        ) +
        (children.length - 1) * TpSpacing.s2;
  }

  static List<Widget> actions({
    required BuildContext context,
    required double width,
    required List<Widget> children,
  }) {
    if (width == 0) return const [];
    return [
      SizedBox(
        width: width,
        child: TpHeaderActionRow(
          children: [
            for (final child in children)
              if (child is TpToolbarTextButton)
                SizedBox(width: textActionWidth(context, child), child: child)
              else
                SizedBox.square(dimension: TpSpacing.tapMin, child: child),
          ],
        ),
      ),
    ];
  }
}

class TpSheetHeader extends StatelessWidget {
  const TpSheetHeader({
    super.key,
    required this.title,
    this.titleKey,
    this.leading,
    this.trailing,
  });

  final String title;
  final Key? titleKey;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 88),
            child: TpHeaderTitle(key: titleKey, child: Text(title)),
          ),
          if (leading != null) Positioned(left: TpSpacing.s4, child: leading!),
          if (trailing != null)
            Positioned(right: TpSpacing.s4, child: trailing!),
        ],
      ),
    );
  }
}

class TpAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TpAppBar({
    super.key,
    required this.title,
    required this.role,
    this.actions = const [],
    this.onCancel,
    this.primaryActionLabel,
    this.primaryActionKey,
    this.onPrimaryAction,
    this.primaryActionEnabled = true,
  }) : assert(
         role != TpAppBarRole.modalForm ||
             (onCancel != null &&
                 primaryActionLabel != null &&
                 onPrimaryAction != null),
         'modalForm requires Cancel and a primary action.',
       ),
       assert(
         (primaryActionLabel == null) == (onPrimaryAction == null),
         'primaryActionLabel and onPrimaryAction must be supplied together.',
       );

  final Widget title;
  final TpAppBarRole role;
  final List<Widget> actions;
  final VoidCallback? onCancel;
  final String? primaryActionLabel;
  final Key? primaryActionKey;
  final VoidCallback? onPrimaryAction;
  final bool primaryActionEnabled;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final largeSheetScope = TpLargeSheetNavigationScope.maybeOf(context);
    final leadingAction = _semanticLeading(context, largeSheetScope);
    final resolvedActions = <Widget>[
      ...actions,
      if (primaryActionLabel != null)
        TpToolbarTextButton(
          key: primaryActionKey ?? const ValueKey('tp-app-bar-primary-action'),
          label: primaryActionLabel!,
          onPressed: primaryActionEnabled ? onPrimaryAction : null,
        ),
    ];
    assert(
      resolvedActions.length <= 2,
      'Toolbar supports at most two actions.',
    );
    final leadingWidth = leadingAction == null
        ? 0.0
        : role == TpAppBarRole.modalForm
        ? TpToolbarSlots.textActionWidth(
            context,
            leadingAction as TpToolbarTextButton,
          )
        : TpSpacing.tapMin;
    final actionsWidth = TpToolbarSlots.actionsWidth(context, resolvedActions);
    if (largeSheetScope != null) {
      final colors = Theme.of(context).colorScheme;
      final showsScopeClose = role != TpAppBarRole.modalForm;
      final sheetActionWidths = <double>[
        for (final action in actions)
          action is TpToolbarTextButton
              ? TpToolbarSlots.textActionWidth(context, action)
              : TpSpacing.tapMin,
        if (primaryActionLabel != null)
          TpToolbarSlots.textActionWidth(
            context,
            resolvedActions.last as TpToolbarTextButton,
          ),
        if (showsScopeClose) TpSpacing.tapMin,
      ];
      final sheetActionsWidth = sheetActionWidths.isEmpty
          ? 0.0
          : sheetActionWidths.reduce((sum, width) => sum + width) +
                (sheetActionWidths.length - 1) * TpSpacing.s2;
      return GlassAppBar(
        preferredSize: preferredSize,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: SizedBox(
          width: sheetActionsWidth + TpSpacing.s4,
          child: Padding(
            padding: const EdgeInsets.only(left: TpSpacing.s4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: leadingAction == null
                  ? null
                  : SizedBox(
                      key: const ValueKey('app-large-sheet-back'),
                      width: leadingWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconTheme(
                          data: IconThemeData(color: colors.primary),
                          child: leadingAction,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        title: TpHeaderTitle(
          key: const ValueKey('tp-app-bar-title'),
          child: title,
        ),
        actions: [
          SizedBox(
            width: sheetActionsWidth + TpSpacing.s4,
            child: Padding(
              padding: const EdgeInsets.only(right: TpSpacing.s4),
              child: TpHeaderActionRow(
                children: [
                  ...resolvedActions,
                  if (showsScopeClose)
                    KeyedSubtree(
                      key: const ValueKey('app-sheet-close'),
                      child: TpToolbarGlassButton(
                        key: const ValueKey('app-large-sheet-close'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: largeSheetScope.onClose,
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 19,
                          color: colors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return GlassAppBar(
      preferredSize: preferredSize,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      centerTitle: false,
      leading: TpToolbarSlots.leading(
        width: leadingWidth,
        action: leadingAction,
      ),
      title: TpHeaderTitle(
        key: const ValueKey('tp-app-bar-title'),
        child: title,
      ),
      actions: primaryActionLabel == null
          ? TpToolbarSlots.actions(
              context: context,
              width: actionsWidth,
              children: resolvedActions,
            )
          : resolvedActions,
    );
  }

  Widget? _semanticLeading(
    BuildContext context,
    TpLargeSheetNavigationScope? largeSheetScope,
  ) {
    switch (role) {
      case TpAppBarRole.standalone:
        return null;
      case TpAppBarRole.detail:
        return TpToolbarGlassButton(
          key: const ValueKey('tp-app-bar-back'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => closeAppRouteOrSheet(context),
          child: const Icon(CupertinoIcons.back, size: 22),
        );
      case TpAppBarRole.modalContent:
        if (largeSheetScope != null) return null;
        return TpToolbarGlassButton(
          key: const ValueKey('tp-app-bar-close'),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Icon(CupertinoIcons.xmark, size: 19),
        );
      case TpAppBarRole.modalForm:
        return TpToolbarTextButton(
          key: const ValueKey('tp-app-bar-cancel'),
          label: '取消',
          onPressed: onCancel,
        );
    }
  }
}

/// 需要由父元件（例如 PopupMenuButton）處理點擊時使用的共用 44pt glass 表面。
class TpToolbarActionSurface extends StatelessWidget {
  const TpToolbarActionSurface({super.key, this.icon, this.child})
    : assert(icon != null || child != null),
      assert(icon == null || child == null);

  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: GlassContainer(
        key: const ValueKey('tp-toolbar-action-surface'),
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: LiquidRoundedSuperellipse(
          borderRadius: 22,
          side: BorderSide(
            color: Colors.white.withValues(alpha: isDark ? 0.30 : 0.72),
          ),
        ),
        settings: tpNavigationGlassSettings(context),
        child:
            child ?? Icon(icon, size: 20, color: theme.colorScheme.onSurface),
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
    return TpToolbarGlassButton(
      tooltip: tooltip,
      onPressed: onPressed,
      child: Icon(icon, size: 20),
    );
  }
}

class TpMoreMenuButton<T> extends StatefulWidget {
  const TpMoreMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.enabled = true,
    this.tooltip = '更多',
    this.triggerChild,
  });

  final List<TpActionItem<T>> items;
  final ValueChanged<T> onSelected;
  final bool enabled;
  final String tooltip;
  final Widget? triggerChild;

  @override
  State<TpMoreMenuButton<T>> createState() => _TpMoreMenuButtonState<T>();
}

class _TpMoreMenuButtonState<T> extends State<TpMoreMenuButton<T>> {
  final _menuController = MenuController();

  void _select(T value) {
    _menuController.close();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSelected(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final triggerForeground = scheme.primary;
    final menuForeground = isDark ? scheme.primary : scheme.onSurface;
    final settings = LiquidGlassSettings(
      glassColor: scheme.primaryContainer.withValues(
        alpha: isDark ? 0.62 : 0.68,
      ),
      thickness: 22,
      blur: 22,
      chromaticAberration: 0,
      lightIntensity: isDark ? 0.62 : 0.72,
      ambientStrength: isDark ? 0.08 : 0.14,
      refractiveIndex: 1.08,
      saturation: 1.02,
      standardOpacityMultiplier: isDark ? 0.64 : 0.52,
      platformViewFallbackColor: scheme.primaryContainer.withValues(
        alpha: isDark ? 0.84 : 0.90,
      ),
    );
    final menuStyle = MenuStyle(
      alignment: AlignmentDirectional.topEnd,
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      minimumSize: const WidgetStatePropertyAll(Size(248, 0)),
      maximumSize: const WidgetStatePropertyAll(Size(248, double.infinity)),
    );
    return SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: MenuAnchor(
        controller: _menuController,
        useRootOverlay: true,
        consumeOutsideTap: true,
        style: menuStyle,
        alignmentOffset: const Offset(0, 8),
        builder: (menuContext, controller, _) => TpToolbarGlassButton(
          tooltip: widget.tooltip,
          onPressed: widget.enabled
              ? () => controller.isOpen ? controller.close() : controller.open()
              : null,
          glassSettings: settings,
          rimColor: triggerForeground.withValues(alpha: isDark ? 0.56 : 0.46),
          child:
              widget.triggerChild ??
              Icon(CupertinoIcons.ellipsis, size: 22, color: triggerForeground),
        ),
        menuChildren: [
          SizedBox(
            width: 248,
            child: TpGlassSurface(
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              padding: const EdgeInsets.all(TpSpacing.s3),
              glassSettings: settings,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in widget.items) ...[
                    if (item.dividerBefore)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Divider(
                          height: TpSpacing.s4,
                          color: menuForeground.withValues(alpha: 0.18),
                        ),
                      ),
                    MenuItemButton(
                      key: item.key,
                      leadingIcon: Icon(
                        item.selected ? CupertinoIcons.check_mark : item.icon,
                        size: 22,
                      ),
                      closeOnActivate: false,
                      style: ButtonStyle(
                        alignment: AlignmentDirectional.centerStart,
                        minimumSize: const WidgetStatePropertyAll(
                          Size(0, TpSpacing.tapMin),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 12),
                        ),
                        foregroundColor: WidgetStatePropertyAll(
                          item.role == TpActionRole.destructive
                              ? scheme.error
                              : menuForeground,
                        ),
                        backgroundColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        overlayColor: WidgetStatePropertyAll(
                          triggerForeground.withValues(alpha: 0.18),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        textStyle: WidgetStatePropertyAll(
                          theme.textTheme.bodyLarge,
                        ),
                      ),
                      onPressed: item.enabled
                          ? () => _select(item.value)
                          : null,
                      child: Text(item.label),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
