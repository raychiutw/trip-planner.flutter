import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../models/day.dart';
import '../../../models/entry.dart';
import '../../../models/poi_favorite.dart';
import '../../../models/poi_search_result.dart';
import '../../../theme/tokens.dart';
import '../../favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;
import '../../favorites/favorites_providers.dart' show favoritesProvider;
import '../trip_providers.dart';

/// 「新增停留點」熱門搜尋 seed(比照建立行程的熱門目的地)。
const _hotSearches = ['沖繩', '東京', '京都', '首爾', '曼谷', '台北'];

/// 把收藏(有座標)轉成 PoiSearchResult,走與搜尋結果相同的選取/送出路徑。
PoiSearchResult _poiFromFavorite(PoiFavorite f) => PoiSearchResult(
  placeId: 'fav-${f.id}',
  name: f.displayName,
  address: f.poiAddress,
  lat: f.poiLat ?? 0,
  lng: f.poiLng ?? 0,
  category: f.poiType,
  rating: f.poiRating,
);

/// 編輯/新增停留點的模式參數。
sealed class EntryEditArgs {
  const EntryEditArgs();
}

class EntryEditExisting extends EntryEditArgs {
  const EntryEditExisting(this.entry);
  final TimelineEntry entry;
}

class EntryEditNew extends EntryEditArgs {
  const EntryEditNew(this.dayNum, {this.days = const []});
  final int dayNum;
  final List<TripDay> days;
}

/// 時間區間有效性：start/end 皆設時 end 須晚於 start;任一未設視為有效（時間選填）。
bool entryTimeRangeValid(TimeOfDay? start, TimeOfDay? end) {
  if (start == null || end == null) return true;
  return end.hour * 60 + end.minute > start.hour * 60 + start.minute;
}

/// 以 modal bottom sheet 開啟編輯/新增停留點表單。
Future<void> showEntryEditSheet(
  BuildContext context, {
  required String tripId,
  required EntryEditArgs args,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: EntryEditSheet(tripId: tripId, args: args),
    ),
  );
}

class EntryEditSheet extends ConsumerStatefulWidget {
  const EntryEditSheet({super.key, required this.tripId, required this.args});

  final String tripId;
  final EntryEditArgs args;

  @override
  ConsumerState<EntryEditSheet> createState() => _EntryEditSheetState();
}

