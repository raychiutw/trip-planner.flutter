/// App shell：5-tab NavigationBar（StatefulShellRoute 的外殼）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../offline/offline_status_banner.dart';

/// 5-tab 底部導航外殼：聊天／行程／地圖／收藏／帳號。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 內容下方、底部導航上方夾一條離線狀態列(無事時不佔空間)。
      body: Column(
        children: [
          Expanded(child: navigationShell),
          const OfflineStatusBanner(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (selectedIndex) {
          HapticFeedback.selectionClick();
          navigationShell.goBranch(
            selectedIndex,
            // 點擊目前 tab 時回到該 branch 的初始路徑
            initialLocation: selectedIndex == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: '聊天',
          ),
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '行程'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: '地圖'),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            label: '收藏',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '帳號'),
        ],
      ),
    );
  }
}
