import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/add_to_trip.dart';
import '../../models/poi_favorite.dart';
import '../../models/poi_type.dart';
import '../../theme/tokens.dart';
import 'favorites_providers.dart';
import 'poi_favorite_card.dart';

const _typeFilterOptions = [
  _TypeFilterOption(key: 'all', label: '全部'),
  _TypeFilterOption(key: 'restaurant', label: '餐廳'),
  _TypeFilterOption(key: 'attraction', label: '景點'),
  _TypeFilterOption(key: 'shopping', label: '購物'),
  _TypeFilterOption(key: 'hotel', label: '住宿'),
];

/// 收藏清單（5-tab「收藏」分頁）：GET /poi-favorites，heart 取消收藏（確認對話框）。
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏'),
        actions: [
          IconButton(
            key: const ValueKey('favorites-explore-action'),
            tooltip: '探索',
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/favorites/explore'),
          ),
        ],
      ),
      body: favoritesAsync.when(
        data: (favorites) => RefreshIndicator(
          onRefresh: () => ref.refresh(favoritesProvider.future),
          child: favorites.isEmpty
              ? const _EmptyHero()
              : _buildList(context, favorites),
        ),
        error: (error, stackTrace) =>
            _ErrorState(onRetry: () => ref.invalidate(favoritesProvider)),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<PoiFavorite> favorites) {
    final filteredFavorites = _filterFavorites(
      favorites,
      _searchQuery,
      _typeFilter,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        _SearchField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          onClear: _searchQuery.trim().isEmpty ? null : _clearSearch,
        ),
        const SizedBox(height: TpSpacing.s3),
        _TypeFilterRow(
          selected: _typeFilter,
          onSelected: (value) => setState(() => _typeFilter = value),
        ),
        const SizedBox(height: TpSpacing.s3),
        if (filteredFavorites.isEmpty)
          _NoSearchResult(onClear: _clearAllFilters)
        else
          for (final favorite in filteredFavorites) ...[
            PoiFavoriteCard(
              favorite: favorite,
              onRemove: () => _confirmRemove(context, ref, favorite),
              onAddToTrip: () => context.go(
                '/favorites/add-to-trip',
                extra: AddToTripFavorite(
                  favoriteId: favorite.id,
                  displayName: favorite.displayName,
                ),
              ),
            ),
            const SizedBox(height: TpSpacing.s3),
          ],
      ],
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _typeFilter = 'all';
    });
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    PoiFavorite favorite,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('取消收藏'),
        content: Text('確定要移除「${favorite.displayName}」嗎?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(favoritesRepositoryProvider).deleteFavorite(favorite.id);
      ref.invalidate(favoritesProvider);
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('取消收藏失敗，請稍後再試')));
    }
  }
}

List<PoiFavorite> _filterFavorites(
  List<PoiFavorite> favorites,
  String rawQuery,
  String typeFilter,
) {
  final query = rawQuery.trim().toLowerCase();

  return favorites.where((favorite) {
    if (typeFilter != 'all' &&
        mapGooglePrimaryTypeToPoiType(favorite.poiType) != typeFilter) {
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

class _TypeFilterOption {
  const _TypeFilterOption({required this.key, required this.label});

  final String key;
  final String label;
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('favorites-search-input'),
      controller: controller,
      decoration: InputDecoration(
        labelText: '搜尋收藏',
        hintText: '名稱 / 地址 / 備註',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                key: const ValueKey('favorites-search-clear'),
                tooltip: '清除搜尋',
                icon: const Icon(Icons.close),
                onPressed: onClear,
              ),
        border: const OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
    );
  }
}

class _TypeFilterRow extends StatelessWidget {
  const _TypeFilterRow({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TpSpacing.s2,
      runSpacing: TpSpacing.s2,
      children: [
        for (final option in _typeFilterOptions)
          FilterChip(
            key: ValueKey('favorites-type-${option.key}'),
            label: Text(option.label),
            selected: selected == option.key,
            onSelected: (_) => onSelected(option.key),
          ),
      ],
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
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
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
                  icon: const Icon(Icons.search),
                  label: const Text('去探索'),
                ),
              ],
            ),
          ),
        ),
      ],
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
