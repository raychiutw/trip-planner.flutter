import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'tp_glass_surface.dart';
import 'tp_scope_menu.dart';

class TpHorizontalSelectorAction {
  const TpHorizontalSelectorAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.key,
  });

  final Key? key;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

/// 行程／地圖頁共用的 Day 選擇器。
class TpHorizontalSelector<T> extends StatefulWidget {
  const TpHorizontalSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
    this.leadingAction,
    this.platformViewBackdrop = false,
  });

  final T value;
  final List<TpScopeOption<T>> options;
  final ValueChanged<T> onSelected;
  final TpHorizontalSelectorAction? leadingAction;
  final bool platformViewBackdrop;

  @override
  State<TpHorizontalSelector<T>> createState() =>
      _TpHorizontalSelectorState<T>();
}

class _TpHorizontalSelectorState<T> extends State<TpHorizontalSelector<T>> {
  // 13pt HIG label + Dynamic Type breathing room (DAY 01 still fits).
  static const _tabWidth = 76.0;
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleSelectedVisibility();
  }

  @override
  void didUpdateWidget(covariant TpHorizontalSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.options.length != widget.options.length) {
      _scheduleSelectedVisibility();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSelectedVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position;
      if (!position.hasViewportDimension || !position.hasContentDimensions) {
        return;
      }
      var center = 0.0;
      var found = false;
      for (final option in widget.options) {
        final width = _optionWidth(option);
        if (option.value == widget.value) {
          center += width / 2;
          found = true;
          break;
        }
        center += width;
      }
      if (!found) return;
      final target = (center - position.viewportDimension / 2).clamp(
        0.0,
        position.maxScrollExtent,
      );
      _controller.animateTo(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : TpMotion.normal,
        curve: TpMotion.appleEase,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.options.every((option) => !option.isAction),
      'TpHorizontalSelector only accepts selection options.',
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tones = theme.extension<TpTones>()!;
    final trackSettings = tpNavigationGlassSettings(
      context,
      visualContent: widget.platformViewBackdrop,
    );
    final selectedColor = isDark
        ? TpColorsDark.navigationSelection
        : TpColorsLight.navigationSelection;
    final selectedSettings = trackSettings.copyWith(
      glassColor: selectedColor,
      platformViewFallbackColor: selectedColor,
    );
    return SizedBox(
      height: TpSpacing.tapMin,
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        platformViewBackdrop: widget.platformViewBackdrop,
        clipBehavior: Clip.antiAlias,
        shape: LiquidRoundedSuperellipse(
          borderRadius: 22,
          side: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
          ),
        ),
        settings: trackSettings,
        child: Row(
          children: [
            if (widget.leadingAction case final action?)
              _SelectorAction(action: action, color: tones.accentDeep),
            Expanded(
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final option in widget.options)
                      _SelectorOption<T>(
                        option: option,
                        selected: option.value == widget.value,
                        width: _optionWidth(option),
                        selectedSettings: selectedSettings,
                        accentColor: tones.accentDeep,
                        onTap: () => widget.onSelected(option.value),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _optionWidth(TpScopeOption<T> option) {
    final textScale = (MediaQuery.textScalerOf(context).scale(13) / 13).clamp(
      1.0,
      2.0,
    );
    final baseWidth =
        (_tabWidth + (option.label.characters.length - 5).clamp(0, 4) * 10)
            .toDouble();
    return baseWidth * textScale;
  }
}

class _SelectorAction extends StatelessWidget {
  const _SelectorAction({required this.action, required this.color});

  final TpHorizontalSelectorAction action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textScale = (MediaQuery.textScalerOf(context).scale(13) / 13).clamp(
      1.0,
      2.0,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          key: action.key,
          button: true,
          label: action.label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: action.onPressed,
            child: SizedBox(
              width: 88 * textScale,
              height: TpSpacing.tapMin,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.icon, size: 14, color: color),
                  const SizedBox(width: TpSpacing.s1),
                  Text(
                    action.label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 1,
          height: 24,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.16),
        ),
      ],
    );
  }
}

class _SelectorOption<T> extends StatelessWidget {
  const _SelectorOption({
    required this.option,
    required this.selected,
    required this.width,
    required this.selectedSettings,
    required this.accentColor,
    required this.onTap,
  });

  final TpScopeOption<T> option;
  final bool selected;
  final double width;
  final LiquidGlassSettings selectedSettings;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? accentColor : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      key: option.key,
      button: true,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: TpSpacing.tapMin,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            child: selected
                ? IgnorePointer(
                    child: GlassButton.custom(
                      label: option.label,
                      width: width - 6,
                      height: 34,
                      shape: const LiquidRoundedSuperellipse(borderRadius: 17),
                      settings: selectedSettings,
                      quality: GlassQuality.standard,
                      interactionScale: 1,
                      stretch: 0,
                      onTap: onTap,
                      child: _OptionContent(option: option, color: color),
                    ),
                  )
                : Center(
                    child: _OptionContent(option: option, color: color),
                  ),
          ),
        ),
      ),
    );
  }
}

class _OptionContent<T> extends StatelessWidget {
  const _OptionContent({required this.option, required this.color});

  final TpScopeOption<T> option;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (option.icon != null) ...[
          Icon(option.icon, size: 14, color: color),
          const SizedBox(width: TpSpacing.s1),
        ],
        if (option.indicatorColor != null) ...[
          Container(
            width: TpSpacing.s2,
            height: TpSpacing.s2,
            decoration: BoxDecoration(
              color: option.indicatorColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: TpSpacing.s2),
        ],
        Text(
          option.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
