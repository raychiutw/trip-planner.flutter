import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/adaptive.dart';
import '../../models/add_to_trip.dart';
import '../../models/poi_favorite.dart';
import '../../models/poi_type.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_account_avatar_button.dart';
import '../../ui/tp_action_item.dart';
import '../../ui/tp_app_bar.dart';
import '../../ui/tp_root_scroll_scaffold.dart';
import 'favorites_providers.dart';
import 'poi_favorite_card.dart';

const _typeFilterOptions = [
  _TypeFilterOption(key: 'all', label: '全部'),
  _TypeFilterOption(key: 'restaurant', label: '餐廳'),
  _TypeFilterOption(key: 'attraction', label: '景點'),
  _TypeFilterOption(key: 'shopping', label: '購物'),
  _TypeFilterOption(key: 'hotel', label: '住宿'),
];

const _favoritesPageSize = 24;
const _favoritesPaginationThreshold = 200;

final _regionRules = [
  MapEntry(RegExp('沖縄|沖繩', caseSensitive: false), '沖繩'),
  MapEntry(RegExp('京都'), '京都'),
  MapEntry(RegExp('大阪'), '大阪'),
  MapEntry(RegExp('東京'), '東京'),
  MapEntry(RegExp('釜山|부산', caseSensitive: false), '釜山'),
  MapEntry(RegExp('首爾|서울', caseSensitive: false), '首爾'),
  MapEntry(RegExp('台北', caseSensitive: false), '台北'),
];

