/// App shell：依裝置寬度與平台切換導覽元件。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../offline/offline_status_banner.dart';

const _wideNavigationBreakpoint = 768.0;

/// 5-tab 導覽外殼：聊天／行程／地圖／收藏／帳號。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _selectBranch(int selectedIndex) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      selectedIndex,
      // 點擊目前 tab 時回到該 branch 的初始路徑。
      initialLocation: selectedIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideNavigationBreakpoint) {
          return _WideShell(
            navigationShell: navigationShell,
            onDestinationSelected: _selectBranch,
          );
        }

        return _CompactShell(
          navigationShell: navigationShell,
          onDestinationSelected: _selectBranch,
        );
      },
    );
  }
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({
    required this.navigationShell,
    required this.onDestinationSelected,
  });

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final usesCupertinoTabBar =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: navigationShell),
          const OfflineStatusBanner(),
        ],
      ),
      bottomNavigationBar: usesCupertinoTabBar
          ? CupertinoTabBar(
              currentIndex: navigationShell.currentIndex,
              onTap: onDestinationSelected,
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.onSurfaceVariant,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.92),
              items: _cupertinoItems,
            )
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: _materialDestinations,
            ),
    );
  }
}

class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.navigationShell,
    required this.onDestinationSelected,
  });

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: _railDestinations,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(child: navigationShell),
                const OfflineStatusBanner(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _materialDestinations = [
  NavigationDestination(
    icon: Icon(Icons.chat_bubble_outline),
    selectedIcon: Icon(Icons.chat_bubble),
    label: '聊天',
  ),
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: '行程',
  ),
  NavigationDestination(
    icon: Icon(Icons.map_outlined),
    selectedIcon: Icon(Icons.map),
    label: '地圖',
  ),
  NavigationDestination(
    icon: Icon(Icons.favorite_outline),
    selectedIcon: Icon(Icons.favorite),
    label: '收藏',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline),
    selectedIcon: Icon(Icons.person),
    label: '帳號',
  ),
];

const _railDestinations = [
  NavigationRailDestination(
    icon: Icon(Icons.chat_bubble_outline),
    selectedIcon: Icon(Icons.chat_bubble),
    label: Text('聊天'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: Text('行程'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.map_outlined),
    selectedIcon: Icon(Icons.map),
    label: Text('地圖'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.favorite_outline),
    selectedIcon: Icon(Icons.favorite),
    label: Text('收藏'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.person_outline),
    selectedIcon: Icon(Icons.person),
    label: Text('帳號'),
  ),
];

const _cupertinoItems = [
  BottomNavigationBarItem(
    icon: Icon(CupertinoIcons.chat_bubble),
    activeIcon: Icon(CupertinoIcons.chat_bubble_fill),
    label: '聊天',
  ),
  BottomNavigationBarItem(
    icon: Icon(CupertinoIcons.house),
    activeIcon: Icon(CupertinoIcons.house_fill),
    label: '行程',
  ),
  BottomNavigationBarItem(
    icon: Icon(CupertinoIcons.map),
    activeIcon: Icon(CupertinoIcons.map_fill),
    label: '地圖',
  ),
  BottomNavigationBarItem(
    icon: Icon(CupertinoIcons.heart),
    activeIcon: Icon(CupertinoIcons.heart_fill),
    label: '收藏',
  ),
  BottomNavigationBarItem(
    icon: Icon(CupertinoIcons.person),
    activeIcon: Icon(CupertinoIcons.person_fill),
    label: '帳號',
  ),
];
