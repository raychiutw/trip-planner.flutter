import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_glass_surface.dart';

/// Root tab bar：固定尺寸、恆顯 label。
///
/// 刻意不做 iOS 26 的 tab bar minimize —— Apple 的 minimize 語意綁定「tab bar
/// 底下是可捲動內容」，本 app 多數 root 畫面底下是固定版面，縮放只會讓導覽跳動。
class AppleRootTabBar extends StatelessWidget {
  const AppleRootTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _destinations = [
    (
      label: '聊天',
      icon: CupertinoIcons.chat_bubble,
      selectedIcon: CupertinoIcons.chat_bubble_fill,
    ),
    (
      label: '行程',
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
    ),
    (
      label: '地圖',
      icon: CupertinoIcons.map,
      selectedIcon: CupertinoIcons.map_fill,
    ),
    (
      label: '收藏',
      icon: CupertinoIcons.heart,
      selectedIcon: CupertinoIcons.heart_fill,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintColor = isDark
        ? TpColorsDark.glass.withValues(alpha: 0.38)
        : TpColorsLight.background.withValues(alpha: 0.42);
    return KeyedSubtree(
      key: const ValueKey('apple-root-tab-bar'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TpRootTabGeometry.horizontalMargin,
          0,
          TpRootTabGeometry.horizontalMargin,
          TpRootTabGeometry.bottomOffset(context),
        ),
        child: TpGlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          tintColor: tintColor,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              height: TpRootTabGeometry.expandedBarHeight,
              child: Row(
                children: [
                  for (var index = 0; index < _destinations.length; index++)
                    Expanded(
                      child: _RootTabItem(
                        destination: _destinations[index],
                        selected: selectedIndex == index,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RootTabItem extends StatelessWidget {
  const _RootTabItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ({String label, IconData icon, IconData selectedIcon}) destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;
    return Semantics(
      key: ValueKey('root-tab-${destination.label}'),
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: DecoratedBox(
              key: selected
                  ? ValueKey('root-tab-selected-surface-${destination.label}')
                  : null,
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).extension<TpTones>()!.accentSubtle
                    : Colors.transparent,
                borderRadius: const BorderRadius.all(Radius.circular(19)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 20,
                    color: color,
                  ),
                  Text(
                    destination.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