/// 收藏清單（root「收藏」分頁）：GET /poi-favorites，heart 取消收藏（確認對話框）。
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'all';
  String _regionFilter = 'all';
  Set<int> _selectedIds = {};
  bool _deletingSelected = false;
  int _page = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return TpRootScrollScaffold(
      title: '收藏',
      onRefresh: () => ref.refresh(favoritesProvider.future),
      actions: [
        TpToolbarIconButton(
          key: const ValueKey('favorites-explore-action'),
          tooltip: '探索',
          icon: CupertinoIcons.search,
          onPressed: () => context.go('/favorites/explore'),
        ),
        const TpAccountAvatarButton(),
      ],
      slivers: [
        ...favoritesAsync.when(
          data: (favorites) => favorites.isEmpty
              ? [
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyHero(),
                  ),
                ]
              : _buildListSlivers(context, ref, favorites),
          error: (error, stackTrace) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(
                onRetry: () => ref.invalidate(favoritesProvider),
              ),
            ),
          ],
          loading: () => const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildListSlivers(
    BuildContext context,
    WidgetRef ref,
    List<PoiFavorite> favorites,
  ) {
    final filteredFavorites = _filterFavorites(
      favorites,
      _searchQuery,
      _typeFilter,
      _regionFilter,
    );
    final regionCounts = _regionCountsFor(favorites);
    final regionOptions = _regionOptionsFor(regionCounts);
    final usePagination = favorites.length >= _favoritesPaginationThreshold;
    final totalPages = usePagination && filteredFavorites.isNotEmpty
        ? (filteredFavorites.length / _favoritesPageSize).ceil()
        : 1;
    final page = _page.clamp(1, totalPages).toInt();
    if (page != _page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _page = page);
      });
    }
    final visibleFavorites = usePagination
        ? filteredFavorites
              .skip((page - 1) * _favoritesPageSize)
              .take(_favoritesPageSize)
              .toList()
        : filteredFavorites;

    return [
      // 底部淨空由 TpRootScrollScaffold 統一提供，這裡不再自行處理。
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          TpSpacing.s4,
          TpSpacing.s3,
          TpSpacing.s4,
          TpSpacing.s4,
        ),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    fieldKey: const ValueKey('favorites-search-input'),
                    controller: _searchController,
                    placeholder: '搜尋收藏',
                    onChanged: (value) => setState(() {
                      _searchQuery = value;
                      _page = 1;
                    }),
                  ),
                ),
                const SizedBox(width: TpSpacing.s2),
                IconButton.filledTonal(
                  key: const ValueKey('favorites-filter-button'),
                  tooltip: '篩選',
                  icon: Icon(
                    _hasActiveFilters
                        ? CupertinoIcons.line_horizontal_3_decrease_circle_fill
                        : CupertinoIcons.line_horizontal_3_decrease_circle,
                  ),
                  onPressed: () => _openFilters(regionCounts, regionOptions),
                ),
              ],
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: TpSpacing.s2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _activeFilterSummary,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: TpSpacing.s3),
            if (_selectedIds.isNotEmpty) ...[
              _BulkToolbar(
                selectedCount: _selectedIds.length,
                deleting: _deletingSelected,
                onSelectAll: () => _selectAllVisible(visibleFavorites),
                onClear: _clearSelection,
                onDelete: _confirmDeleteSelected,
              ),
              const SizedBox(height: TpSpacing.s3),
            ],
            if (filteredFavorites.isEmpty)
              _NoSearchResult(onClear: _clearAllFilters)
            else
              for (final favorite in visibleFavorites) ...[
                PoiFavoriteCard(
                  favorite: favorite,
                  selected: _selectedIds.contains(favorite.id),
                  selectionMode: _selectedIds.isNotEmpty,
                  onSelectedChanged: _deletingSelected
                      ? null
                      : (_) => _toggleFavoriteSelection(favorite.id),
                  onRemove: () => _confirmRemove(context, ref, favorite),
                  onLongPress: () =>
                      _showFavoriteActions(context, ref, favorite),
                ),
                const SizedBox(height: TpSpacing.s3),
              ],
            if (usePagination && filteredFavorites.isNotEmpty)
              _PaginationControls(
                page: page,
                totalPages: totalPages,
                start: (page - 1) * _favoritesPageSize + 1,
                end: (page - 1) * _favoritesPageSize + visibleFavorites.length,
                total: filteredFavorites.length,
                onPrevious: page <= 1
                    ? null
                    : () => setState(() => _page = page - 1),
                onNext: page >= totalPages
                    ? null
                    : () => setState(() => _page = page + 1),
              ),
          ]),
        ),
      ),
    ];
  }

  bool get _hasActiveFilters => _typeFilter != 'all' || _regionFilter != 'all';

  String get _activeFilterSummary {
    final labels = <String>[];
    if (_typeFilter != 'all') {
      labels.add(
        _typeFilterOptions
            .firstWhere((option) => option.key == _typeFilter)
            .label,
      );
    }
    if (_regionFilter != 'all') labels.add(_regionFilter);
    return '已篩選：${labels.join(' · ')}';
  }

  Future<void> _openFilters(
    Map<String, int> regionCounts,
    List<String> regionOptions,
  ) async {
    final controller = AppSheetFormController();
    try {
      await showAppFormSheet(
        context,
        title: '篩選收藏',
        submitLabel: '套用',
        submitKey: const ValueKey('favorites-filter-apply'),
        controller: controller,
        builder: (_) => _FavoritesFilterForm(
          controller: controller,
          initialType: _typeFilter,
          initialRegion: _regionFilter,
          regionCounts: regionCounts,
          regionOptions: regionOptions,
          onApply: (type, region) async {
            if (!mounted) return false;
            setState(() {
              _typeFilter = type;
              _regionFilter = region;
              _page = 1;
            });
            return true;
          },
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showFavoriteActions(
    BuildContext context,
    WidgetRef ref,
    PoiFavorite favorite,
  ) async {
    final action = await showAppActionSheet<_FavoriteContextAction>(
      context,
      actions: const [
        TpActionItem(
          label: '加入行程',
          value: _FavoriteContextAction.addToTrip,
          icon: CupertinoIcons.calendar_badge_plus,
        ),
        TpActionItem(
          label: '選取',
          value: _FavoriteContextAction.select,
          icon: CupertinoIcons.check_mark_circled,
        ),
        TpActionItem(
          label: '取消收藏',
          value: _FavoriteContextAction.remove,
          icon: CupertinoIcons.heart_slash,
          dividerBefore: true,
          role: TpActionRole.destructive,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (action) {
      case _FavoriteContextAction.addToTrip:
        context.go(
          '/favorites/add-to-trip',
          extra: AddToTripFavorite(
            favoriteId: favorite.id,
            displayName: favorite.displayName,
          ),
        );
        return;
      case _FavoriteContextAction.select:
        _toggleFavoriteSelection(favorite.id);
        return;
      case _FavoriteContextAction.remove:
        await _confirmRemove(context, ref, favorite);
        return;
      case null:
        return;
    }
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _typeFilter = 'all';
      _regionFilter = 'all';
      _selectedIds = {};
      _page = 1;
    });
  }

  void _toggleFavoriteSelection(int id) {
    setState(() {
      final next = Set<int>.from(_selectedIds);
      if (next.contains(id)) {
        next.remove(id);
      } else {
        next.add(id);
      }
      _selectedIds = next;
    });
  }

  void _selectAllVisible(List<PoiFavorite> favorites) {
    setState(
      () => _selectedIds = favorites.map((favorite) => favorite.id).toSet(),
    );
  }

  void _clearSelection() {
    setState(() => _selectedIds = {});
  }

  Future<void> _confirmDeleteSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('確定刪除收藏？'),
        content: Text('即將刪除 ${ids.length} 個收藏景點，此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingSelected = true);
    final repository = ref.read(favoritesRepositoryProvider);
    final results = await Future.wait(
      ids.map(
        (id) => repository
            .deleteFavorite(id)
            .then((_) => true)
            .catchError((_) => false),
      ),
    );
    final failed = results.where((ok) => !ok).length;

    ref.invalidate(favoritesProvider);
    if (!mounted) return;
    setState(() {
      _selectedIds = {};
      _deletingSelected = false;
    });

    final message = failed == 0
        ? '已刪除 ${ids.length} 個收藏'
        : failed < ids.length
        ? '已刪除 ${ids.length - failed} 個，$failed 個失敗'
        : '刪除失敗，請稍後再試';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    PoiFavorite favorite,
  ) async {
    final confirmed = await showAppConfirm(
      context,
      title: '取消收藏',
      message: '確定要移除「${favorite.displayName}」嗎?',
      confirmLabel: '移除',
      cancelLabel: '保留',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(favoritesRepositoryProvider).deleteFavorite(favorite.id);
      ref.invalidate(favoritesProvider);
      HapticFeedback.selectionClick();
    } on Exception {
      if (!context.mounted) return;
      showAppNotice(context, '取消收藏失敗，請稍後再試');
    }
  }
}

class _FavoritesFilterForm extends StatefulWidget {
  const _FavoritesFilterForm({
    required this.controller,
    required this.initialType,
    required this.initialRegion,
    required this.regionCounts,
    required this.regionOptions,
    required this.onApply,
  });

  final AppSheetFormController controller;
  final String initialType;
  final String initialRegion;
  final Map<String, int> regionCounts;
  final List<String> regionOptions;
  final Future<bool> Function(String type, String region) onApply;

  @override
  State<_FavoritesFilterForm> createState() => _FavoritesFilterFormState();
}

class _FavoritesFilterFormState extends State<_FavoritesFilterForm> {
  late String _pendingType;
  late String _pendingRegion;

  @override
  void initState() {
    super.initState();
    _pendingType = widget.initialType;
    _pendingRegion = widget.initialRegion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.attach(_apply);
      _syncFormState();
    });
  }

  Future<bool> _apply() => widget.onApply(_pendingType, _pendingRegion);

  void _syncFormState() {
    widget.controller.update(
      dirty:
          _pendingType != widget.initialType ||
          _pendingRegion != widget.initialRegion,
      canSubmit: true,
    );
  }

  void _select({String? type, String? region}) {
    setState(() {
      _pendingType = type ?? _pendingType;
      _pendingRegion = region ?? _pendingRegion;
    });
    _syncFormState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(TpSpacing.s4),
        children: [
          Text('類型', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: TpSpacing.s2),
          Wrap(
            spacing: TpSpacing.s2,
            runSpacing: TpSpacing.s2,
            children: [
              for (final option in _typeFilterOptions)
                FilterChip(
                  key: ValueKey('favorites-type-${option.key}'),
                  label: Text(option.label),
                  selected: _pendingType == option.key,
                  onSelected: (_) => _select(type: option.key),
                ),
            ],
          ),
          if (widget.regionOptions.isNotEmpty) ...[
            const SizedBox(height: TpSpacing.s5),
            Text('地區', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: TpSpacing.s2),
            Wrap(
              spacing: TpSpacing.s2,
              runSpacing: TpSpacing.s2,
              children: [
                FilterChip(
                  key: const ValueKey('favorites-region-all'),
                  label: Text('全部 ${widget.regionCounts['all'] ?? 0}'),
                  selected: _pendingRegion == 'all',
                  onSelected: (_) => _select(region: 'all'),
                ),
                for (final region in widget.regionOptions)
                  FilterChip(
                    key: ValueKey('favorites-region-$region'),
                    label: Text('$region ${widget.regionCounts[region] ?? 0}'),
                    selected: _pendingRegion == region,
                    onSelected: (_) => _select(region: region),
                  ),
              ],
            ),
          ],
          const SizedBox(height: TpSpacing.s5),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('favorites-filter-reset'),
              onPressed: () => _select(type: 'all', region: 'all'),
              child: const Text('重設'),
            ),
          ),
        ],
      ),
    );
  }
}

