import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/adaptive.dart';
import '../../models/add_to_trip.dart';
import '../../models/poi_favorite.dart';
import '../../theme/tokens.dart';
import 'favorites_providers.dart';
import 'poi_favorite_card.dart';

/// 收藏清單（5-tab「收藏」分頁）：GET /poi-favorites，heart 取消收藏（確認對話框）。
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(favoritesProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.large(
              pinned: true,
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
        ),
      ),
    );
  }

  List<Widget> _buildListSlivers(
    BuildContext context,
    WidgetRef ref,
    List<PoiFavorite> favorites,
  ) {
    return [
      SliverPadding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        sliver: SliverList.separated(
          itemCount: favorites.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: TpSpacing.s3),
          itemBuilder: (context, index) {
            final favorite = favorites[index];
            return PoiFavoriteCard(
              favorite: favorite,
              onRemove: () => _confirmRemove(context, ref, favorite),
              onAddToTrip: () => context.go(
                '/favorites/add-to-trip',
                extra: AddToTripFavorite(
                  favoriteId: favorite.id,
                  displayName: favorite.displayName,
                ),
              ),
            );
          },
        ),
      ),
    ];
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('取消收藏失敗，請稍後再試')));
    }
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
            icon: const Icon(Icons.search),
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
