import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'dynamic_type.dart';
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

    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    Widget segmentFor(T key, {required bool stacked}) => TpTapTarget(
      onTap: enabled ? () => onChanged!(key) : null,
      button: true,
      selected: key == value,
      inMutuallyExclusiveGroup: true,
      label: options[key],
      focusRadius: trackRadius,
      child: DecoratedBox(
        // 堆疊時沒有滑動 thumb(各列高度可能不同),直接在被選列上色。
        decoration: BoxDecoration(
          color: stacked && key == value
              ? (enabled
                    ? scheme.surface
                    : scheme.surface.withAlpha(
                        (TpDisabled.controlOpacity * 255).round(),
                      ))
              : null,
          borderRadius: BorderRadius.circular(TpRadius.sm),
        ),
        child: Center(
          heightFactor: 1,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: TpSpacing.s2,
              vertical: stacked ? TpSpacing.s1 : 0,
            ),
            child: Text(
              options[key]!,
              maxLines: stacked ? null : 1,
              textAlign: TextAlign.center,
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
    );

    Widget track(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(trackRadius),
      ),
      child: Padding(padding: const EdgeInsets.all(_trackInset), child: child),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 大字級、或單列放不下最寬的標籤時改成上下堆疊:每個選項都完整可見可點,
        // 不縮字、不靠橫向捲動藏選項。
        final stacked =
            isLargeTextScale(context) ||
            (constraints.hasBoundedWidth &&
                !_fitsInRow(
                  context,
                  labelStyle,
                  options.values,
                  constraints.maxWidth - 2 * _trackInset,
                ));
        if (stacked) {
          final column = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final key in keys) segmentFor(key, stacked: true)],
          );
          return track(
            constraints.hasBoundedWidth
                ? column
                : IntrinsicWidth(child: column),
          );
        }
        final segments = Row(
          children: [
            for (final key in keys)
              Expanded(child: segmentFor(key, stacked: false)),
          ],
        );
        // 有限寬度就填滿;無限寬(水平捲動容器內)則各段等寬於最寬者。
        final body = constraints.hasBoundedWidth
            ? segments
            : IntrinsicWidth(child: segments);
        return track(
          Stack(
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
        );
      },
    );
  }

  /// 每段等寬時,最寬的標籤(含左右內距)是否放得進單列。
  bool _fitsInRow(
    BuildContext context,
    TextStyle? style,
    Iterable<String> labels,
    double width,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return (widest + 2 * TpSpacing.s2) * labels.length <= width;
  }
}
