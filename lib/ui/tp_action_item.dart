import 'package:flutter/widgets.dart';

enum TpActionRole { normal, destructive }

@immutable
class TpActionItem<T> {
  const TpActionItem({
    required this.value,
    required this.label,
    required this.icon,
    this.key,
    this.semanticLabel,
    this.selected = false,
    this.dividerBefore = false,
    this.role = TpActionRole.normal,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData icon;
  final Key? key;
  final String? semanticLabel;

  /// 目前選取中。呈現規則:保留 [icon] 原本的字符,勾選另外顯示 —— 不以勾取代字符。
  final bool selected;
  final bool dividerBefore;
  final TpActionRole role;
  final bool enabled;
}
