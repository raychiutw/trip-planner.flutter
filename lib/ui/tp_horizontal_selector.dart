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
    return SizedBox(
      height: TpSpacing.tapMin,
      child: TpGlassSurface(
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s1),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (index, option) in widget.options.indexed)
                KeyedSubtree(
                  key: _optionKeys[index],
                  child: Semantics(
                    key: option.key,
                    button: true,
                    selected: option.value == widget.value,
                    label: option.label,
                    excludeSemantics: true,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => widget.onSelected(option.value),
                        child: AnimatedContainer(
                          duration: TpMotion.resolve(context, TpMotion.fast),
                          constraints: const BoxConstraints(
                            minHeight: TpSpacing.tapMin,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: TpSpacing.s3,
                          ),
                          decoration: BoxDecoration(
                            color: option.value == widget.value
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: option.value == widget.value
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
                                  fontWeight: option.value == widget.value
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
