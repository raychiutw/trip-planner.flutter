import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/adaptive_content.dart';
import '../../../app/app_feedback.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../models/add_to_trip.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_action_item.dart';
import '../../../ui/tp_app_bar.dart';
import 'explore_controller.dart';
import 'poi_search_card.dart';

const List<String> _popularRegions = ['全部地區', '沖繩', '東京', '京都', '首爾', '台北'];
const String _kCustomRegion = '__custom__';

/// 探索畫面：搜尋 POI + region/分類 filter + heart 收藏 toggle。
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final savedState = ref.read(exploreControllerProvider);
    _searchController = TextEditingController(text: savedState.query);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(exploreControllerProvider.notifier);
      await controller.ensureSavedLoaded();
      final state = ref.read(exploreControllerProvider);
      if (!state.hasSearched) {
        await controller.search(state.region != '全部地區' ? state.region : '東京');
      }
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

  void _searchAsTyped(String _) {
    ref.read(exploreControllerProvider.notifier).search(_searchController.text);
  }

  Future<void> _openCustomRegion() async {
    final textController = TextEditingController();
    final formController = AppSheetFormController()
      ..attach(() async => true)
      ..update(canSubmit: true);
    try {
      final submitted = await showAppFormSheet(
        context,
        title: '自訂地區',
        submitLabel: '切換',
        controller: formController,
        builder: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(TpSpacing.s4),
          child: TextField(
            key: const ValueKey('explore-custom-region-field'),
            controller: textController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: '地區名稱',
              hintText: '例如：大阪、曼谷、巴黎',
            ),
            onChanged: (_) => formController.update(dirty: true),
            onSubmitted: (_) => formController.submit(),
          ),
        ),
      );
      if (submitted ?? false) {
        final region = textController.text.trim();
        ref
            .read(exploreControllerProvider.notifier)
            .setRegion(region.isEmpty ? '全部地區' : region);
      }
    } finally {
      textController.dispose();
      formController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exploreControllerProvider);
    final categories = state.fineCategories;
    final inlineCategories = categories.take(4).toList();
    final overflowCategories = categories.skip(4).toList();
    final selectedOverflow = overflowCategories
        .where((category) => category.label == state.category)
        .firstOrNull;

    ref.listen(exploreControllerProvider.select((s) => s.errorMessage), (
      prev,
      next,
    ) {
      if (next != null && next != prev) {
        showAppError(
          context,
          next,
          onRetry: () => ref
              .read(exploreControllerProvider.notifier)
              .search(ref.read(exploreControllerProvider).query),
        );
      }
    });

    return Scaffold(
      appBar: const TpAppBar(role: TpAppBarRole.detail, title: Text('探索')),
      body: AppAdaptiveContent(
        maxWidth: AppContentWidth.conversation,
        contentKey: const ValueKey('explore-content'),
        child: Column(
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
              child: Column(
                children: [
                  AppSearchField(
                    fieldKey: const ValueKey('explore-search-field'),
                    controller: _searchController,
                    placeholder: '搜尋地點',
                    debounce: const Duration(milliseconds: 300),
                    onChanged: _searchAsTyped,
                    onSubmitted: (_) => _submitSearch(),
                  ),
                  if (state.searching) ...[
                    const SizedBox(height: TpSpacing.s1),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: TpSpacing.tapMin,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
                itemCount:
                    1 +
                    inlineCategories.length +
                    (overflowCategories.isEmpty ? 0 : 1),
                separatorBuilder: (_, _) => const SizedBox(width: TpSpacing.s2),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _categoryChip(
                      key: const ValueKey('explore-category-all'),
                      label: '為你推薦',
                      count: state.results.length,
                      selected: state.category == 'all',
                      onSelected: () => ref
                          .read(exploreControllerProvider.notifier)
                          .setCategory('all'),
                    );
                  }
                  if (index <= inlineCategories.length) {
                    final category = inlineCategories[index - 1];
                    return _categoryChip(
                      key: ValueKey('explore-category-${category.label}'),
                      label: category.label,
                      count: category.count,
                      selected: state.category == category.label,
                      onSelected: () => ref
                          .read(exploreControllerProvider.notifier)
                          .setCategory(category.label),
                    );
                  }
                  return _categoryChip(
                    key: const ValueKey('explore-more-categories'),
                    label: selectedOverflow?.label ?? '更多',
                    count: selectedOverflow?.count,
                    selected: selectedOverflow != null,
                    onSelected: () => _openMoreCategories(overflowCategories),
                  );
                },
              ),
            ),
            Expanded(child: _buildBody(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip({
    required Key key,
    required String label,
    required int? count,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final theme = Theme.of(context);
    return ChoiceChip(
      key: key,
      label: Text(count == null ? label : '$label  $count'),
      selected: selected,
      showCheckmark: false,
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      selectedColor: theme.colorScheme.primaryContainer,
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
      ),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      ),
      onSelected: (_) => onSelected(),
    );
  }

  Future<void> _openMoreCategories(List<ExploreCategory> categories) async {
    final selected = await showAppActionSheet<String>(
      context,
      title: '更多分類',
      actions: [
        for (final category in categories)
          TpActionItem(
            label: '${category.label}  ${category.count}',
            value: category.label,
            icon: CupertinoIcons.tag,
          ),
      ],
    );
    if (selected == null || !mounted) return;
    ref.read(exploreControllerProvider.notifier).setCategory(selected);
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
        return const AppListLoadingSkeleton(key: ValueKey('explore-loading'));
      }
      if (state.query.trim().length >= 2 && state.hasSearched) {
        return Center(
          child: Text(
            '沒有找到「${state.query}」的結果。換個關鍵字試試?',
            style: theme.textTheme.bodyMedium,
          ),
        );
      }
      return const Center(child: Text('輸入至少 2 個字開始搜尋'));
    }

    final filtered = state.filteredResults;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '沒有符合「${state.activeCategoryLabel}」的結果。試試其他分類或回到「為你推薦」。',
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

    return SingleChildScrollView(
      key: const ValueKey('explore-results-list'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(TpSpacing.s4),
      child: Column(
        children: [
          for (var index = 0; index < filtered.length; index++) ...[
            if (index > 0) const SizedBox(height: TpSpacing.s3),
            PoiSearchCard(
              poi: filtered[index],
              isSaved: state.isSaved(filtered[index]),
              isSaving: state.savingPlaceIds.contains(filtered[index].placeId),
              onToggleFavorite: () {
                HapticFeedback.selectionClick();
                ref
                    .read(exploreControllerProvider.notifier)
                    .toggleFavorite(filtered[index]);
              },
              onAddToTrip: () => context.go(
                '/favorites/add-to-trip',
                extra: AddToTripDirect(poi: filtered[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
