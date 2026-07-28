import 'package:flutter/material.dart';

class TpScopeOption<T> {
  const TpScopeOption({
    required this.value,
    required this.label,
    this.semanticsLabel,
    this.icon,
    this.indicatorColor,
    this.isAction = false,
    this.key,
  });

  final T value;
  final String label;
  final String? semanticsLabel;
  final IconData? icon;
  final Color? indicatorColor;
  final bool isAction;
  final Key? key;
}
