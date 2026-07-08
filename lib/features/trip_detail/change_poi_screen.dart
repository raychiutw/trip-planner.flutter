/// 置換 entry master POI / 加入備選 POI 的表單。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../api/trip_repository.dart';
import '../../models/entry.dart';
import '../../models/poi.dart';
import '../../theme/tokens.dart';
import '../favorites/favorites_screen.dart';
import 'trip_providers.dart';

enum ChangePoiMode { master, alternate }

class ChangePoiScreen extends ConsumerStatefulWidget {
  const ChangePoiScreen({
    super.key,
    required this.tripId,
    required this.entryId,
    this.mode = ChangePoiMode.master,
  });

  final String tripId;
  final int entryId;
  final ChangePoiMode mode;

  @override
  ConsumerState<ChangePoiScreen> createState() => _ChangePoiScreenState();
}

class _ChangePoiScreenState extends ConsumerState<ChangePoiScreen> {
  final _queryController = TextEditingController();
  AsyncValue<List<PoiSearchResult>>? _searchState;
  String _source = 'search';
  String? _submittingKey;
  String? _submitError;

  bool get _isAlternate => widget.mode == ChangePoiMode.alternate;
  String get _title => _isAlternate ? '加入備選景點' : '置換景點';
  String get _submitLabel => _isAlternate ? '加為備選' : '置換景點';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = (tripId: widget.tripId, entryId: widget.entryId);
    final entryAsync = ref.watch(entryDetailProvider(args));

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: entryAsync.when(
        data: _buildForm,
        error: (error, stackTrace) => _LoadErrorState(
          message: '無法取得景點資料',
          onRetry: () => ref.invalidate(entryDetailProvider(args)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildForm(TimelineEntry entry) {
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        _CurrentEntryCard(entry: entry),
        const SizedBox(height: TpSpacing.s4),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'search',
              icon: Icon(Icons.search),
              label: Text('搜尋'),
            ),
            ButtonSegment(
              value: 'favorites',
              icon: Icon(Icons.favorite_border),
              label: Text('收藏'),
            ),
          ],
          selected: {_source},
          onSelectionChanged: _submittingKey == null
              ? (selection) => setState(() {
                  _source = selection.single;
                  _submitError = null;
                })
              : null,
        ),
        if (_submitError != null) ...[
          const SizedBox(height: TpSpacing.s3),
          _InlineError(message: _submitError!),
        ],
        const SizedBox(height: TpSpacing.s4),
        if (_source == 'search')
          _buildSearchTab(entry)
        else
          _buildFavoritesTab(entry),
      ],
    );
  }

  Widget _buildSearchTab(TimelineEntry entry) {
    final searchState = _searchState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('change-poi-search-input'),
                controller: _queryController,
                decoration: const InputDecoration(
                  labelText: '搜尋景點',
                  border: OutlineInputBorder(),
                ),
                enabled: _submittingKey == null,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            IconButton.filledTonal(
              tooltip: '搜尋',
              icon: const Icon(Icons.search),
              onPressed: _submittingKey == null ? _runSearch : null,
            ),
          ],
        ),
        const SizedBox(height: TpSpacing.s4),
        if (searchState == null)
          Text(
            _isAlternate ? '搜尋後選一個景點加為備選' : '搜尋後選一個景點置換目前主景點',
            textAlign: TextAlign.center,
          )
        else
          searchState.when(
            data: (results) {
              if (results.isEmpty) {
                return const _CenteredMessage(message: '找不到符合的景點');
              }
              return Column(
                children: [
                  for (var index = 0; index < results.length; index++) ...[
                    _PoiSearchResultCard(
                      result: results[index],
                      submitLabel: _submitLabel,
                      isSubmitting:
                          _submittingKey == 'search:${results[index].placeId}',
                      onSubmit: () =>
                          _submitSearchResult(entry, results[index]),
                    ),
                    if (index != results.length - 1)
                      const SizedBox(height: TpSpacing.s3),
                  ],
                ],
              );
            },
            error: (error, stackTrace) =>
                const _CenteredMessage(message: '搜尋失敗，請確認至少輸入 2 個字'),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(TpSpacing.s6),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFavoritesTab(TimelineEntry entry) {
    return ref
        .watch(poiFavoritesProvider)
        .when(
          data: (favorites) {
            if (favorites.isEmpty) {
              return const _CenteredMessage(message: '還沒有收藏景點');
            }
            return Column(
              children: [
                for (var index = 0; index < favorites.length; index++) ...[
                  _PoiFavoriteCard(
                    favorite: favorites[index],
                    submitLabel: _submitLabel,
                    isSubmitting:
                        _submittingKey == 'favorite:${favorites[index].id}',
                    onSubmit: () => _submitFavorite(entry, favorites[index]),
                  ),
                  if (index != favorites.length - 1)
                    const SizedBox(height: TpSpacing.s3),
                ],
              ],
            );
          },
          error: (error, stackTrace) => _LoadErrorState(
            message: '無法取得收藏資料',
            onRetry: () => ref.invalidate(poiFavoritesProvider),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
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
      _submitError = null;
    });
    final nextState = await AsyncValue.guard(
      () => ref
          .read(tripRepositoryProvider)
          .searchPois(query: query, region: null, limit: 20),
    );
    if (!mounted) return;
    setState(() => _searchState = nextState);
  }

  Future<void> _submitSearchResult(
    TimelineEntry entry,
    PoiSearchResult result,
  ) async {
    setState(() {
      _submittingKey = 'search:${result.placeId}';
      _submitError = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      if (_isAlternate) {
        await repository.addEntryAlternateFromSearchResult(
          tripId: widget.tripId,
          entryId: widget.entryId,
          poi: result,
          entryPoisVersion: entry.entryPoisVersion,
        );
        _afterAlternateMutation();
      } else {
        await repository.replaceEntryMasterPoiFromSearchResult(
          tripId: widget.tripId,
          entryId: widget.entryId,
          poi: result,
          entryPoisVersion: entry.entryPoisVersion,
        );
        _afterMasterMutation(repository);
      }
    } on ApiError catch (error) {
      _showSubmitError(error);
    } on Exception {
      _showSubmitError(null);
    } finally {
      if (mounted) setState(() => _submittingKey = null);
    }
  }

  Future<void> _submitFavorite(
    TimelineEntry entry,
    PoiFavorite favorite,
  ) async {
    setState(() {
      _submittingKey = 'favorite:${favorite.id}';
      _submitError = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      if (_isAlternate) {
        await repository.addEntryAlternateWithPoiId(
          tripId: widget.tripId,
          entryId: widget.entryId,
          poiId: favorite.poiId,
          entryPoisVersion: entry.entryPoisVersion,
        );
        _afterAlternateMutation();
      } else {
        await repository.replaceEntryMasterPoiWithPoiId(
          tripId: widget.tripId,
          entryId: widget.entryId,
          poiId: favorite.poiId,
          entryPoisVersion: entry.entryPoisVersion,
        );
        _afterMasterMutation(repository);
      }
    } on ApiError catch (error) {
      _showSubmitError(error);
    } on Exception {
      _showSubmitError(null);
    } finally {
      if (mounted) setState(() => _submittingKey = null);
    }
  }

  void _afterMasterMutation(TripRepository repository) {
    _invalidateEntryAndDays();
    unawaited(
      repository.recomputeTravel(widget.tripId).catchError((Object _) {}),
    );
    if (mounted) context.go('/trips/${widget.tripId}');
  }

  void _afterAlternateMutation() {
    _invalidateEntryAndDays();
    if (mounted) {
      context.go('/trips/${widget.tripId}/stop/${widget.entryId}/edit');
    }
  }

  void _invalidateEntryAndDays() {
    ref.invalidate(
      entryDetailProvider((tripId: widget.tripId, entryId: widget.entryId)),
    );
    ref.invalidate(tripDaysProvider(widget.tripId));
  }

  void _showSubmitError(ApiError? error) {
    if (!mounted) return;
    setState(() {
      if (error?.code == 'STALE_ENTRY') {
        _submitError = '資料已被其他操作更新，請重新進入此頁';
      } else if (error?.code == 'DUPLICATE_POI') {
        _submitError = '此景點已存在於這個停留點';
      } else {
        _submitError = _isAlternate ? '加入備選失敗，請稍後再試' : '置換景點失敗，請稍後再試';
      }
    });
  }
}

class _CurrentEntryCard extends StatelessWidget {
  const _CurrentEntryCard({required this.entry});

  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final currentName = entry.master?.name ?? entry.title;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('目前：$currentName', style: theme.textTheme.titleMedium),
            if (entry.alternates.isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(
                '備選：${entry.alternates.map((poi) => poi.name ?? 'POI #${poi.poiId}').join('、')}',
                style: metaStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PoiSearchResultCard extends StatelessWidget {
  const _PoiSearchResultCard({
    required this.result,
    required this.submitLabel,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final PoiSearchResult result;
  final String submitLabel;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s1),
            Wrap(
              spacing: TpSpacing.s2,
              runSpacing: TpSpacing.s1,
              children: [
                Text(poiTypeLabel(result.category), style: metaStyle),
                if (result.rating != null)
                  Text(result.rating!.toStringAsFixed(1), style: metaStyle),
              ],
            ),
            if (result.address != null &&
                result.address!.trim().isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(result.address!, style: metaStyle),
            ],
            const SizedBox(height: TpSpacing.s3),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: ValueKey('change-poi-submit-search-${result.placeId}'),
                icon: isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.swap_horiz_outlined),
                label: Text(submitLabel),
                onPressed: isSubmitting ? null : onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoiFavoriteCard extends StatelessWidget {
  const _PoiFavoriteCard({
    required this.favorite,
    required this.submitLabel,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final PoiFavorite favorite;
  final String submitLabel;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(favorite.displayName, style: theme.textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s1),
            Wrap(
              spacing: TpSpacing.s2,
              runSpacing: TpSpacing.s1,
              children: [
                Text(poiTypeLabel(favorite.poiType), style: metaStyle),
                if (favorite.poiRating != null)
                  Text(
                    favorite.poiRating!.toStringAsFixed(1),
                    style: metaStyle,
                  ),
              ],
            ),
            if (favorite.poiAddress != null &&
                favorite.poiAddress!.trim().isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(favorite.poiAddress!, style: metaStyle),
            ],
            const SizedBox(height: TpSpacing.s3),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: ValueKey('change-poi-submit-favorite-${favorite.id}'),
                icon: isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite_border),
                label: Text(submitLabel),
                onPressed: isSubmitting ? null : onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: TpSpacing.s2),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: TpSpacing.s3),
          FilledButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s6),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
