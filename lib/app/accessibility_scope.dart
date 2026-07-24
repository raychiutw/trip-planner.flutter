import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 將 iOS 的 Reduce Transparency 設定提供給 App widget tree。
///
/// Flutter 未提供此 accessibility flag；非 iOS 或 platform channel 不可用時，
/// 安全回退為關閉。測試與 artifact flow 可直接注入 [reduceTransparency]。
class AppAccessibilityScope extends StatelessWidget {
  const AppAccessibilityScope({
    super.key,
    this.reduceTransparency,
    required this.child,
  });

  static const _channel = EventChannel(
    'tripline/accessibility/reduce-transparency',
  );
  static final Stream<Object?> _events = _channel.receiveBroadcastStream();

  final bool? reduceTransparency;
  final Widget child;

  static bool reduceTransparencyOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_AppAccessibilityData>()
          ?.reduceTransparency ??
      false;

  @override
  Widget build(BuildContext context) {
    final injectedValue = reduceTransparency;
    if (injectedValue != null) {
      return _AppAccessibilityData(
        reduceTransparency: injectedValue,
        child: child,
      );
    }
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return _AppAccessibilityData(reduceTransparency: false, child: child);
    }
    return StreamBuilder<Object?>(
      stream: _events,
      initialData: true,
      builder: (context, snapshot) => _AppAccessibilityData(
        reduceTransparency: snapshot.hasError || snapshot.data != false,
        child: child,
      ),
    );
  }
}

class _AppAccessibilityData extends InheritedWidget {
  const _AppAccessibilityData({
    required this.reduceTransparency,
    required super.child,
  });

  final bool reduceTransparency;

  @override
  bool updateShouldNotify(_AppAccessibilityData oldWidget) =>
      reduceTransparency != oldWidget.reduceTransparency;
}
