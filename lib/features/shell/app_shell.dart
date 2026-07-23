/// App shell：4-tab root navigation（StatefulShellRoute 的外殼）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../ui/tp_root_scaffold.dart';
import '../account/account_sheet.dart';
import '../offline/offline_status_banner.dart';
import 'apple_root_tab_bar.dart';

/// 4-tab 底部導航外殼：聊天／行程／地圖／收藏。
///
/// `extendBody` 讓內容延伸到浮動玻璃 tab bar 底下（玻璃要有東西可糊才成立）。
/// 代價是 root tab 畫面的底部錨定內容會被蓋住 — Flutter 會把 tab bar 高度灌進
/// body 的 `MediaQuery.padding.bottom`，畫面一律用 `rootTabBottomInset` 取用。
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    this.showRootTab = true,
    this.accountPage,
    this.accountReturnLocation = '/trips',
  });

  final StatefulNavigationShell navigationShell;
  final bool showRootTab;
  final String? accountPage;
  final String accountReturnLocation;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _rootReselects = ValueNotifier<int>(0);

  void _selectTab(BuildContext context, int selectedIndex) {
    HapticFeedback.selectionClick();
    final navigationShell = widget.navigationShell;
    if (selectedIndex == navigationShell.currentIndex &&
        GoRouterState.of(context).matchedLocation ==
            navigationShell.route.branches[selectedIndex].defaultRoute?.path) {
      _rootReselects.value++;
      return;
    }
    navigationShell.goBranch(
      selectedIndex,
      initialLocation: selectedIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showRootTab =
        widget.showRootTab && MediaQuery.viewInsetsOf(context).bottom == 0;
    return Scaffold(
      extendBody: showRootTab,
      // 內容下方、底部導航上方夾一條離線狀態列(無事時不佔空間)。
      body: TpRootReselectScope(
        notifier: _rootReselects,
        child: Column(
          children: [
            Expanded(child: widget.navigationShell),
            const OfflineStatusBanner(),
            if (widget.accountPage != null)
              _AccountSheetDeepLink(
                page: widget.accountPage!,
                returnLocation: widget.accountReturnLocation,
              ),
          ],
        ),
      ),
      bottomNavigationBar: showRootTab
          ? AppleRootTabBar(
              selectedIndex: widget.navigationShell.currentIndex,
              onSelected: (index) => _selectTab(context, index),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _rootReselects.dispose();
    super.dispose();
  }
}

class _AccountSheetDeepLink extends StatefulWidget {
  const _AccountSheetDeepLink({
    required this.page,
    required this.returnLocation,
  });

  final String page;
  final String returnLocation;

  @override
  State<_AccountSheetDeepLink> createState() => _AccountSheetDeepLinkState();
}

class _AccountSheetDeepLinkState extends State<_AccountSheetDeepLink> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open());
    });
  }

  Future<void> _open() async {
    final router = GoRouter.of(context);
    final returnLocation = widget.returnLocation;
    await showAccountSheet(context, page: widget.page);
    router.go(returnLocation);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
