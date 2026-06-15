import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import 'trip_card.dart';

/// `GET /my-trips` 清單（SWR:stale→fresh;刪除後 invalidate refresh）。
final myTripsProvider = StreamProvider<List<TripSummary>>((ref) {
  return ref.watch(tripRepositoryProvider).watchMyTrips();
});

/// 行程清單（5-tab「行程」分頁）：AppBar「我的行程」+ 搜尋框 + 下拉更新 + 單欄卡片清單。
/// 點卡片進詳情；長按開 bottom sheet 刪除（AlertDialog 二次確認）。
class TripsListScreen extends ConsumerStatefulWidget {
  const TripsListScreen({super.key});

  @override
  ConsumerState<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends ConsumerState<TripsListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TripSummary> _filter(List<TripSummary> trips) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return trips;
    return trips
        .where(
          (t) =>
              t.displayTitle.toLowerCase().contains(q) ||
              t.name.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final myTripsAsync = ref.watch(myTripsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('我的行程')),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('trips-create-fab'),
        onPressed: () => context.push('/new-trip'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TpSpacing.s4,
              TpSpacing.s2,
              TpSpacing.s4,
              TpSpacing.s2,
            ),
            child: TextField(
              key: const ValueKey('trips-search-field'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜尋行程',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: myTripsAsync.when(
              data: (trips) {
                final filtered = _filter(trips);
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(myTripsProvider.future),
                  child: trips.isEmpty
                      ? const _EmptyHero()
                      : filtered.isEmpty
                          ? _buildNoResults(theme)
                          : _buildTripList(context, filtered),
                );
              },
              error: (error, stackTrace) =>
                  _ErrorState(onRetry: () => ref.invalidate(myTripsProvider)),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(ThemeData theme) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              '找不到符合的行程',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTripList(BuildContext context, List<TripSummary> trips) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(TpSpacing.s4),
      itemCount: trips.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: TpSpacing.s3),
      itemBuilder: (context, index) {
        final trip = trips[index];
        return TripCard(
          trip: trip,
          tone: TripCardTone.values[index % TripCardTone.values.length],
          onTap: () => context.go('/trips/${trip.tripId}'),
          onLongPress: () => _showTripActions(context, trip),
        );
      },
    );
  }

  /// 長按卡片 → bottom sheet（刪除行程）。
  Future<void> _showTripActions(BuildContext context, TripSummary trip) async {
    final selectedDelete = await showModalBottomSheet<bool>(
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
                leading: const Icon(Icons.ios_share),
                title: const Text('分享'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/share-trip/${trip.tripId}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('共編設定'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/collab/${trip.tripId}');
                },
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
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: TpSpacing.s2),
            ],
          ),
        );
      },
    );
    if (selectedDelete != true || !context.mounted) return;
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
              ],
            ),
          ),
        ),
      ],
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
