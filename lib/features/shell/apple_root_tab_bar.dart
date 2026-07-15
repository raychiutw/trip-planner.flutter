import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../ui/tp_glass_surface.dart';

class AppleRootTabBar extends StatelessWidget {
  const AppleRootTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.minimized,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool minimized;

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
    final duration = TpMotion.resolve(context, TpMotion.normal);
    return KeyedSubtree(
      key: const ValueKey('apple-root-tab-bar'),
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: duration,
          curve: TpMotion.appleEase,
          padding: EdgeInsets.fromLTRB(
            minimized ? 36 : 12,
            0,
            minimized ? 36 : 12,
            8,
          ),
          child: TpGlassSurface(
            borderRadius: const BorderRadius.all(Radius.circular(32)),
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: duration,
                curve: TpMotion.appleEase,
                height: minimized ? 50 : 64,
                child: Row(
                  children: [
                    for (var index = 0; index < _destinations.length; index++)
                      Expanded(
                        child: _RootTabItem(
                          destination: _destinations[index],
                          selected: selectedIndex == index,
                          minimized: minimized,
                          duration: duration,
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
    required this.minimized,
    required this.duration,
    required this.onTap,
  });

  final ({String label, IconData icon, IconData selectedIcon}) destination;
  final bool selected;
  final bool minimized;
  final Duration duration;
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
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: AnimatedSize(
            duration: duration,
            curve: TpMotion.appleEase,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 22,
                  color: color,
                ),
                if (!minimized) ...[
                  const SizedBox(height: 2),
                  Text(
                    destination.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
