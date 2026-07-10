import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../models/add_to_trip.dart';
import '../../../theme/tokens.dart';
import 'explore_controller.dart';
import 'poi_search_card.dart';

const List<String> _popularRegions = ['全部地區', '沖繩', '東京', '京都', '首爾', '台北'];
const List<(String, String)> _categoryChips = [
  ('all', '為你推薦'),
  ('attraction', '景點'),
  ('food', '美食'),
  ('hotel', '住宿'),
  ('shopping', '購物'),
];
final Map<String, String> _categoryLabels = {
  for (final (key, label) in _categoryChips) key: label,
};
const String _kCustomRegion = '__custom__';

/// 探索畫面：搜尋 POI + region/分類 filter + heart 收藏 toggle。
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(exploreControllerProvider.notifier);
      await controller.ensureSavedLoaded();
      final region = ref.read(exploreControllerProvider).region;
      await controller.search(region != '全部地區' ? region : '東京');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    ref.read(exploreControllerProvider.notifier).search(_searchController.text);
    FocusScope.of(context).unfocus();
  }

  Future<void> _openCustomRegion() async {
    final textController = TextEditingController();
    try {
      final result = await showAdaptiveDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog.adaptive(
          title: const Text('自訂地區'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '地區名稱',
              hintText: '例如:大阪、曼谷、巴黎',
            ),
            onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(textController.text),
              child: const Text('切換'),
            ),
          ],
        ),
      );
      if (result != null) {
        ref
            .read(exploreControllerProvider.notifier)
            .setRegion(result.trim().isEmpty ? '全部地區' : result.trim());
      }
    } finally {
      textController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exploreControllerProvider);

    ref.listen(exploreControllerProvider.select((s) => s.errorMessage), (
      prev,
      next,
    ) {
      if (next != null && next != prev) {
        showAppNotice(context, next);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('探索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TpSpacing.s4,
              TpSpacing.s2,
              TpSpacing.s4,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _regionPill(state.region),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TpSpacing.s4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('explore-search-field'),
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submitSearch(),
                    decoration: const InputDecoration(hintText: '搜尋地點'),
                  ),
                ),
                const SizedBox(width: TpSpacing.s2),
                FilledButton(
                  key: const ValueKey('explore-search-button'),
                  onPressed: state.searching ? null : _submitSearch,
                  child: Text(state.searching ? '搜尋中…' : '搜尋'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
              itemCount: _categoryChips.length,
              separatorBuilder: (_, _) => const SizedBox(width: TpSpacing.s2),
              itemBuilder: (context, index) {
                final (key, label) = _categoryChips[index];
                return ChoiceChip(
                  label: Text(label),
                  selected: state.category == key,
                  onSelected: (_) => ref
                      .read(exploreControllerProvider.notifier)
                      .setCategory(key),
                );
              },
            ),
          ),
          Expanded(child: _buildBody(context, state)),
        ],
      ),
    );
  }

  Widget _regionPill(String region) {
    final options = [..._popularRegions];
    if (region != '全部地區' && !options.contains(region)) {
      options.insert(1, region);
    }
    return PopupMenuButton<String>(
      onSelected: (selected) {
        if (selected == _kCustomRegion) {
          _openCustomRegion();
        } else {
          ref.read(exploreControllerProvider.notifier).setRegion(selected);
        }
      },
      itemBuilder: (context) => [
        for (final opt in options) PopupMenuItem(value: opt, child: Text(opt)),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _kCustomRegion, child: Text('+ 自訂地區…')),
      ],
      child: Chip(
        avatar: const Icon(CupertinoIcons.location_solid, size: 16),
        label: Text('$region ▾'),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ExploreState state) {
    final theme = Theme.of(context);

    if (state.results.isEmpty) {
      if (state.searching) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }
      if (state.query.trim().length >= 2 && state.hasSearched) {
        return Center(
          child: Text(
            '沒有找到「${state.query}」的結果。換個關鍵字試試?',
            style: theme.textTheme.bodyMedium,
          ),
        );
      }
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final filtered = state.filteredResults;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '沒有符合「${_categoryLabels[state.category]}」的結果。試試其他分類或回到「為你推薦」。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: TpSpacing.s3),
            FilledButton(
              onPressed: () => ref
                  .read(exploreControllerProvider.notifier)
                  .setCategory('all'),
              child: const Text('回到為你推薦'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(TpSpacing.s4),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: TpSpacing.s3,
        crossAxisSpacing: TpSpacing.s3,
        childAspectRatio: 0.82,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final poi = filtered[index];
        return PoiSearchCard(
          poi: poi,
          isSaved: state.isSaved(poi),
          isSaving: state.savingPlaceIds.contains(poi.placeId),
          onToggleFavorite: () {
            HapticFeedback.selectionClick();
            ref.read(exploreControllerProvider.notifier).toggleFavorite(poi);
          },
          onAddToTrip: () => context.go(
            '/favorites/add-to-trip',
            extra: AddToTripDirect(poi: poi),
          ),
        );
      },
    );
  }
}
