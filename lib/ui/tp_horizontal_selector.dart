import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'tp_glass_surface.dart';
import 'tp_scope_menu.dart';

/// 行程／地圖頁共用的一階切換器。
///
/// 跨頁動作、分隔線和 DAY 選擇都位於同一個 Liquid Glass 膠囊內；只有
/// selected DAY 使用第二個小型 glass thumb。這和定版 mockup 的「攤平一階」
/// 結構一致，也避免兩個相鄰膠囊在地圖上形成不連續的白色區塊。
class TpHorizontalSelector<T> extends StatefulWidget {
  const TpHorizontalSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
    this.platformViewBackdrop = false,
  });

  final T value;
  final List<TpScopeOption<T>> options;
  final ValueChanged<T> onSelected;
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
        if (option.isAction) continue;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tones = theme.extension<TpTones>()!;
    final trackSettings = tpNavigationGlassSettings(context);
    final selectedColor = isDark
        ? TpColorsDark.navigationSelection
        : TpColorsLight.navigationSelection;
    final selectedSettings = trackSettings.copyWith(
      glassColor: selectedColor,
      platformViewFallbackColor: selectedColor,
    );
    final actionOptions = widget.options
        .where((option) => option.isAction)
        .toList(growable: false);
    final tabOptions = widget.options
        .where((option) => !option.isAction)
        .toList(growable: false);

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
            for (final option in actionOptions)
              _SelectorOption<T>(
                option: option,
                selected: false,
                width: _optionWidth(option),
                selectedSettings: selectedSettings,
                accentColor: tones.accentDeep,
                onTap: () => widget.onSelected(option.value),
              ),
            if (actionOptions.isNotEmpty && tabOptions.isNotEmpty)
              Container(
                key: const ValueKey('tp-selector-divider-0'),
                width: 1,
                height: 18,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final option in tabOptions)
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

  double _actionWidth(TpScopeOption<T> option) {
    final iconWidth = option.icon == null ? 0 : 20;
    return 24 + iconWidth + option.label.characters.length * 13;
  }

  double _optionWidth(TpScopeOption<T> option) {
    final textScale = (MediaQuery.textScalerOf(context).scale(13) / 13).clamp(
      1.0,
      2.0,
    );
    final baseWidth = option.isAction
        ? _actionWidth(option)
        : (_tabWidth + (option.label.characters.length - 5).clamp(0, 4) * 10)
              .toDouble();
    return baseWidth * textScale;
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
    final color = selected || option.isAction
        ? accentColor
        : theme.colorScheme.onSurfaceVariant;
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