class _EntryEditSheetState extends ConsumerState<EntryEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  TimeOfDay? _start;
  TimeOfDay? _end;
  int? _newDayNum;
  bool _submitting = false;

  // POI 搜尋狀態(僅新增模式):選到的 POI、搜尋結果、是否搜尋中。
  PoiSearchResult? _selectedPoi;
  List<PoiSearchResult> _results = const [];
  bool _searching = false;

  bool get _isEdit => widget.args is EntryEditExisting;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args is EntryEditExisting) {
      _title = TextEditingController(text: args.entry.title);
      _desc = TextEditingController(text: args.entry.description ?? '');
      _start = _parseHm(args.entry.startTime);
      _end = _parseHm(args.entry.endTime);
    } else {
      _title = TextEditingController();
      _desc = TextEditingController();
      _newDayNum = (args as EntryEditNew).dayNum;
    }
    _title.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseHm(String? hm) {
    if (hm == null) return null;
    final parts = hm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String? _fmt(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool get _canSubmit =>
      !_submitting &&
      (_isEdit || _title.text.trim().isNotEmpty) &&
      entryTimeRangeValid(_start, _end);

  int _selectedDayNum(EntryEditNew args) {
    final dayNum = _newDayNum ?? args.dayNum;
    return args.days.isEmpty || args.days.any((d) => d.dayNum == dayNum)
        ? dayNum
        : args.dayNum;
  }

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _start : _end) ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  Future<void> _recomputeDay(int dayNum) async {
    try {
      await ref
          .read(tripRepositoryProvider)
          .recomputeTravel(tripId: widget.tripId, day: '$dayNum');
    } on Exception {
      // 交通重算失敗不影響停留點新增結果。
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final description = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    setState(() => _submitting = true);
    final repo = ref.read(tripRepositoryProvider);
    try {
      switch (widget.args) {
        case EntryEditExisting(:final entry):
          await repo.updateEntry(
            tripId: widget.tripId,
            entryId: entry.id,
            expectedVersion: entry.version,
            description: description,
            startTime: _fmt(_start),
            endTime: _fmt(_end),
          );
          try {
            await repo.recomputeTravel(tripId: widget.tripId);
          } on Exception {
            // Entry save succeeded; travel can self-heal on the next refresh.
          }
        case final EntryEditNew args:
          final dayNum = _selectedDayNum(args);
          final poi = _selectedPoi;
          // 選了 POI → 帶名稱 + 座標(source user-explore,後端 find-or-create 帶分類);
          // 沒選 → 手打標題當自訂停留點(無座標,source custom)。
          final hasCoords = poi != null && (poi.lat != 0 || poi.lng != 0);
          await repo.addEntryToDay(
            tripId: widget.tripId,
            dayNum: dayNum,
            title: poi?.name ?? title,
            description: description,
            lat: hasCoords ? poi.lat : null,
            lng: hasCoords ? poi.lng : null,
            startTime: _fmt(_start),
            endTime: _fmt(_end),
            source: poi != null ? 'user-explore' : 'custom',
          );
          await _recomputeDay(dayNum);
      }
      ref.invalidate(tripDaysProvider(widget.tripId));
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      showAppNotice(context, _isEdit ? '已儲存' : '已新增');
    } on ApiError catch (error) {
      if (!mounted) return;
      if (error.status == 409) {
        ref.invalidate(tripDaysProvider(widget.tripId));
        Navigator.of(context).pop();
        showAppNotice(context, '此停留點已更新，已重新載入，請再編輯一次');
        return;
      }
      setState(() => _submitting = false);
      showAppNotice(context, '儲存失敗，請稍後再試');
    } on Exception {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppNotice(context, '儲存失敗，請稍後再試');
    }
  }

  Future<void> _runPoiSearch() async {
    final q = _title.text.trim();
    if (q.length < 2) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final r = await ref
          .read(poiRepositoryProvider)
          .searchPois(q: q, region: '全部地區');
      if (mounted) setState(() => _results = r);
    } on Exception {
      if (mounted) {
        setState(() => _results = const []);
        showAppNotice(context, '搜尋失敗，請稍後再試');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pickPoi(PoiSearchResult poi) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedPoi = poi;
      _title.text = poi.name;
      _results = const [];
    });
  }

  void _clearPoi() => setState(() {
    _selectedPoi = null;
    _results = const [];
  });

  /// 新增模式的地點區塊:已選 → 地點卡;未選 → 搜尋框 + 熱門 chips + 結果清單。
  /// 搜尋沿用建立行程那套(AppSearchField + /poi-search on submit);沒選就以手打
  /// 標題當自訂停留點(無座標)。
  Widget _buildPoiSection(BuildContext context) {
    final poi = _selectedPoi;
    if (poi != null) {
      return _SelectedPoiCard(poi: poi, onChange: _clearPoi);
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                fieldKey: const ValueKey('entry-edit-title'),
                controller: _title,
                placeholder: '地點名稱(可搜尋)',
                onSubmitted: (_) => _runPoiSearch(),
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            IconButton.filled(
              key: const ValueKey('entry-poi-search-btn'),
              tooltip: '搜尋地點',
              onPressed: _searching ? null : _runPoiSearch,
              icon: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.search),
            ),
          ],
        ),
        const SizedBox(height: TpSpacing.s2),
        Wrap(
          spacing: TpSpacing.s2,
          children: [
            for (final h in _hotSearches)
              ActionChip(
                key: ValueKey('entry-poi-hot-$h'),
                label: Text(h),
                onPressed: () {
                  _title.text = h;
                  _runPoiSearch();
                },
              ),
          ],
        ),
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: TpSpacing.s2),
            child: Material(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(TpRadius.md),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final r in _results.take(6))
                    ListTile(
                      dense: true,
                      key: ValueKey('poi-result-${r.placeId}'),
                      leading: const Icon(CupertinoIcons.location_solid),
                      title: Text(r.name),
                      subtitle: r.address == null
                          ? null
                          : Text(
                              r.address!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => _pickPoi(r),
                    ),
                ],
              ),
            ),
          )
        else
          _favoritesSection(context),
      ],
    );
  }

  /// 尚未搜尋時,列出「有座標的收藏」供直接加入 — 點選走與搜尋結果相同的
  /// _pickPoi 路徑,送出時帶 lat/lng(source user-explore)。無座標收藏不列。
  Widget _favoritesSection(BuildContext context) {
    final theme = Theme.of(context);
    final favs =
        ref.watch(favoritesProvider).asData?.value ?? const <PoiFavorite>[];
    final withCoords = [
      for (final f in favs)
        if (f.poiLat != null && f.poiLng != null) f,
    ];
    if (withCoords.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: TpSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '從收藏加入',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TpSpacing.s1),
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(TpRadius.md),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in withCoords.take(6))
                  ListTile(
                    dense: true,
                    key: ValueKey('fav-result-${f.id}'),
                    leading: const Icon(CupertinoIcons.heart_fill, size: 18),
                    title: Text(f.displayName),
                    subtitle: f.poiAddress == null
                        ? null
                        : Text(
                            f.poiAddress!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => _pickPoi(_poiFromFavorite(f)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeValid = entryTimeRangeValid(_start, _end);
    final args = widget.args;
    final dayOptions = args is EntryEditNew ? args.days : const <TripDay>[];
    final selectedDayNum = args is EntryEditNew ? _selectedDayNum(args) : null;
    final showDayPicker =
        dayOptions.length > 1 &&
        dayOptions.any((d) => d.dayNum == selectedDayNum);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? '編輯停留點' : '新增停留點',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: TpSpacing.s4),
              if (!_isEdit) _buildPoiSection(context),
              if (showDayPicker) ...[
                const SizedBox(height: TpSpacing.s3),
                DropdownButtonFormField<int>(
                  key: const ValueKey('entry-edit-day'),
                  initialValue: selectedDayNum,
                  decoration: const InputDecoration(labelText: '日期'),
                  items: [
                    for (final day in dayOptions)
                      DropdownMenuItem(
                        value: day.dayNum,
                        child: Text('DAY ${day.dayNum} · ${day.displayTitle}'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _newDayNum = value);
                  },
                ),
              ],
              const SizedBox(height: TpSpacing.s3),
              _timeField(true),
              const SizedBox(height: TpSpacing.s2),
              _timeField(false),
              if (!timeValid)
                Padding(
                  padding: const EdgeInsets.only(top: TpSpacing.s2),
                  child: Text(
                    '結束時間需晚於開始時間',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: TpSpacing.s3),
              TextField(
                key: const ValueKey('entry-edit-desc'),
                controller: _desc,
                decoration: const InputDecoration(labelText: '描述（選填）'),
                maxLines: 2,
              ),
              if (_isEdit) ...[
                const SizedBox(height: TpSpacing.s3),
                OutlinedButton.icon(
                  key: const ValueKey('entry-edit-manage-pois'),
                  onPressed: () {
                    final entry = (widget.args as EntryEditExisting).entry;
                    Navigator.of(context).pop();
                    context.push(
                      '/trips/${widget.tripId}/entries/${entry.id}/pois',
                    );
                  },
                  icon: const Icon(CupertinoIcons.location_solid),
                  label: const Text('管理地點'),
                ),
              ],
              const SizedBox(height: TpSpacing.s6),
              FilledButton(
                key: const ValueKey('entry-edit-submit'),
                onPressed: _canSubmit ? _submit : null,
                child: Text(_submitting ? '處理中…' : (_isEdit ? '儲存' : '新增')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeField(bool isStart) {
    final t = isStart ? _start : _end;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: ValueKey(isStart ? 'entry-edit-start' : 'entry-edit-end'),
            onPressed: () => _pick(isStart),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${isStart ? '開始' : '結束'}　${_fmt(t) ?? '未設定'}'),
            ),
          ),
        ),
        if (t != null)
          IconButton(
            key: ValueKey(
              isStart ? 'entry-edit-start-clear' : 'entry-edit-end-clear',
            ),
            tooltip: '清除',
            icon: const Icon(CupertinoIcons.xmark, size: 18),
            onPressed: () =>
                setState(() => isStart ? _start = null : _end = null),
          ),
      ],
    );
  }
}

/// 已選 POI 的確認卡:名稱 + 地址 +「已帶入座標」+ 更換(清除重選)。
class _SelectedPoiCard extends StatelessWidget {
  const _SelectedPoiCard({required this.poi, required this.onChange});

  final PoiSearchResult poi;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCoords = poi.lat != 0 || poi.lng != 0;
    return Container(
      key: const ValueKey('entry-poi-selected'),
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.location_solid, color: theme.colorScheme.primary),
          const SizedBox(width: TpSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(poi.name, style: theme.textTheme.titleMedium),
                if (poi.address != null)
                  Text(
                    poi.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (hasCoords)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '已帶入座標',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('entry-poi-clear'),
            onPressed: onChange,
            child: const Text('更換'),
          ),
        ],
      ),
    );
  }
}
