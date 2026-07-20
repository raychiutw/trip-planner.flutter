import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_loading_skeleton.dart';
import '../../models/poi_favorite.dart';
import '../../models/day.dart';
import '../../models/poi_note.dart';
import '../../models/poi_search_result.dart';
import '../../models/poi_type.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';
import '../favorites/favorites_providers.dart';
import '../favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;
import 'trip_providers.dart';
import 'widgets/entry_edit_sheet.dart';

/// 新增停留點頁的初始模式。
enum EntryAddMode { search, favorites, custom }

enum _EntryAddCategory { all, attraction, food, hotel, shopping }

const _entryAddRegionOptions = ['全部地區', '沖繩', '東京', '京都', '首爾', '台北'];
const _entryAddCategoryChips = [
  (_EntryAddCategory.all, '為你推薦'),
  (_EntryAddCategory.attraction, '景點'),
  (_EntryAddCategory.food, '美食'),
  (_EntryAddCategory.hotel, '住宿'),
  (_EntryAddCategory.shopping, '購物'),
];

/// Web 相容的停留點新增頁，支援搜尋 POI 或新增自訂停留點。
class EntryAddRouteScreen extends ConsumerStatefulWidget {
  const EntryAddRouteScreen({
    super.key,
    required this.tripId,
    this.initialDayNum,
    this.initialMode = EntryAddMode.custom,
    this.initialRegion,
  });

  final String tripId;
  final int? initialDayNum;
  final EntryAddMode initialMode;

  /// 搜尋 POI 的初始地區；`null` 或空字串代表全部地區。
  final String? initialRegion;

  @override
  ConsumerState<EntryAddRouteScreen> createState() =>
      _EntryAddRouteScreenState();
}

class _EntryAddRouteScreenState extends ConsumerState<EntryAddRouteScreen> {
  final _dismissController = AppUnsavedChangesController();
  final _customFormController = AppSheetFormController();
  late EntryAddMode _mode;
  final _searchController = TextEditingController();
  int? _selectedDayNum;
  List<PoiSearchResult> _results = const [];
  bool _searching = false;
  int _searchRequest = 0;
  String? _searchError;
  final Set<String> _selectedPlaceIds = <String>{};
  final Map<String, String> _searchPoiTypeOverrides = <String, String>{};
  List<PoiFavorite> _favorites = const [];
  bool _favoritesLoaded = false;
  bool _favoritesLoading = false;
  String? _favoritesError;
  final Set<int> _selectedFavoriteIds = <int>{};
  bool _submittingSelected = false;
  bool _dirty = false;
  late String _region;
  _EntryAddCategory _category = _EntryAddCategory.all;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _region = _normaliseRegion(widget.initialRegion);
    if (_mode == EntryAddMode.favorites) {
      unawaited(_loadFavorites());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customFormController.dispose();
    super.dispose();
  }

  int _dayNumFor(List<TripDay> days) {
    final selected = _selectedDayNum ?? widget.initialDayNum;
    if (selected != null && days.any((day) => day.dayNum == selected)) {
      return selected;
    }
    return days.first.dayNum;
  }