List<PoiFavorite> _filterFavorites(
  List<PoiFavorite> favorites,
  String rawQuery,
  String typeFilter,
  String regionFilter,
) {
  final query = rawQuery.trim().toLowerCase();

  return favorites.where((favorite) {
    if (typeFilter != 'all' &&
        mapGooglePrimaryTypeToPoiType(favorite.poiType) != typeFilter) {
      return false;
    }
    if (regionFilter != 'all' &&
        _deriveRegion(favorite.poiAddress) != regionFilter) {
      return false;
    }
    if (query.isEmpty) return true;

    final haystack = [
      favorite.displayName,
      favorite.poiAddress,
      favorite.note,
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(query);
  }).toList();
}

Map<String, int> _regionCountsFor(List<PoiFavorite> favorites) {
  final counts = <String, int>{'all': favorites.length};
  for (final favorite in favorites) {
    final region = _deriveRegion(favorite.poiAddress);
    counts[region] = (counts[region] ?? 0) + 1;
  }
  return counts;
}

List<String> _regionOptionsFor(Map<String, int> counts) {
  final options = counts.keys.where((key) => key != 'all').toList();
  options.sort((a, b) {
    final byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
    if (byCount != 0) return byCount;
    return a.compareTo(b);
  });
  return options;
}

String _deriveRegion(String? address) {
  if (address == null || address.isEmpty) return '其他';
  for (final rule in _regionRules) {
    if (rule.key.hasMatch(address)) return rule.value;
  }
  return '其他';
}

class _TypeFilterOption {
  const _TypeFilterOption({required this.key, required this.label});

  final String key;
  final String label;
}

enum _FavoriteContextAction { addToTrip, select, remove }

class _BulkToolbar extends StatelessWidget {
  const _BulkToolbar({
    required this.selectedCount,
    required this.deleting,
    required this.onSelectAll,
    required this.onClear,
    required this.onDelete,
  });

  final int selectedCount;
  final bool deleting;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key: const ValueKey('favorites-toolbar'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TpRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Wrap(
          spacing: TpSpacing.s2,
          runSpacing: TpSpacing.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TpSpacing.s2),
              child: Text('已選 $selectedCount 個'),
            ),
            TextButton(
              key: const ValueKey('favorites-select-all'),
              onPressed: deleting ? null : onSelectAll,
              child: const Text('全選'),
            ),
            TextButton(
              key: const ValueKey('favorites-clear-selection'),
              onPressed: deleting ? null : onClear,
              child: const Text('取消'),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('favorites-delete-selected'),
              onPressed: deleting ? null : onDelete,
              icon: deleting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(deleting ? '刪除中' : '刪除'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.page,
    required this.totalPages,
    required this.start,
    required this.end,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int start;
  final int end;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('favorites-pagination'),
      padding: const EdgeInsets.only(top: TpSpacing.s2),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('favorites-page-prev'),
            tooltip: '上一頁',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$start-$end / $total'),
                Text('第 $page / $totalPages 頁'),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('favorites-page-next'),
            tooltip: '下一頁',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResult extends StatelessWidget {
  const _NoSearchResult({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TpSpacing.s6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('目前的篩選沒有符合的收藏', style: theme.textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s3),
            TextButton(
              key: const ValueKey('favorites-search-no-match-clear'),
              onPressed: onClear,
              child: const Text('清除篩選'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空清單 hero 文案。
class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('還沒有收藏的地點', style: theme.textTheme.titleLarge),
          const SizedBox(height: TpSpacing.s2),
          Text(
            '探索並收藏喜歡的地點。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TpSpacing.s4),
          FilledButton.tonalIcon(
            key: const ValueKey('favorites-empty-explore'),
            onPressed: () => context.go('/favorites/explore'),
            icon: const Icon(CupertinoIcons.search),
            label: const Text('去探索'),
          ),
        ],
      ),
    );
  }
}

/// 載入失敗：文案 + 重試。
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
            '無法取得收藏清單，請檢查網路後再試一次。',
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
