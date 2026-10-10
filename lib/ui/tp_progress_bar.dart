import 'package:flutter/material.dart';

/// 線性進度條。Cupertino 沒有 linear progress,HIG 的 progress indicator 也只定義
/// 轉圈與帶值的 bar,所以這裡用 `colorScheme` 自繪(不新增套件)。
///
/// [value] 為 null 時是 indeterminate:一段色塊在軌道上來回掃過,
/// 「減少動態效果」開啟時改為靜態半段。語意一律朗讀 [semanticLabel],
/// determinate 另帶百分比。
class TpProgressBar extends StatefulWidget {
  const TpProgressBar({
    super.key,
    this.value,
    this.semanticLabel = '載入中',
    this.height = 4,
  });

  /// 0~1;超出範圍會被 clamp。null 代表 indeterminate。
  final double? value;

  /// 朗讀用標籤;null 代表裝飾性(外層已有標籤或緊鄰文字說明),整條不進語意樹。
  final String? semanticLabel;
  final double height;

  @override
  State<TpProgressBar> createState() => _TpProgressBarState();
}

class _TpProgressBarState extends State<TpProgressBar>
    with TickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void didUpdateWidget(TpProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  /// indeterminate 且未開「減少動態效果」才需要 controller;在生命週期回呼同步,
  /// 不在 build 內產生副作用。
  void _syncController() {
    final animate =
        widget.value == null && !MediaQuery.disableAnimationsOf(context);
    if (animate) {
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    } else {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = widget.value;
    final radius = BorderRadius.circular(widget.height / 2);

    Widget bar;
    if (value != null) {
      bar = _track(
        scheme,
        radius,
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: _fill(scheme, radius),
        ),
      );
    } else if (_controller == null) {
      bar = _track(
        scheme,
        radius,
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: 0.5,
          child: _fill(scheme, radius),
        ),
      );
    } else {
      bar = AnimatedBuilder(
        animation: _controller!,
        builder: (context, _) => _track(
          scheme,
          radius,
          FractionallySizedBox(
            alignment: Alignment(-1 + 2 * _controller!.value, 0),
            widthFactor: 0.35,
            child: _fill(scheme, radius),
          ),
        ),
      );
    }

    if (widget.semanticLabel == null) {
      return ExcludeSemantics(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: bar,
        ),
      );
    }
    return Semantics(
      label: widget.semanticLabel,
      value: value == null ? null : '${(value.clamp(0.0, 1.0) * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: bar,
        ),
      ),
    );
  }

  Widget _track(ColorScheme scheme, BorderRadius radius, Widget child) =>
      DecoratedBox(
        key: const ValueKey('tp-progress-track'),
        decoration: BoxDecoration(
          color: scheme.outlineVariant,
          borderRadius: radius,
        ),
        child: ClipRRect(borderRadius: radius, child: child),
      );

  Widget _fill(ColorScheme scheme, BorderRadius radius) => DecoratedBox(
    key: const ValueKey('tp-progress-fill'),
    decoration: BoxDecoration(color: scheme.primary, borderRadius: radius),
    child: const SizedBox.expand(),
  );
}