  Future<void> _searchPois() async {
    final q = _searchController.text.trim();
    final request = ++_searchRequest;
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await ref
          .read(poiRepositoryProvider)
          .searchPois(q: q, limit: 20, region: _regionForSearch(_region));
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _results = results;
        _searching = false;
        _searchError = results.isEmpty ? '找不到符合的景點' : null;
      });
    } on Exception {
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _searching = false;
        _searchError = '搜尋失敗，請稍後再試';
      });
    }
  }

  Future<void> _loadFavorites({bool force = false}) async {
    if (_favoritesLoading || (_favoritesLoaded && !force)) return;
    setState(() {
      _favoritesLoading = true;
      _favoritesError = null;
    });
    try {
      final favorites = await ref
          .read(favoritesRepositoryProvider)
          .fetchFavorites();
      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _favoritesLoaded = true;
        _favoritesLoading = false;
        _favoritesError = null;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _favoritesLoading = false;
        _favoritesError = '載入收藏失敗，請稍後再試';
      });
    }
  }

  void _togglePoiSelection(PoiSearchResult poi) {
    setState(() {
      _dirty = true;
      if (_selectedPlaceIds.contains(poi.placeId)) {
        _selectedPlaceIds.remove(poi.placeId);
        _searchPoiTypeOverrides.remove(poi.placeId);
      } else {
        _selectedPlaceIds.add(poi.placeId);
      }
    });
  }

  void _toggleFavoriteSelection(PoiFavorite favorite) {
    setState(() {
      _dirty = true;
      if (_selectedFavoriteIds.contains(favorite.id)) {
        _selectedFavoriteIds.remove(favorite.id);
      } else {
        _selectedFavoriteIds.add(favorite.id);
      }
    });
  }

  int get _selectedCount => switch (_mode) {
    EntryAddMode.search => _selectedPlaceIds.length,
    EntryAddMode.favorites => _selectedFavoriteIds.length,
    EntryAddMode.custom => 0,
  };

  Future<void> _submitSelected(int dayNum) async {
    if (_submittingSelected) return;
    final selectedPois = _mode == EntryAddMode.search
        ? _results
              .where((poi) => _selectedPlaceIds.contains(poi.placeId))
              .toList(growable: false)
        : const <PoiSearchResult>[];
    final selectedFavorites = _mode == EntryAddMode.favorites
        ? _favorites
              .where((favorite) => _selectedFavoriteIds.contains(favorite.id))
              .toList(growable: false)
        : const <PoiFavorite>[];

    if (_mode == EntryAddMode.search && selectedPois.isEmpty) {
      setState(() => _searchError = '請先選擇要加入的景點');
      return;
    }
    if (_mode == EntryAddMode.favorites && selectedFavorites.isEmpty) {
      setState(() => _favoritesError = '請先選擇要加入的收藏');
      return;
    }

    setState(() {
      _submittingSelected = true;
      _searchError = null;
      _favoritesError = null;
    });
    try {
      final repo = ref.read(tripRepositoryProvider);
      if (_mode == EntryAddMode.search) {
        for (final poi in selectedPois) {
          final note = await _buildSearchPoiNote(poi);
          await repo.addEntryToDay(
            tripId: widget.tripId,
            dayNum: dayNum,
            title: poi.name,
            note: note,
            poiType:
                _searchPoiTypeOverrides[poi.placeId] ??
                mapGooglePrimaryTypeToPoiType(poi.category),
            lat: poi.lat,
            lng: poi.lng,
            source: 'google',
          );
        }
      } else {
        for (final favorite in selectedFavorites) {
          await repo.addEntryToDay(
            tripId: widget.tripId,
            dayNum: dayNum,
            title: favorite.displayName,
            note: favorite.poiAddress,
            poiType: mapGooglePrimaryTypeToPoiType(favorite.poiType),
            lat: favorite.poiLat,
            lng: favorite.poiLng,
            source: 'favorite',
          );
        }
      }
      ref.invalidate(tripDaysProvider(widget.tripId));
      if (!mounted) return;
      context.go('/trips/${Uri.encodeComponent(widget.tripId)}');
    } on Exception {
      if (!mounted) return;
      setState(() => _setSubmitError('加入行程失敗，請稍後再試'));
    } finally {
      if (mounted) {
        setState(() => _submittingSelected = false);
      }
    }
  }

  Future<void> _submitCurrent(int dayNum) async {
    if (_mode == EntryAddMode.custom) {
      if (await _customFormController.submit() && mounted) {
        _customFormController.update(dirty: false);
        context.go('/trips/${Uri.encodeComponent(widget.tripId)}');
      }
      return;
    }
    await _submitSelected(dayNum);
  }

  Future<String?> _buildSearchPoiNote(PoiSearchResult poi) async {
    try {
      final details = await ref
          .read(poiRepositoryProvider)
          .resolvePlace(poi.placeId);
      return buildPoiNote(
        hoursRaw: details.hours,
        priceLevel: details.priceLevel,
        address: poi.address,
      );
    } on Exception {
      return buildPoiNote(address: poi.address);
    }
  }

  void _setSubmitError(String message) {
    if (_mode == EntryAddMode.search) {
      _searchError = message;
    } else if (_mode == EntryAddMode.favorites) {
      _favoritesError = message;
    }
  }

  void _setMode(EntryAddMode mode) {
    setState(() {
      if (_mode != mode) _dirty = true;
      _mode = mode;
    });
    if (mode == EntryAddMode.favorites) {
      unawaited(_loadFavorites());
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysAsync = ref.watch(tripDaysProvider(widget.tripId));
    final days = switch (daysAsync) {
      AsyncData<List<TripDay>>(:final value) => value,
      _ => const <TripDay>[],
    };
    final dayNum = days.isEmpty ? null : _dayNumFor(days);
    final primaryKey = _mode == EntryAddMode.custom
        ? const ValueKey('entry-edit-submit')
        : const ValueKey('entry-add-confirm');

    return AnimatedBuilder(
      animation: _customFormController,
      builder: (context, _) {
        final primaryEnabled =
            dayNum != null &&
            !_submittingSelected &&
            switch (_mode) {
              EntryAddMode.search ||
              EntryAddMode.favorites => _selectedCount > 0,
              EntryAddMode.custom => _customFormController.canSubmit,
            };
        return AppUnsavedChangesGuard(
          controller: _dismissController,
          hasChanges: _dirty || _customFormController.isDirty,
          dismissalEnabled:
              !_submittingSelected && !_customFormController.isSubmitting,
          child: Scaffold(
            appBar: TpAppBar(
              role: TpAppBarRole.modalForm,
              title: const Text('新增停留點'),
              onCancel: _dismissController.requestPop,
              primaryActionLabel: '加入',
              primaryActionKey: primaryKey,
              primaryActionEnabled: primaryEnabled,
              onPrimaryAction: () {
                if (dayNum != null) unawaited(_submitCurrent(dayNum));
              },
            ),
            body: daysAsync.when(
              loading: () => const AppListLoadingSkeleton(
                key: ValueKey('entry-add-loading'),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(TpSpacing.s6),
                  child: Text('載入失敗：$error', textAlign: TextAlign.center),
                ),
              ),
              data: (days) {
                if (days.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(TpSpacing.s6),
                      child: Text('此行程尚無日期，請先回行程頁建立日期。'),
                    ),
                  );
                }
                final dayNum = _dayNumFor(days);
                final filteredResults = _results
                    .where((poi) => _matchesCategory(poi.category, _category))
                    .toList(growable: false);
                final filteredFavorites = _favorites
                    .where(
                      (favorite) =>
                          _matchesCategory(favorite.poiType, _category),
                    )
                    .toList(growable: false);
                return ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    TpSpacing.s4,
                    TpSpacing.s4,
                    TpSpacing.s4,
                    TpSpacing.s8,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DayPicker(
                              days: days,
                              selectedDayNum: dayNum,
                              onSelected: (nextDayNum) => setState(() {
                                _selectedDayNum = nextDayNum;
                                _dirty = true;
                              }),
                            ),
                            const SizedBox(height: TpSpacing.s3),
                            SegmentedButton<EntryAddMode>(
                              segments: const [
                                ButtonSegment(
                                  value: EntryAddMode.search,
                                  icon: Icon(Icons.search),
                                  label: Text('搜尋'),
                                ),
                                ButtonSegment(
                                  value: EntryAddMode.favorites,
                                  icon: Icon(Icons.favorite_border),
                                  label: Text('收藏'),
                                ),
                                ButtonSegment(
                                  value: EntryAddMode.custom,
                                  icon: Icon(Icons.edit_location_alt_outlined),
                                  label: Text('自訂'),
                                ),
                              ],
                              selected: {_mode},
                              onSelectionChanged: (values) =>
                                  _setMode(values.first),
                            ),
                            const SizedBox(height: TpSpacing.s2),
                            if (_mode == EntryAddMode.search ||
                                _mode == EntryAddMode.favorites) ...[
                              _EntryAddCategoryFilter(
                                selected: _category,
                                onSelected: (category) =>
                                    setState(() => _category = category),
                              ),
                              const SizedBox(height: TpSpacing.s2),
                            ],
                            if (_mode == EntryAddMode.search)
                              _SearchPoiPanel(
                                controller: _searchController,
                                results: filteredResults,
                                searching: _searching,
                                selectedPlaceIds: _selectedPlaceIds,
                                poiTypeOverrides: _searchPoiTypeOverrides,
                                submitting: _submittingSelected,
                                selectedCount: _selectedCount,
                                error: _searchError,
                                emptyMessage:
                                    _results.isNotEmpty &&
                                        filteredResults.isEmpty
                                    ? '沒有符合分類的搜尋結果'
                                    : null,
                                region: _region,
                                onRegionChanged: (region) => setState(() {
                                  _region = region;
                                }),
                                onSearch: () => _searchPois(),
                                onToggle: _togglePoiSelection,
                                onPoiTypeChanged: (poi, poiType) =>
                                    setState(() {
                                      _searchPoiTypeOverrides[poi.placeId] =
                                          poiType;
                                      _dirty = true;
                                    }),
                              )
                            else if (_mode == EntryAddMode.favorites)
                              _FavoritePoiPanel(
                                favorites: filteredFavorites,
                                loading: _favoritesLoading && !_favoritesLoaded,
                                selectedFavoriteIds: _selectedFavoriteIds,
                                submitting: _submittingSelected,
                                selectedCount: _selectedCount,
                                error: _favoritesError,
                                emptyMessage:
                                    _favorites.isNotEmpty &&
                                        filteredFavorites.isEmpty
                                    ? '沒有符合分類的收藏'
                                    : '還沒有收藏的地點',
                                onRetry: () => _loadFavorites(force: true),
                                onToggle: _toggleFavoriteSelection,
                              )
                            else
                              EntryEditSheet(
                                tripId: widget.tripId,
                                args: EntryEditNew(dayNum),
                                formController: _customFormController,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _FavoritePoiPanel extends StatelessWidget {
  const _FavoritePoiPanel({
    required this.favorites,
    required this.loading,
    required this.selectedFavoriteIds,
    required this.submitting,
    required this.selectedCount,
    required this.error,
    required this.emptyMessage,
    required this.onRetry,
    required this.onToggle,
  });

  final List<PoiFavorite> favorites;
  final bool loading;
  final Set<int> selectedFavoriteIds;
  final bool submitting;
  final int selectedCount;
  final String? error;
  final String emptyMessage;
  final VoidCallback onRetry;
  final ValueChanged<PoiFavorite> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return const SizedBox(
        height: 180,
        child: AppListLoadingSkeleton(
          key: ValueKey('entry-favorites-loading'),
          itemCount: 1,
        ),
      );
    }

    if (favorites.isEmpty && error == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: TpSpacing.s6),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: TpSpacing.s2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('重試')),
              ],
            ),
          ),
        for (final favorite in favorites)
          Card(
            margin: const EdgeInsets.only(bottom: TpSpacing.s2),
            child: ListTile(
              key: ValueKey('entry-add-favorite-${favorite.id}'),
              title: Text(favorite.displayName),
              subtitle: favorite.poiAddress == null
                  ? null
                  : Text(favorite.poiAddress!),
              trailing: Checkbox(
                value: selectedFavoriteIds.contains(favorite.id),
                onChanged: submitting ? null : (_) => onToggle(favorite),
              ),
              onTap: submitting ? null : () => onToggle(favorite),
            ),
          ),
        if (selectedCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: TpSpacing.s3),
            child: Text('已選 $selectedCount 個'),
          ),
      ],
    );
  }
}

