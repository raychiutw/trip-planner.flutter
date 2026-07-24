/// App shell：4-tab root navigation（StatefulShellRoute 的外殼）。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_root_scaffold.dart';
import '../account/account_sheet.dart';
import '../offline/offline_status_banner.dart';
import '../trips/current_trip_provider.dart';
import '../trips/trips_list_screen.dart';
import 'apple_root_tab_bar.dart';

/// 4-tab 自適應導覽外殼：聊天／行程／地圖／收藏。
///
/// Compact 寬度將內容延伸到浮動玻璃 tab bar 底下；regular 寬度改在頂部顯示
/// 同一組 tabs。底部錨定內容一律用 `rootTabBottomInset` 避開 compact tab bar。
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

  static const regularNavigationWidth = 720.0;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _rootReselects = ValueNotifier<int>(0);
  final _rootTabFocusNodes = List.generate(
    4,
    (index) => FocusNode(debugLabel: 'root-tab-$index'),
  );

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final regular = constraints.maxWidth >= AppShell.regularNavigationWidth;
        final rootTabs = AppleRootTabBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onSelected: (index) => _selectTab(context, index),
          inline: regular,
          focusNodes: _rootTabFocusNodes,
        );
        return Scaffold(
          extendBody: showRootTab && !regular,
          appBar: showRootTab && regular
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(80),
                  child: KeyedSubtree(
                    key: const ValueKey('apple-regular-root-tabs'),
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(height: 80, child: rootTabs),
                    ),
                  ),
                )
              : null,
          // 內容下方、底部導航上方夾一條離線狀態列(無事時不佔空間)。
          body: TpRootReselectScope(
            notifier: _rootReselects,
            child: Column(
              children: [
                Expanded(
                  key: const ValueKey('app-shell-content'),
                  child: KeyedSubtree(
                    key: const ValueKey('app-shell-detail'),
                    child: widget.navigationShell,
                  ),
                ),
                const OfflineStatusBanner(),
                if (widget.accountPage != null)
                  _AccountSheetDeepLink(
                    page: widget.accountPage!,
                    returnLocation: widget.accountReturnLocation,
                  ),
              ],
            ),
          ),
          bottomNavigationBar: showRootTab && !regular ? rootTabs : null,
        );
      },
    );
  }

  @override
  void dispose() {
    _rootReselects.dispose();
    for (final focusNode in _rootTabFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}

/// 行程 detail 在一般寬度顯示清單，compact 寬度則只保留內容。
///
/// 兩種寬度都維持相同的 Row/Expanded 祖先，避免 resize 重建 detail 狀態。
class AdaptiveTripDetail extends StatelessWidget {
  const AdaptiveTripDetail({
    required this.selectedTripId,
    required this.child,
    super.key,
  });

  final String selectedTripId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final regular = constraints.maxWidth >= AppShell.regularNavigationWidth;
        return Row(
          children: [
            if (regular) ...[
              KeyedSubtree(
                key: const ValueKey('trip-regular-split-view'),
                child: _TripRegularSidebar(selectedTripId: selectedTripId),
              ),
              VerticalDivider(
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ],
            Expanded(key: const ValueKey('trip-adaptive-detail'), child: child),
          ],
        );
      },
    );
  }
}

class _TripRegularSidebar extends ConsumerWidget {
  const _TripRegularSidebar({required this.selectedTripId});

  final String selectedTripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 320,
      child: Material(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
                  child: Text('行程', style: theme.textTheme.titleLarge),
                ),
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Expanded(
              child: ref
                  .watch(myTripsProvider)
                  .when(
                    loading: () => const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                    error: (error, stackTrace) => Center(
                      child: TextButton(
                        onPressed: () => ref.invalidate(myTripsProvider),
                        child: const Text('重新載入行程'),
                      ),
                    ),
                    data: (trips) => _TripRegularList(
                      trips: trips,
                      selectedTripId: selectedTripId,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripRegularList extends ConsumerWidget {
  const _TripRegularList({required this.trips, required this.selectedTripId});

  final List<TripSummary> trips;
  final String selectedTripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (trips.isEmpty) {
      return const Center(child: Text('尚無行程'));
    }
    final theme = Theme.of(context);
    return ListView.builder(
      key: const PageStorageKey('trip-regular-sidebar-list'),
      padding: const EdgeInsets.symmetric(vertical: TpSpacing.s2),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        final selected = trip.tripId == selectedTripId;
        final title = trip.title?.trim();
        final displayTitle = title?.isNotEmpty == true ? title! : trip.name;
        void selectTrip() {
          unawaited(
            ref.read(currentTripIdProvider.notifier).select(trip.tripId),
          );
          context.go('/trips/${Uri.encodeComponent(trip.tripId)}');
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: selectTrip,
          child: Semantics(
            key: ValueKey('trip-sidebar-item-${trip.tripId}'),
            container: true,
            selected: selected,
            button: true,
            label: displayTitle,
            onTap: selectTrip,
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: ListTile(
                  selected: selected,
                  title: Text(displayTitle),
                  leading: const Icon(SFIcons.sf_suitcase),
                  trailing: selected
                      ? Icon(
                          CupertinoIcons.check_mark,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
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
