import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import 'trip_card.dart';

/// `GET /my-trips` 清單（本畫面專屬 scope；刪除後 invalidate refresh）。
final myTripsProvider = FutureProvider<List<TripSummary>>((ref) {
  return ref.watch(tripRepositoryProvider).fetchMyTrips();
});

enum _TripsFilterTab { all, mine, collab, archived }

enum _TripsSortBy { updated, start, name }

/// 行程清單（5-tab「行程」分頁）：AppBar「我的行程」+ 下拉更新 + 單欄卡片清單。
/// 點卡片進詳情；長按開 bottom sheet 刪除（AlertDialog 二次確認）。
class TripsListScreen extends ConsumerStatefulWidget {
  const TripsListScreen({super.key});

  @override
  ConsumerState<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends ConsumerState<TripsListScreen> {
  final _searchController = TextEditingController();

  _TripsFilterTab _filterTab = _TripsFilterTab.all;
  _TripsSortBy _sortBy = _TripsSortBy.updated;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myTripsAsync = ref.watch(myTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的行程'),
        actions: [
          IconButton(
            key: const ValueKey('trips-list-add-trip'),
            tooltip: '新增行程',
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/trips/new'),
          ),
        ],
      ),
      body: myTripsAsync.when(
        data: (trips) {
          final visibleTrips = _visibleTrips(trips);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myTripsProvider.future),
            child: trips.isEmpty
                ? const _EmptyHero()
                : _buildTripsContent(context, trips, visibleTrips),
          );
        },
        error: (error, stackTrace) =>
            _ErrorState(onRetry: () => ref.invalidate(myTripsProvider)),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildTripsContent(
    BuildContext context,
    List<TripSummary> trips,
    List<TripSummary> visibleTrips,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        _buildToolbar(trips),
        const SizedBox(height: TpSpacing.s3),
        if (visibleTrips.isEmpty)
          _FilteredEmpty(
            isArchivedTab: _filterTab == _TripsFilterTab.archived,
            onReset: () => setState(() => _filterTab = _TripsFilterTab.all),
          )
        else
          for (var index = 0; index < visibleTrips.length; index++) ...[
            TripCard(
              trip: visibleTrips[index],
              tone: TripCardTone.values[index % TripCardTone.values.length],
              onTap: () => context.go('/trips/${visibleTrips[index].tripId}'),
              onLongPress: () => _showTripActions(context, visibleTrips[index]),
            ),
            if (index != visibleTrips.length - 1)
              const SizedBox(height: TpSpacing.s3),
          ],
      ],
    );
  }

  Widget _buildToolbar(List<TripSummary> trips) {
    final counts = _tabCounts(trips);
    return DecoratedBox(
      key: const ValueKey('trips-list-toolbar'),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_TripsFilterTab>(
                segments: [
                  ButtonSegment(
                    value: _TripsFilterTab.all,
                    label: Text(
                      '全部 ${counts.all}',
                      key: const ValueKey('trips-list-tab-all'),
                    ),
                  ),
                  ButtonSegment(
                    value: _TripsFilterTab.mine,
                    label: Text(
                      '我的 ${counts.mine}',
                      key: const ValueKey('trips-list-tab-mine'),
                    ),
                  ),
                  ButtonSegment(
                    value: _TripsFilterTab.collab,
                    label: Text(
                      '共編 ${counts.collab}',
                      key: const ValueKey('trips-list-tab-collab'),
                    ),
                  ),
                  ButtonSegment(
                    value: _TripsFilterTab.archived,
                    label: Text(
                      '已歸檔 ${counts.archived}',
                      key: const ValueKey('trips-list-tab-archived'),
                    ),
                  ),
                ],
                selected: {_filterTab},
                onSelectionChanged: (selection) {
                  setState(() => _filterTab = selection.single);
                },
              ),
            ),
            const SizedBox(height: TpSpacing.s3),
            LayoutBuilder(
              builder: (context, constraints) {
                final searchField = TextField(
                  key: const ValueKey('trips-list-search-input'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: '搜尋行程',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey('trips-list-search-clear'),
                            tooltip: '清除搜尋',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                );
                final sortField = SizedBox(
                  width: constraints.maxWidth < 520 ? double.infinity : 176,
                  child: DropdownButtonFormField<_TripsSortBy>(
                    key: const ValueKey('trips-list-sort'),
                    initialValue: _sortBy,
                    decoration: const InputDecoration(
                      labelText: '排序',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _TripsSortBy.updated,
                        child: Text('最新編輯'),
                      ),
                      DropdownMenuItem(
                        value: _TripsSortBy.start,
                        child: Text('出發日近'),
                      ),
                      DropdownMenuItem(
                        value: _TripsSortBy.name,
                        child: Text('名稱 A-Z'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _sortBy = value);
                    },
                  ),
                );

                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: TpSpacing.s2),
                      sortField,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: TpSpacing.s2),
                    sortField,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<TripSummary> _visibleTrips(List<TripSummary> trips) {
    var list = trips.where((trip) {
      final archived = _isArchived(trip);
      return switch (_filterTab) {
        _TripsFilterTab.archived => archived,
        _TripsFilterTab.all => !archived,
        _TripsFilterTab.mine => !archived && _isMine(trip),
        _TripsFilterTab.collab => !archived && _isCollab(trip),
      };
    }).toList();

    final term = _searchController.text.trim().toLowerCase();
    if (term.isNotEmpty) {
      list = list.where((trip) {
        final haystack = [
          trip.title,
          trip.name,
          trip.countries,
        ].whereType<String>().join(' ').toLowerCase();
        return haystack.contains(term);
      }).toList();
    }

    switch (_sortBy) {
      case _TripsSortBy.updated:
        return list;
      case _TripsSortBy.start:
        list.sort((a, b) {
          final av = a.startDate?.trim().isEmpty ?? true
              ? '9999'
              : a.startDate!.trim();
          final bv = b.startDate?.trim().isEmpty ?? true
              ? '9999'
              : b.startDate!.trim();
          return av.compareTo(bv);
        });
      case _TripsSortBy.name:
        list.sort(
          (a, b) => a.displayTitle.toLowerCase().compareTo(
            b.displayTitle.toLowerCase(),
          ),
        );
    }
    return list;
  }

  ({int all, int mine, int collab, int archived}) _tabCounts(
    List<TripSummary> trips,
  ) {
    final activeTrips = trips.where((trip) => !_isArchived(trip)).toList();
    final mine = activeTrips.where(_isMine).length;
    return (
      all: activeTrips.length,
      mine: mine,
      collab: activeTrips.where(_isCollab).length,
      archived: trips.length - activeTrips.length,
    );
  }

  bool _isArchived(TripSummary trip) {
    return trip.archivedAt != null && trip.archivedAt!.trim().isNotEmpty;
  }

  bool _isMine(TripSummary trip) => trip.role?.toLowerCase() == 'owner';

  bool _isCollab(TripSummary trip) {
    final role = trip.role?.toLowerCase();
    return role != null && role != 'owner';
  }

  /// 長按卡片 → bottom sheet（刪除行程）。
  Future<void> _showTripActions(BuildContext context, TripSummary trip) async {
    final selectedAction = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TpRadius.xl)),
      ),
      builder: (sheetContext) {
        final destructiveColor = Theme.of(sheetContext).colorScheme.error;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: TpSpacing.s2),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('編輯行程'),
                onTap: () => Navigator.of(sheetContext).pop('edit'),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: destructiveColor),
                title: Text(
                  '刪除行程',
                  style: TextStyle(
                    color: destructiveColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
              const SizedBox(height: TpSpacing.s2),
            ],
          ),
        );
      },
    );
    if (!context.mounted) return;
    if (selectedAction == 'edit') {
      context.go('/trips/${trip.tripId}/edit');
      return;
    }
    if (selectedAction != 'delete') return;
    await _confirmAndDeleteTrip(context, trip);
  }

  /// AlertDialog 二次確認 → deleteTrip → invalidate refresh。
  Future<void> _confirmAndDeleteTrip(
    BuildContext context,
    TripSummary trip,
  ) async {
    final confirmedDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogColorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(TpRadius.xl)),
          ),
          title: const Text('刪除行程'),
          content: Text('確定要刪除「${trip.displayTitle}」嗎？此動作無法復原。'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(shape: const StadiumBorder()),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dialogColorScheme.error,
                foregroundColor: dialogColorScheme.onError,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (confirmedDelete != true || !context.mounted) return;

    try {
      await ref.read(tripRepositoryProvider).deleteTrip(trip.tripId);
      ref.invalidate(myTripsProvider);
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('刪除失敗，請稍後再試')));
    }
  }
}

/// 空清單 hero 文案。
class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 包進 scrollable 讓空清單也能下拉更新
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('還沒有行程', style: theme.textTheme.titleLarge),
                const SizedBox(height: TpSpacing.s2),
                Text(
                  '建立第一趟旅程，開始規劃你的旅行。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: TpSpacing.s4),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('新增行程'),
                  onPressed: () => context.go('/trips/new'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 篩選後沒有結果：保留工具列，讓使用者能直接改條件。
class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.isArchivedTab, required this.onReset});

  final bool isArchivedTab;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TpSpacing.s8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isArchivedTab
                  ? '目前沒有已歸檔行程。歸檔行程會在這裡顯示。'
                  : '沒有符合條件的行程。試著切換分類或調整搜尋字。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (isArchivedTab) ...[
              const SizedBox(height: TpSpacing.s3),
              TextButton(
                key: const ValueKey('trips-list-archived-reset'),
                onPressed: onReset,
                child: const Text('回到全部'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 載入失敗：文案 + 重試按鈕。
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('載入失敗', style: theme.textTheme.titleMedium),
          const SizedBox(height: TpSpacing.s2),
          Text(
            '無法取得行程清單，請檢查網路後再試一次。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TpSpacing.s4),
          FilledButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}