class _SearchPoiPanel extends StatelessWidget {
  const _SearchPoiPanel({
    required this.controller,
    required this.results,
    required this.searching,
    required this.selectedPlaceIds,
    required this.poiTypeOverrides,
    required this.submitting,
    required this.selectedCount,
    required this.error,
    required this.emptyMessage,
    required this.region,
    required this.onRegionChanged,
    required this.onSearch,
    required this.onToggle,
    required this.onPoiTypeChanged,
  });

  final TextEditingController controller;
  final List<PoiSearchResult> results;
  final bool searching;
  final Set<String> selectedPlaceIds;
  final Map<String, String> poiTypeOverrides;
  final bool submitting;
  final int selectedCount;
  final String? error;
  final String? emptyMessage;
  final String region;
  final ValueChanged<String> onRegionChanged;
  final VoidCallback onSearch;
  final ValueChanged<PoiSearchResult> onToggle;
  final void Function(PoiSearchResult poi, String poiType) onPoiTypeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<String>(
            tooltip: '切換搜尋地區',
            onSelected: onRegionChanged,
            itemBuilder: (context) => [
              for (final option in _regionOptionsFor(region))
                PopupMenuItem(value: option, child: Text(option)),
            ],
            child: Chip(
              avatar: const Icon(Icons.location_on_outlined, size: 16),
              label: Text(region),
            ),
          ),
        ),
        const SizedBox(height: TpSpacing.s2),
        AppSearchField(
          fieldKey: const ValueKey('entry-add-search-field'),
          controller: controller,
          placeholder: '搜尋景點',
          debounce: const Duration(milliseconds: 300),
          onChanged: (_) => onSearch(),
          onSubmitted: (_) => onSearch(),
        ),
        if (searching) ...[
          const SizedBox(height: TpSpacing.s1),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: TpSpacing.s2),
            child: Text(
              error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (error == null && emptyMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: TpSpacing.s2),
            child: Text(
              emptyMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: TpSpacing.s3),
        for (final poi in results) ...[
          Builder(
            builder: (context) {
              final selected = selectedPlaceIds.contains(poi.placeId);
              final poiType =
                  poiTypeOverrides[poi.placeId] ??
                  mapGooglePrimaryTypeToPoiType(poi.category);
              return Card(
                margin: const EdgeInsets.only(bottom: TpSpacing.s2),
                child: ListTile(
                  key: ValueKey('entry-add-poi-${poi.placeId}'),
                  title: Text(poi.name),
                  subtitle: _SearchPoiSubtitle(
                    poi: poi,
                    selected: selected,
                    poiType: poiType,
                    enabled: !submitting,
                    onPoiTypeChanged: (nextType) =>
                        onPoiTypeChanged(poi, nextType),
                  ),
                  trailing: Checkbox(
                    value: selected,
                    onChanged: submitting ? null : (_) => onToggle(poi),
                  ),
                  onTap: submitting ? null : () => onToggle(poi),
                ),
              );
            },
          ),
        ],
        if (selectedCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: TpSpacing.s3),
            child: Text('已選 $selectedCount 個'),
          ),
      ],
    );
  }
}

