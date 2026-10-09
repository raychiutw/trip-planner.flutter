import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tp_tap_target.dart';

const _thumbDuration = Duration(milliseconds: 200);
const _trackInset = 2.0;

/// 互斥的少量選項(2~4 項),取代 Material 的 `SegmentedButton`。
///
/// 外觀對標 iOS 的 sliding segmented control(淺色軌道加滑動的 thumb),
/// 但自繪以取得 Cupertino 版沒有的鍵盤焦點、Enter／Space 啟動、每段 44pt 高、
/// 明確的 selected／enabled 語意,以及「減少動態效果」時關閉 thumb 滑動。
/// [options] 的迭代順序即顯示順序。[onChanged] 為 null 時停用。
class TpSegmentedControl<T extends Object> extends StatelessWidget {
  const TpSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onChanged != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final keys = options.keys.toList();
    final index = keys.indexOf(value);
    final count = keys.length;
    final trackRadius = TpRadius.sm + _trackInset;

    final segments = Row(
      children: [
        for (final key in keys)
          Expanded(
            child: TpTapTarget(
              onTap: enabled ? () => onChanged!(key) : null,
              button: true,
              selected: key == value,
              inMutuallyExclusiveGroup: true,
              label: options[key],
              focusRadius: trackRadius,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s2),
                  child: Text(
                    options[key]!,
                    maxLines: 1,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: key == value ? FontWeight.w600 : null,
                      color: enabled
                          ? scheme.onSurface
                          : scheme.onSurface.withAlpha(TpDisabled.contentAlpha),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 有限寬度就填滿;無限寬(水平捲動容器內)則各段等寬於最寬者。
        final body = constraints.hasBoundedWidth
            ? segments
            : IntrinsicWidth(child: segments);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(trackRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_trackInset),
            child: Stack(
              children: [
                if (index >= 0)
                  Positioned.fill(
                    child: AnimatedAlign(
                      key: const ValueKey('tp-segment-thumb'),
                      duration: reduceMotion ? Duration.zero : _thumbDuration,
                      curve: Curves.easeOut,
                      alignment: Alignment(
                        count == 1 ? 0 : -1 + 2 * index / (count - 1),
                        0,
                      ),
                      child: FractionallySizedBox(
                        widthFactor: 1 / count,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: enabled
                                ? scheme.surface
                                : scheme.surface.withAlpha(
                                    (TpDisabled.controlOpacity * 255).round(),
                                  ),
                            borderRadius: BorderRadius.circular(TpRadius.sm),
                          ),
                        ),
                      ),
                    ),
                  ),
                body,
              ],
            ),
          ),
        );
      },
    );
  }
}
