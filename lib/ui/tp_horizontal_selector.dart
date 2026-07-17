import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tp_glass_surface.dart';
import 'tp_scope_menu.dart';

class TpHorizontalSelector<T> extends StatefulWidget {
  const TpHorizontalSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final T value;
  final List<TpScopeOption<T>> options;
  final ValueChanged<T> onSelected;

  @override
  State<TpHorizontalSelector<T>> createState() =>
      _TpHorizontalSelectorState<T>();
}

class _TpHorizontalSelectorState<T> extends State<TpHorizontalSelector<T>> {
  late List<GlobalKey> _optionKeys;

  @override
  void initState() {
    super.initState();
    _optionKeys = _keysFor(widget.options.length);
    _scheduleSelectedVisibility();
  }

  @override
  void didUpdateWidget(covariant TpHorizontalSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      _optionKeys = _keysFor(widget.options.length);
    }
    if (oldWidget.value != widget.value ||
        oldWidget.options.length != widget.options.length) {
      _scheduleSelectedVisibility();
    }
  }

  List<GlobalKey> _keysFor(int length) =>
      List<GlobalKey>.generate(length, (_) => GlobalKey());

  void _scheduleSelectedVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = widget.options.indexWhere(
        (option) => option.value == widget.value,
      );
      if (index < 0) return;
      final optionContext = _optionKeys[index].currentContext;
      if (optionContext == null) return;
      final renderObject = optionContext.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        return;
      }
      Scrollable.ensureVisible(
        optionContext,
        alignment: 0.5,
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
    return SizedBox(
      height: TpSpacing.tapMin,
      child: TpGlassSurface(
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        padding: const EdgeInsets.all(TpSpacing.s1),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (index, option) in widget.options.indexed) ...[
                _SelectorOption<T>(
                  key: _optionKeys[index],
                  option: option,
                  selected: !option.isAction && option.value == widget.value,
                  isDark: isDark,
                  onTap: () => widget.onSelected(option.value),
                ),
                if (option.isAction && index < widget.options.length - 1)
                  Container(
                    key: ValueKey('tp-selector-divider-$index'),
                    width: 1,
                    height: 18,
                    margin: const EdgeInsets.symmetric(
                      horizontal: TpSpacing.s1,
                    ),
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.72,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorOption<T> extends StatelessWidget {
  const _SelectorOption({
    super.key,
    required this.option,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final TpScopeOption<T> option;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Semantics(
      key: option.key,
      button: true,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: TpMotion.resolve(context, TpMotion.fast),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s3),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: isDark ? 0.30 : 0.20)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              border: selected
                  ? Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.34 : 0.86,
                      ),
                    )
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  Icon(
                    option.icon,
                    size: 14,
                    color: option.isAction || selected
                        ? accent
                        : theme.colorScheme.onSurfaceVariant,
                  ),
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
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: option.isAction || selected
                        ? accent
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected || option.isAction
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
