import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/day.dart';
import '../../models/poi_search_result.dart';
import '../../models/poi_type.dart';
import '../../theme/tokens.dart';
import '../favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;
import 'trip_providers.dart';
import 'widgets/entry_edit_sheet.dart';

/// 新增停留點頁的初始模式。
enum EntryAddMode { search, custom }

/// Web 相容的停留點新增頁，支援搜尋 POI 或新增自訂停留點。
class EntryAddRouteScreen extends ConsumerStatefulWidget {
  const EntryAddRouteScreen({
    super.key,
    required this.tripId,
    this.initialDayNum,
    this.initialMode = EntryAddMode.custom,
  });

  final String tripId;
  final int? initialDayNum;
  final EntryAddMode initialMode;

  @override
  ConsumerState<EntryAddRouteScreen> createState() =>
      _EntryAddRouteScreenState();
}

class _EntryAddRouteScreenState extends ConsumerState<EntryAddRouteScreen> {
  late EntryAddMode _mode;
  final _searchController = TextEditingController();
  int? _selectedDayNum;
  List<PoiSearchResult> _results = const [];
  bool _searching = false;
  String? _addingPlaceId;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    if (q.isEmpty) {
      setState(() => _searchError = '請輸入景點關鍵字');
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await ref
          .read(poiRepositoryProvider)
          .searchPois(q: q, limit: 20, region: null);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        _searchError = results.isEmpty ? '找不到符合的景點' : null;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = '搜尋失敗，請稍後再試';
      });
    }
  }

  Future<void> _addPoi(PoiSearchResult poi, int dayNum) async {
    setState(() {
      _addingPlaceId = poi.placeId;
      _searchError = null;
    });
    try {
      await ref
          .read(tripRepositoryProvider)
          .addEntryToDay(
            tripId: widget.tripId,
            dayNum: dayNum,
            title: poi.name,
            note: poi.address,
            poiType: mapGooglePrimaryTypeToPoiType(poi.category),
            lat: poi.lat,
            lng: poi.lng,
            source: 'google',
          );
      ref.invalidate(tripDaysProvider(widget.tripId));
      if (!mounted) return;
      context.go('/trips/${Uri.encodeComponent(widget.tripId)}');
    } on Exception {
      if (!mounted) return;
      setState(() {
        _addingPlaceId = null;
        _searchError = '加入行程失敗，請稍後再試';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysAsync = ref.watch(tripDaysProvider(widget.tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('新增停留點')),
      body: daysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
          return ListView(
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
                        onSelected: (nextDayNum) =>
                            setState(() => _selectedDayNum = nextDayNum),
                      ),
                      const SizedBox(height: TpSpacing.s3),
                      SegmentedButton<EntryAddMode>(
                        segments: const [
                          ButtonSegment(
                            value: EntryAddMode.search,
                            icon: Icon(Icons.search),
                            label: Text('搜尋景點'),
                          ),
                          ButtonSegment(
                            value: EntryAddMode.custom,
                            icon: Icon(Icons.edit_location_alt_outlined),
                            label: Text('自訂'),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (values) =>
                            setState(() => _mode = values.first),
                      ),
                      const SizedBox(height: TpSpacing.s2),
                      if (_mode == EntryAddMode.search)
                        _SearchPoiPanel(
                          controller: _searchController,
                          results: _results,
                          searching: _searching,
                          addingPlaceId: _addingPlaceId,
                          error: _searchError,
                          onSearch: () => _searchPois(),
                          onAdd: (poi) => _addPoi(poi, dayNum),
                        )
                      else
                        EntryEditSheet(
                          tripId: widget.tripId,
                          args: EntryEditNew(dayNum),
                          onSaved: () => context.go(
                            '/trips/${Uri.encodeComponent(widget.tripId)}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchPoiPanel extends StatelessWidget {
  const _SearchPoiPanel({
    required this.controller,
    required this.results,
    required this.searching,
    required this.addingPlaceId,
    required this.error,
    required this.onSearch,
    required this.onAdd,
  });

  final TextEditingController controller;
  final List<PoiSearchResult> results;
  final bool searching;
  final String? addingPlaceId;
  final String? error;
  final VoidCallback onSearch;
  final ValueChanged<PoiSearchResult> onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('entry-add-search-field'),
                controller: controller,
                decoration: const InputDecoration(labelText: '搜尋景點'),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSearch(),
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            IconButton.filled(
              key: const ValueKey('entry-add-search-submit'),
              tooltip: '搜尋',
              onPressed: searching ? null : onSearch,
              icon: searching
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: TpSpacing.s2),
            child: Text(
              error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: TpSpacing.s3),
        for (final poi in results)
          Card(
            margin: const EdgeInsets.only(bottom: TpSpacing.s2),
            child: ListTile(
              key: ValueKey('entry-add-poi-${poi.placeId}'),
              title: Text(poi.name),
              subtitle: poi.address == null ? null : Text(poi.address!),
              trailing: addingPlaceId == poi.placeId
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_location_alt_outlined),
              onTap: addingPlaceId == null ? () => onAdd(poi) : null,
            ),
          ),
      ],
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
    return Wrap(
      spacing: TpSpacing.s2,
      runSpacing: TpSpacing.s2,
      children: [
        for (final day in days)
          FilterChip(
            key: ValueKey('entry-add-day-${day.dayNum}'),
            selected: day.dayNum == selectedDayNum,
            onSelected: (_) => onSelected(day.dayNum),
            label: Text(_dayLabel(day)),
          ),
      ],
    );
  }
}

String _dayLabel(TripDay day) {
  final title = day.displayTitle;
  if (title == 'Day ${day.dayNum}') return 'DAY ${day.dayNum}';
  return 'DAY ${day.dayNum} · $title';
}
