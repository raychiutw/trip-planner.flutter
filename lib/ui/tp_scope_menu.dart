import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tp_glass_surface.dart';

class TpScopeOption<T> {
  const TpScopeOption({
    required this.value,
    required this.label,
    this.icon,
    this.indicatorColor,
    this.isAction = false,
    this.key,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? indicatorColor;
  final bool isAction;
  final Key? key;
}

class TpScopeMenu<T> extends StatelessWidget {
  const TpScopeMenu({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<TpScopeOption<T>> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: value,
      tooltip: '切換範圍',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<T>(
            key: option.key,
            value: option.value,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Icon(
                    option.value == value
                        ? CupertinoIcons.check_mark
                        : option.icon,
                    size: 18,
                  ),
                ),
                const SizedBox(width: TpSpacing.s2),
                Text(option.label),
              ],
            ),
          ),
      ],
      child: TpGlassSurface(
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TpSpacing.tapMin),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: TpSpacing.s2),
              const Icon(CupertinoIcons.chevron_down, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
