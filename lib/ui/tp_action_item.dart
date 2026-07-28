import 'package:flutter/widgets.dart';

enum TpActionRole { normal, destructive }

@immutable
class TpActionItem<T> {
  const TpActionItem({
    required this.value,
    required this.label,
    this.icon,
    this.key,
    this.semanticLabel,
    this.selected = false,
    this.dividerBefore = false,
    this.role = TpActionRole.normal,
    this.enabled = true,
  });

  final T value;
  final String label;

  /// 選單(`TpMoreMenuButton`)的項目字符，畫在標題前。
  ///
  /// 可省略：`showAppActionSheet` 依 HIG 不畫字符，action sheet 專用的項目給
  /// 字符也不會被畫出來 —— 那種情況一律留空，不要為了填欄位塞一個看不到的值。
  final IconData? icon;
  final Key? key;
  final String? semanticLabel;

  /// 目前選取中。呈現規則:保留 [icon] 原本的字符,勾選另外顯示 —— 不以勾取代字符。
  final bool selected;
  final bool dividerBefore;
  final TpActionRole role;
  final bool enabled;
}
