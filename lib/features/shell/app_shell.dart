/// App shell：5-tab root navigation（StatefulShellRoute 的外殼）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../offline/offline_status_banner.dart';
import 'apple_root_tab_bar.dart';

/// 5-tab 底部導航外殼：聊天／行程／地圖／收藏／帳號。
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _tabBarMinimized = false;

  bool _handleScroll(ScrollNotification notification) {
    if (kIsWeb || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    bool? nextValue;
    if (notification.metrics.pixels <= 0) {
      nextValue = false;
    } else if (notification case ScrollUpdateNotification(:final scrollDelta)) {
      if (scrollDelta != null && scrollDelta.abs() >= 1) {
        nextValue = scrollDelta > 0;
      }
    }

    if (nextValue != null && nextValue != _tabBarMinimized) {
      setState(() => _tabBarMinimized = nextValue!);
    }
    return false;
  }

  void _selectTab(int selectedIndex) {
    if (_tabBarMinimized) {
      setState(() => _tabBarMinimized = false);
    }
    HapticFeedback.selectionClick();
    widget.navigationShell.goBranch(
      selectedIndex,
      initialLocation: selectedIndex == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      // 內容下方、底部導航上方夾一條離線狀態列(無事時不佔空間)。
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: Column(
          children: [
            Expanded(child: widget.navigationShell),
            const OfflineStatusBanner(),
          ],
        ),
      ),
      bottomNavigationBar: AppleRootTabBar(
        selectedIndex: widget.navigationShell.currentIndex,
        minimized: _tabBarMinimized,
        onSelected: _selectTab,
      ),
    );
  }
}
