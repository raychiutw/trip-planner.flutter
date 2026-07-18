import 'package:flutter/widgets.dart';

enum TpActionRole { normal, destructive }

@immutable
class TpActionItem<T> {
  const TpActionItem({
    required this.value,
    required this.label,
    required this.icon,
    this.key,
    this.dividerBefore = false,
    this.role = TpActionRole.normal,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData icon;
  final Key? key;
  final bool dividerBefore;
  final TpActionRole role;
  final bool enabled;
}
