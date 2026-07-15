import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tp_glass_surface.dart';

enum TpAccessoryDetent { collapsed, medium }

class TpBottomAccessory extends StatelessWidget {
  const TpBottomAccessory({
    super.key,
    required this.detent,
    required this.collapsed,
    required this.medium,
    required this.onChanged,
  });

  static const collapsedHeight = 72.0;
  static const mediumHeight = 220.0;

  final TpAccessoryDetent detent;
  final Widget collapsed;
  final Widget medium;
  final ValueChanged<TpAccessoryDetent> onChanged;

  void _toggle() => onChanged(
    detent == TpAccessoryDetent.collapsed
        ? TpAccessoryDetent.medium
        : TpAccessoryDetent.collapsed,
  );

  @override
  Widget build(BuildContext context) {
    final isCollapsed = detent == TpAccessoryDetent.collapsed;
    return Semantics(
      button: true,
      label: isCollapsed ? '展開景點' : '收合景點',
      onTap: _toggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isCollapsed ? _toggle : null,
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -100 && isCollapsed) {
            onChanged(TpAccessoryDetent.medium);
          } else if (velocity > 100 && !isCollapsed) {
            onChanged(TpAccessoryDetent.collapsed);
          }
        },
        child: AnimatedContainer(
          key: const ValueKey('tp-bottom-accessory'),
          duration: TpMotion.resolve(context, TpMotion.normal),
          curve: TpMotion.appleEase,
          height: isCollapsed ? collapsedHeight : mediumHeight,
          child: TpGlassSurface(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(TpRadius.xl),
            ),
            child: isCollapsed ? collapsed : medium,
          ),
        ),
      ),
    );
  }
}
