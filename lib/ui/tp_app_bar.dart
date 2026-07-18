import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/tokens.dart';
import 'tp_action_item.dart';

enum TpAppBarRole { standalone, detail, modalContent, modalForm }

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
      child: TextButton(onPressed: onPressed, child: Text(label, maxLines: 1)),
    );
  }
}

/// 所有 header 圓形功能共用同一組 Liquid Glass 材質。
///
/// 參數刻意與 root tab／DAY selector 同源：暖白或中性深色低透明 tint、
/// 亮邊與 44pt HIG 點擊範圍，避免各頁 header 看起來像不同套 UI。
LiquidGlassSettings tpToolbarGlassSettings(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return LiquidGlassSettings(
    glassColor: isDark ? const Color(0x70121214) : const Color(0x70FFFBF5),
    thickness: 16,
    blur: 16,
    chromaticAberration: 0,
    lightIntensity: isDark ? 0.56 : 0.62,
    ambientStrength: isDark ? 0.06 : 0.10,
    refractiveIndex: 1.06,
    saturation: 1.02,
    standardOpacityMultiplier: isDark ? 0.52 : 0.40,
    platformViewFallbackColor: isDark
        ? const Color(0x66121214)
        : const Color(0x5CFFFBF5),
  );
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
          settings: glassSettings ?? tpToolbarGlassSettings(context),
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

abstract final class TpToolbarSlots {
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
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(width: TpSpacing.s2),
              SizedBox.square(
                dimension: TpSpacing.tapMin,
                child: children[index],
              ),
            ],
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
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 88),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
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
          key: const ValueKey('tp-app-bar-primary-action'),
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
        ? 64.0
        : TpSpacing.tapMin;
    final actionsWidth = TpToolbarSlots.sideWidth(
      actionCount: resolvedActions.length,
      hasLeading: false,
    );
    if (largeSheetScope != null) {
      final colors = Theme.of(context).colorScheme;
      final showsScopeClose = role != TpAppBarRole.modalForm;
      final sheetActionWidths = <double>[
        for (var index = 0; index < actions.length; index++) TpSpacing.tapMin,
        if (primaryActionLabel != null) 64,
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
        title: DefaultTextStyle.merge(
          key: const ValueKey('tp-app-bar-title'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: title,
        ),
        actions: [
          SizedBox(
            width: sheetActionsWidth + TpSpacing.s4,
            child: Padding(
              padding: const EdgeInsets.only(right: TpSpacing.s4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (
                    var index = 0;
                    index < resolvedActions.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(width: TpSpacing.s2),
                    resolvedActions[index],
                  ],
                  if (showsScopeClose) ...[
                    if (resolvedActions.isNotEmpty)
                      const SizedBox(width: TpSpacing.s2),
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
      title: DefaultTextStyle.merge(
        key: const ValueKey('tp-app-bar-title'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: title,
      ),
      actions: primaryActionLabel == null
          ? TpToolbarSlots.actions(
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
          onPressed: () => Navigator.of(context).maybePop(),
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
        settings: tpToolbarGlassSettings(context),
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
  final _menuController = GlassMenuController();
  _PendingMenuSelection<T>? _pendingSelection;

  void _queueSelection(T value) {
    _pendingSelection = _PendingMenuSelection(value);
  }

  void _dispatchSelectionAfterClose() {
    final pending = _pendingSelection;
    if (pending == null) return;
    _pendingSelection = null;
    _dispatchWhenMenuClosed(pending.value);
  }

  void _dispatchWhenMenuClosed(T value) {
    // GlassMenu invokes the item callback before beginning its close morph.
    // Opening a route at that moment disables the underlying route's ticker,
    // leaving the full-screen dismiss barrier alive and making the page appear
    // stuck. Wait until the overlay has actually left before opening a sheet.
    if (!mounted) return;
    if (!_menuController.isOpen) {
      widget.onSelected(value);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _dispatchWhenMenuClosed(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final triggerForeground = scheme.primary;
    final menuForeground = isDark ? scheme.primary : scheme.onPrimaryContainer;
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
    return SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: GlassMenu(
        controller: _menuController,
        onClose: _dispatchSelectionAfterClose,
        menuWidth: 248,
        menuBorderRadius: 24,
        itemBorderRadius: 16,
        menuAlignment: GlassMenuAlignment.topRight,
        autoAdjustToScreen: true,
        menuPadding: const EdgeInsets.all(TpSpacing.s3),
        settings: settings,
        quality: GlassQuality.standard,
        selectionColor: triggerForeground.withValues(alpha: 0.18),
        triggerBuilder: (menuContext, toggleMenu) => TpToolbarGlassButton(
          tooltip: widget.tooltip,
          onPressed: widget.enabled ? toggleMenu : null,
          glassSettings: settings,
          rimColor: triggerForeground.withValues(alpha: isDark ? 0.56 : 0.46),
          child:
              widget.triggerChild ??
              Icon(CupertinoIcons.ellipsis, size: 22, color: triggerForeground),
        ),
        items: [
          for (final item in widget.items) ...[
            if (item.dividerBefore)
              GlassMenuDivider(
                indent: 12,
                color: menuForeground.withValues(alpha: 0.18),
              ),
            GlassMenuItem(
              key: item.key,
              title: item.label,
              icon: Icon(item.icon),
              iconColor: item.role == TpActionRole.destructive
                  ? null
                  : menuForeground,
              titleStyle: item.role == TpActionRole.destructive
                  ? null
                  : theme.textTheme.bodyLarge?.copyWith(color: menuForeground),
              isDestructive: item.role == TpActionRole.destructive,
              enabled: item.enabled,
              height: TpSpacing.tapMin,
              onTap: () => _queueSelection(item.value),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingMenuSelection<T> {
  const _PendingMenuSelection(this.value);

  final T value;
}