class _SearchPoiSubtitle extends StatelessWidget {
  const _SearchPoiSubtitle({
    required this.poi,
    required this.selected,
    required this.poiType,
    required this.enabled,
    required this.onPoiTypeChanged,
  });

  final PoiSearchResult poi;
  final bool selected;
  final String poiType;
  final bool enabled;
  final ValueChanged<String> onPoiTypeChanged;

  @override
  Widget build(BuildContext context) {
    final address = poi.address?.trim();
    final children = <Widget>[
      if (address != null && address.isNotEmpty) Text(address),
      if (selected)
        Padding(
          padding: const EdgeInsets.only(top: TpSpacing.s1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '分類',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: TpSpacing.s2),
              DropdownButton<String>(
                key: ValueKey('entry-add-poi-type-${poi.placeId}'),
                value: poiType,
                isDense: true,
                underline: const SizedBox.shrink(),
                onChanged: enabled
                    ? (value) {
                        if (value != null) onPoiTypeChanged(value);
                      }
                    : null,
                items: [
                  for (final entry in kPoiTypeLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
              ),
            ],
          ),
        ),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _EntryAddCategoryFilter extends StatelessWidget {
  const _EntryAddCategoryFilter({
    required this.selected,
    required this.onSelected,
  });

  final _EntryAddCategory selected;
  final ValueChanged<_EntryAddCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TpSpacing.tapMin,
      child: ListView.separated(
        key: const ValueKey('entry-add-category-list'),
        scrollDirection: Axis.horizontal,
        itemCount: _entryAddCategoryChips.length,
        separatorBuilder: (_, _) => const SizedBox(width: TpSpacing.s2),
        itemBuilder: (context, index) {
          final (category, label) = _entryAddCategoryChips[index];
          return FilterChip(
            key: ValueKey('entry-add-category-${category.name}'),
            selected: selected == category,
            onSelected: (_) => onSelected(category),
            label: Text(label),
          );
        },
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.days,
    required this.selectedDayNum,
    required this.onSelected,
  });

  final List<TripDay> days;
  final int selectedDayNum;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedDay = days.firstWhere(
      (day) => day.dayNum == selectedDayNum,
      orElse: () => days.first,
    );
    return OutlinedButton(
      key: const ValueKey('entry-add-day-picker'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
        alignment: Alignment.centerLeft,
      ),
      onPressed: () async {
        final selected = await showAppSelectionSheet<int>(
          context,
          title: '選擇日期',
          builder: (sheetContext, select) => ListView(
            children: [
              for (final day in days)
                ListTile(
                  key: ValueKey('entry-add-day-${day.dayNum}'),
                  title: Text(_dayLabel(day)),
                  trailing: day.dayNum == selectedDayNum
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => select(day.dayNum),
                ),
            ],
          ),
        );
        if (selected != null && context.mounted) onSelected(selected);
      },
      child: Row(
        children: [
          Expanded(child: Text(_dayLabel(selectedDay))),
          const Icon(Icons.keyboard_arrow_down),
        ],
      ),
    );
  }
}

String _dayLabel(TripDay day) {
  final title = day.displayTitle;
  if (title == 'Day ${day.dayNum}') return 'DAY ${day.dayNum}';
  return 'DAY ${day.dayNum} · $title';
}

String _normaliseRegion(String? region) {
  final trimmed = region?.trim();
  if (trimmed == null || trimmed.isEmpty) return '全部地區';
  return trimmed;
}

String? _regionForSearch(String region) {
  final trimmed = region.trim();
  if (trimmed.isEmpty || trimmed == '全部地區') return null;
  return trimmed;
}

List<String> _regionOptionsFor(String region) {
  final normalised = _normaliseRegion(region);
  if (_entryAddRegionOptions.contains(normalised)) {
    return _entryAddRegionOptions;
  }
  return [normalised, ..._entryAddRegionOptions];
}

bool _matchesCategory(String? rawCategory, _EntryAddCategory target) {
  if (target == _EntryAddCategory.all) return true;
  final category = rawCategory?.toLowerCase() ?? '';
  return switch (target) {
    _EntryAddCategory.food => RegExp(
      r'restaurant|cafe|food|bar|bakery|餐|食',
    ).hasMatch(category),
    _EntryAddCategory.hotel => RegExp(
      r'hotel|hostel|guest|inn|住宿|飯店',
    ).hasMatch(category),
    _EntryAddCategory.shopping => RegExp(
      r'shop|mall|market|購物',
    ).hasMatch(category),
    _EntryAddCategory.attraction => RegExp(
      r'attract|museum|park|temple|景點|公園',
    ).hasMatch(category),
    _EntryAddCategory.all => true,
  };
}
