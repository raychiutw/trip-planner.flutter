/// App shell：5-tab NavigationBar（StatefulShellRoute 的外殼）。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 5-tab 底部導航外殼：聊天／行程／地圖／收藏／帳號。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (selectedIndex) => navigationShell.goBranch(
          selectedIndex,
          // 點擊目前 tab 時回到該 branch 的初始路徑
          initialLocation: selectedIndex == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: '聊天',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: '行程',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: '地圖',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            label: '收藏',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: '帳號',
          ),
        ],
      ),
    );
  }
}

/// 尚未實作功能的占位畫面（聊天／全域地圖／收藏）。
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '即將推出',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
