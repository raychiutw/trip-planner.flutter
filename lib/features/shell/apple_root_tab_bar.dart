import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../ui/tp_glass_surface.dart';

/// 浮動玻璃 root tab bar：固定高度，不隨捲動縮放。
///
/// Apple 的 `tabBarMinimizeBehavior` 只在 tab bar 底下確實是可捲動內容時才成立；
/// 本 app 多數 root 畫面（地圖、聊天）底下是固定版面，縮放沒有對應的捲動語意，
/// 只會讓導覽在視線裡跳動，因此不採用。
class AppleRootTabBar extends StatelessWidget {
  const AppleRootTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// 玻璃列高度（不含 safe area 與外距）。
  static const barHeight = 64.0;

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
    (
      label: '帳號',
      icon: CupertinoIcons.person,
      selectedIcon: CupertinoIcons.person_fill,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('apple-root-tab-bar'),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TpSpacing.s3,
            0,
            TpSpacing.s3,
            TpSpacing.s2,
          ),
          child: TpGlassSurface(
            borderRadius: const BorderRadius.all(Radius.circular(32)),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                height: barHeight,
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
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: TpSpacing.tapMin,
            minWidth: TpSpacing.tapMin,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 2),
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
    );
  }
}
