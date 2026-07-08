/// 收藏 tab：列出使用者的 POI 收藏池。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/poi.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// `GET /poi-favorites` 收藏清單；取消收藏後 invalidate refresh。
final poiFavoritesProvider = FutureProvider<List<PoiFavorite>>((ref) {
  return ref.watch(tripRepositoryProvider).fetchPoiFavorites();
});

/// 收藏分頁。
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(poiFavoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏'),
        actions: [
          IconButton(
            tooltip: '探索景點',
            icon: const Icon(Icons.explore_outlined),
            onPressed: () => context.go('/explore'),
          ),
        ],
      ),
      body: favoritesAsync.when(
        data: (favorites) => RefreshIndicator(
          onRefresh: () => ref.refresh(poiFavoritesProvider.future),
          child: favorites.isEmpty
              ? const _FavoritesEmptyState()
              : _FavoritesList(favorites: favorites),
        ),
        error: (error, stackTrace) => _FavoritesErrorState(
          onRetry: () => ref.invalidate(poiFavoritesProvider),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _FavoritesList extends ConsumerWidget {
  const _FavoritesList({required this.favorites});

  final List<PoiFavorite> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(TpSpacing.s4),
      itemCount: favorites.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: TpSpacing.s3),
      itemBuilder: (context, index) => _FavoriteCard(
        favorite: favorites[index],
        onDelete: () => _deleteFavorite(context, ref, favorites[index]),
      ),
    );
  }

  Future<void> _deleteFavorite(
    BuildContext context,
    WidgetRef ref,
    PoiFavorite favorite,
  ) async {
    try {
      await ref.read(tripRepositoryProvider).deletePoiFavorite(favorite.id);
      ref.invalidate(poiFavoritesProvider);
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('取消收藏失敗，請稍後再試')));
    }
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.favorite, required this.onDelete});

  final PoiFavorite favorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metaTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        favorite.displayName,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: TpSpacing.s1),
                      Wrap(
                        spacing: TpSpacing.s2,
                        runSpacing: TpSpacing.s1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _TypeChip(type: favorite.poiType),
                          if (favorite.poiRating != null)
                            _RatingText(rating: favorite.poiRating!),
                          Text(_usageLabel(favorite), style: metaTextStyle),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '取消收藏',
                  icon: const Icon(Icons.favorite),
                  color: colorScheme.primary,
                  onPressed: onDelete,
                ),
              ],
            ),
            if (favorite.poiAddress != null &&
                favorite.poiAddress!.trim().isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(favorite.poiAddress!, style: metaTextStyle),
            ],
            if (favorite.note != null && favorite.note!.trim().isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(favorite.note!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: TpSpacing.s3),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('加入行程'),
                onPressed: () =>
                    context.go('/favorites/${favorite.id}/add-to-trip'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _usageLabel(PoiFavorite favorite) {
    final usageCount = favorite.usages.length;
    if (usageCount == 0) return '尚未排入行程';
    return '已排入 $usageCount 個行程';
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final String? type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final label = poiTypeLabel(type);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tones.accentSubtle,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TpSpacing.s2,
          vertical: TpSpacing.s1,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: tones.accentDeep),
        ),
      ),
    );
  }
}

class _RatingText extends StatelessWidget {
  const _RatingText({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: TpSpacing.s1),
        Text(
          rating.toStringAsFixed(1),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FavoritesEmptyState extends StatelessWidget {
  const _FavoritesEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(TpSpacing.s6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('還沒有收藏', style: theme.textTheme.titleLarge),
                  const SizedBox(height: TpSpacing.s2),
                  Text(
                    '先探索景點，再把想去的地方排進行程。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: TpSpacing.s4),
                  FilledButton.icon(
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('探索景點'),
                    onPressed: () => context.go('/explore'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FavoritesErrorState extends StatelessWidget {
  const _FavoritesErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('載入收藏失敗', style: theme.textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s2),
            Text(
              '無法取得收藏清單，請檢查網路後再試一次。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            FilledButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}
