import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 互斥的少量選項(2~4 項),取代 Material 的 `SegmentedButton`。
///
/// 底層是 [CupertinoSlidingSegmentedControl];[options] 的迭代順序即顯示順序。
/// [onChanged] 為 null 時停用(不回呼,視覺以降低不透明度表示)。
class TpSegmentedControl<T extends Object> extends StatelessWidget {
  const TpSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.segmentKeys = const {},
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T>? onChanged;

  /// 測試與語意用:為個別 segment 的文字指定 key。
  final Map<T, Key> segmentKeys;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: CupertinoSlidingSegmentedControl<T>(
          groupValue: value,
          backgroundColor: scheme.surfaceContainerHigh,
          thumbColor: scheme.surface,
          children: {
            for (final entry in options.entries)
              entry.key: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  entry.value,
                  key: segmentKeys[entry.key],
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: scheme.onSurface),
                ),
              ),
          },
          onValueChanged: (next) {
            if (next != null) onChanged?.call(next);
          },
        ),
      ),
    );
  }
}
