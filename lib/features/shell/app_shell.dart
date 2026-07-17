/// App shell：4-tab root navigation（StatefulShellRoute 的外殼）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../offline/offline_status_banner.dart';
import 'apple_root_tab_bar.dart';

/// 4-tab 底部導航外殼：聊天／行程／地圖／收藏。
///
/// `extendBody` 讓內容延伸到浮動玻璃 tab bar 底下（玻璃要有東西可糊才成立）。
/// 代價是 root tab 畫面的底部錨定內容會被蓋住 — Flutter 會把 tab bar 高度灌進
/// body 的 `MediaQuery.padding.bottom`，畫面一律用 `rootTabBottomInset` 取用。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _selectTab(int selectedIndex) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      selectedIndex,
      initialLocation: selectedIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      // 內容下方、底部導航上方夾一條離線狀態列(無事時不佔空間)。
      body: Column(
        children: [
          Expanded(child: navigationShell),
          const OfflineStatusBanner(),
        ],
      ),
      bottomNavigationBar: AppleRootTabBar(
        selectedIndex: navigationShell.currentIndex,
        onSelected: _selectTab,
      ),
    );
  }
}
