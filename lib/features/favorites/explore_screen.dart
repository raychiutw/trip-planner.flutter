/// POI 探索頁：搜尋景點並加入收藏池。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/poi.dart';
import '../../theme/tokens.dart';
import 'favorites_screen.dart';

/// `/explore` secondary route。
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _queryController = TextEditingController();
  AsyncValue<List<PoiSearchResult>>? _searchState;
  final Set<String> _savingPlaceIds = {};
  String _region = '沖繩';

  static const _regions = ['沖繩', '東京', '京都', '大阪', '全部地區'];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(poiFavoritesProvider).value ?? const [];
    final favoriteByKey = <String, PoiFavorite>{
      for (final favorite in favorites)
        if (favorite.poiName != null)
          poiFavoriteKey(name: favorite.poiName!, type: favorite.poiType):
              favorite,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('探索景點')),
      body: ListView(
        padding: const EdgeInsets.all(TpSpacing.s4),
        children: [
          _SearchBox(
            controller: _queryController,
            region: _region,
            regions: _regions,
            onRegionChanged: (region) => setState(() => _region = region),
            onSearch: _runSearch,
          ),
          const SizedBox(height: TpSpacing.s4),
          _buildSearchBody(favoriteByKey),
        ],
      ),
    );
  }

  Widget _buildSearchBody(Map<String, PoiFavorite> favoriteByKey) {
    final searchState = _searchState;
    if (searchState == null) return const _ExploreLanding();

    return searchState.when(
      data: (results) {
        if (results.isEmpty) return const _ExploreEmptyResult();
        return Column(
          children: [
            for (var index = 0; index < results.length; index++) ...[
              _SearchResultCard(
                result: results[index],
                favorite:
                    favoriteByKey[poiFavoriteKey(
                      name: results[index].name,
                      type: results[index].category,
                    )],
                isSaving: _savingPlaceIds.contains(results[index].placeId),
                onToggleFavorite: () => _toggleFavorite(
                  results[index],
                  favoriteByKey[poiFavoriteKey(
                    name: results[index].name,
                    type: results[index].category,
                  )],
                ),
                onAddToTrip: () => _openAddToTrip(results[index]),
              ),
              if (index != results.length - 1)
                const SizedBox(height: TpSpacing.s3),
            ],
          ],
        );
      },
      error: (error, stackTrace) => _ExploreErrorState(onRetry: _runSearch),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(TpSpacing.s8),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Future<void> _runSearch() async {
    final query = _queryController.text.trim();
    if (query.length < 2) {
      setState(() {
        _searchState = AsyncError(
          ArgumentError('query too short'),
          StackTrace.current,
        );
      });
      return;
    }

    setState(() {
      _searchState = const AsyncLoading();
    });

    final region = _region == '全部地區' ? null : _region;
    final nextState = await AsyncValue.guard(
      () => ref
          .read(tripRepositoryProvider)
          .searchPois(query: query, region: region, limit: 20),
    );
    if (!mounted) return;
    setState(() {
      _searchState = nextState;
    });
  }

  Future<void> _toggleFavorite(
    PoiSearchResult result,
    PoiFavorite? favorite,
  ) async {
    setState(() => _savingPlaceIds.add(result.placeId));
    try {
      final repository = ref.read(tripRepositoryProvider);
      if (favorite != null) {
        await repository.deletePoiFavorite(favorite.id);
      } else {
        final poiId = await repository.findOrCreatePoi(result);
        await repository.createPoiFavorite(poiId: poiId);
      }
      ref.invalidate(poiFavoritesProvider);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('收藏更新失敗，請稍後再試')));
    } finally {
      if (mounted) {
        setState(() => _savingPlaceIds.remove(result.placeId));
      }
    }
  }

  void _openAddToTrip(PoiSearchResult result) {
    context.go(
      Uri(
        path: '/add-to-trip',
        queryParameters: _addToTripQueryParameters(result),
      ).toString(),
    );
  }
}

Map<String, String> _addToTripQueryParameters(PoiSearchResult result) {
  return {
    'place_id': result.placeId,
    'name': result.name,
    'lat': '${result.lat}',
    'lng': '${result.lng}',
    if (result.address != null && result.address!.trim().isNotEmpty)
      'address': result.address!,
    if (result.category != null && result.category!.trim().isNotEmpty)
      'category': result.category!,
    if (result.country != null && result.country!.trim().isNotEmpty)
      'country': result.country!,
    if (result.countryName != null && result.countryName!.trim().isNotEmpty)
      'country_name': result.countryName!,
    if (result.rating != null) 'rating': '${result.rating}',
    if (result.businessStatus != null &&
        result.businessStatus!.trim().isNotEmpty)
      'business_status': result.businessStatus!,
  };
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.region,
    required this.regions,
    required this.onRegionChanged,
    required this.onSearch,
  });

  final TextEditingController controller;
  final String region;
  final List<String> regions;
  final ValueChanged<String> onRegionChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: region,
          decoration: const InputDecoration(
            labelText: '地區',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final region in regions)
              DropdownMenuItem(value: region, child: Text(region)),
          ],
          onChanged: (value) {
            if (value != null) onRegionChanged(value);
          },
        ),
        const SizedBox(height: TpSpacing.s3),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '搜尋景點',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: '搜尋',
              icon: const Icon(Icons.search),
              onPressed: onSearch,
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearch(),
        ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.favorite,
    required this.isSaving,
    required this.onToggleFavorite,
    required this.onAddToTrip,
  });

  final PoiSearchResult result;
  final PoiFavorite? favorite;
  final bool isSaving;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToTrip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final isFavorited = favorite != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: TpSpacing.s1),
                  Wrap(
                    spacing: TpSpacing.s2,
                    runSpacing: TpSpacing.s1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(poiTypeLabel(result.category), style: metaStyle),
                      if (result.rating != null)
                        _ResultRating(rating: result.rating!),
                      if (result.businessStatus != null)
                        Text(result.businessStatus!, style: metaStyle),
                    ],
                  ),
                  if (result.address != null &&
                      result.address!.trim().isNotEmpty) ...[
                    const SizedBox(height: TpSpacing.s2),
                    Text(result.address!, style: metaStyle),
                  ],
                  const SizedBox(height: TpSpacing.s3),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('加入行程'),
                      onPressed: onAddToTrip,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            isSaving
                ? const SizedBox.square(
                    dimension: TpSpacing.tapMin,
                    child: Padding(
                      padding: EdgeInsets.all(TpSpacing.s3),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: isFavorited ? '取消收藏' : '加入收藏',
                    icon: Icon(
                      isFavorited ? Icons.favorite : Icons.favorite_border,
                    ),
                    color: isFavorited
                        ? colorScheme.primary
                        : colorScheme.outline,
                    onPressed: onToggleFavorite,
                  ),
          ],
        ),
      ),
    );
  }
}

class _ResultRating extends StatelessWidget {
  const _ResultRating({required this.rating});

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

class _ExploreLanding extends StatelessWidget {
  const _ExploreLanding();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TpSpacing.s8),
      child: Column(
        children: [
          Text('搜尋想去的景點', style: theme.textTheme.titleLarge),
          const SizedBox(height: TpSpacing.s2),
          Text(
            '找到地點後可先加入收藏，再從收藏排進行程。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreEmptyResult extends StatelessWidget {
  const _ExploreEmptyResult();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TpSpacing.s8),
      child: Text(
        '找不到符合的景點',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium,
      ),
    );
  }
}

class _ExploreErrorState extends StatelessWidget {
  const _ExploreErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TpSpacing.s8),
      child: Column(
        children: [
          Text('搜尋失敗', style: theme.textTheme.titleMedium),
          const SizedBox(height: TpSpacing.s2),
          Text(
            '請確認至少輸入 2 個字，或稍後再試。',
            textAlign: TextAlign.center,
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
