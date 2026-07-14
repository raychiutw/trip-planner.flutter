import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../api/trip_repository.dart' show CustomEntryPoi;
import '../../app/adaptive.dart';
import '../../app/app_feedback.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/poi_favorite.dart';
import '../../models/poi_search_result.dart';
import '../../models/poi_type.dart';
import '../../theme/tokens.dart';
import '../favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;
import '../favorites/favorites_providers.dart';
import 'trip_providers.dart';

/// 開啟 POI 訂位連結的注入點，讓測試可替換外部瀏覽器呼叫。
typedef ReservationUrlLauncher = Future<void> Function(Uri url);

/// 用系統外部瀏覽器 / app 開啟訂位連結。
Future<void> launchReservationUrl(Uri url) async {
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw Exception('Unable to open reservation URL: $url');
  }
}

/// 地點管理全頁：正選切換、備選增刪、per-POI 備註/分類/訂位。
/// OCC = entryPoisVersion（string）;每次操作後重抓 entryDetail 取最新 token。
class EntryPoiScreen extends ConsumerWidget {
  const EntryPoiScreen({
    super.key,
    required this.tripId,
    required this.entryId,
    this.reservationUrlLauncher = launchReservationUrl,
  });

  final String tripId;
  final int entryId;

  /// 訂位連結開啟器；production 用 `url_launcher`，測試可注入 fake。
  final ReservationUrlLauncher reservationUrlLauncher;

  ({String tripId, int entryId}) get _key => (tripId: tripId, entryId: entryId);

  /// 跑一個 POI 操作 → 成功重抓 entryDetail + tripDays;409 重抓 + 提示。
  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() op, {
    required String success,
    bool recomputeTravel = false,
  }) async {
    try {
      await op();
      if (recomputeTravel) {
        await _recomputeTravel(ref);
      }
      ref.invalidate(entryDetailProvider(_key));
      ref.invalidate(tripDaysProvider(tripId));
      if (!context.mounted) return;
      showAppNotice(context, success);
    } on ApiError catch (error) {
      ref.invalidate(entryDetailProvider(_key));
      if (!context.mounted) return;
      showAppError(context, error.status == 409 ? '地點已更新，已重新載入' : '操作失敗，請稍後再試');
    } on Exception {
      if (!context.mounted) return;
      showAppError(context, '操作失敗，請稍後再試');
    }
  }

  Future<void> _recomputeTravel(WidgetRef ref) async {
    try {
      await ref.read(tripRepositoryProvider).recomputeTravel(tripId: tripId);
    } on Exception {
      // 交通重算失敗不影響地點管理結果。
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(entryDetailProvider(_key));
    return Scaffold(
      appBar: AppBar(title: const Text('地點管理')),
      body: entryAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(TpSpacing.s6),
            child: Text('無法載入地點:$error', textAlign: TextAlign.center),
          ),
        ),
        data: (entry) => _body(context, ref, entry),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, TimelineEntry entry) {
    final theme = Theme.of(context);
    final repo = ref.read(tripRepositoryProvider);
    final version = entry.entryPoisVersion;
    final sameDayEntries = switch (ref.watch(tripDaysProvider(tripId))) {
      AsyncData(:final value) => _sameDayEntries(value, entry.id),
      _ => const <TimelineEntry>[],
    };

    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        Text('正選地點', style: theme.textTheme.titleMedium),
        const SizedBox(height: TpSpacing.s2),
        if (entry.master != null)
          _PoiCard(
            poi: entry.master!,
            isMaster: true,
            reservationUrlLauncher: reservationUrlLauncher,
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('change-master'),
                  onPressed: () => _changeMaster(context, ref, entry),
                  child: const Text('置換正選'),
                ),
                TextButton(
                  key: const ValueKey('poi-edit-master'),
                  onPressed: () => _editPoiInfo(context, ref, entry.master!),
                  child: const Text('編輯資訊'),
                ),
              ],
            ),
          )
        else
          Text(
            '尚無正選地點',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: TpSpacing.s5),
        Row(
          children: [
            Text('備選地點', style: theme.textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              key: const ValueKey('add-alternate'),
              onPressed: () => _addAlternate(context, ref, entry),
              icon: const Icon(CupertinoIcons.add),
              label: const Text('加入備選'),
            ),
          ],
        ),
        const SizedBox(height: TpSpacing.s2),
        if (entry.alternates.isEmpty)
          Text(
            '尚無備選地點',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final (index, alt) in entry.alternates.indexed)
            _PoiCard(
              poi: alt,
              isMaster: false,
              reservationUrlLauncher: reservationUrlLauncher,
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('alt-move-up-${alt.poiId}'),
                        tooltip: '上移',
                        icon: const Icon(Icons.keyboard_arrow_up),
                        onPressed: index == 0
                            ? null
                            : () => _moveAlternate(
                                context,
                                ref,
                                entry,
                                index,
                                -1,
                              ),
                      ),
                      IconButton(
                        key: ValueKey('alt-move-down-${alt.poiId}'),
                        tooltip: '下移',
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onPressed: index == entry.alternates.length - 1
                            ? null
                            : () =>
                                  _moveAlternate(context, ref, entry, index, 1),
                      ),
                      IconButton(
                        key: ValueKey('alt-remove-${alt.poiId}'),
                        tooltip: '移除',
                        icon: const Icon(CupertinoIcons.delete),
                        onPressed: () => _run(
                          context,
                          ref,
                          () => repo.removeEntryAlternate(
                            tripId: tripId,
                            entryId: entryId,
                            poiId: alt.poiId,
                            entryPoisVersion: version,
                          ),
                          success: '已移除備選',
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    key: ValueKey('alt-setmaster-${alt.poiId}'),
                    onPressed: () => _confirmSetMaster(
                      context,
                      ref,
                      entry,
                      alt,
                      sameDayEntries,
                    ),
                    child: const Text('設為正選'),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Future<void> _confirmSetMaster(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
    EntryPoiInfo alternate,
    List<TimelineEntry> sameDayEntries,
  ) async {
    final warning = _crossRegionWarning(alternate, sameDayEntries, entry.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('設為正選？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('要將「${alternate.name ?? '未命名地點'}」設為此停留點的正選嗎？'),
            if (warning != null) ...[
              const SizedBox(height: TpSpacing.s3),
              Text(
                warning,
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('設為正選'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(tripRepositoryProvider)
          .setEntryMaster(
            tripId: tripId,
            entryId: entryId,
            poiId: alternate.poiId,
            entryPoisVersion: entry.entryPoisVersion,
          ),
      success: '已設為正選',
      recomputeTravel: true,
    );
  }

  Future<void> _editPoiInfo(
    BuildContext context,
    WidgetRef ref,
    EntryPoiInfo poi,
  ) async {
    final result =
        await showAdaptiveDialog<
          ({String? note, String type, String? reservation})
        >(
          context: context,
          builder: (_) => _PoiInfoDialog(poi: poi),
        );
    if (result == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(tripRepositoryProvider)
          .updateEntryPoi(
            tripId: tripId,
            entryId: entryId,
            poiId: poi.poiId,
            note: result.note,
            poiType: result.type,
            reservation: result.reservation,
          ),
      success: '已儲存',
    );
  }

  Future<void> _moveAlternate(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
    int fromIndex,
    int delta,
  ) async {
    final toIndex = fromIndex + delta;
    if (toIndex < 0 || toIndex >= entry.alternates.length) return;
    final alternates = entry.alternates.toList();
    final moved = alternates.removeAt(fromIndex);
    alternates.insert(toIndex, moved);
    await _run(
      context,
      ref,
      () => ref
          .read(tripRepositoryProvider)
          .reorderEntryAlternates(
            tripId: tripId,
            entryId: entryId,
            order: [for (final alternate in alternates) alternate.poiId],
            entryPoisVersion: entry.entryPoisVersion,
          ),
      success: '已更新備選順序',
    );
  }

  Future<void> _addAlternate(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
  ) async {
    final selected = await showModalBottomSheet<_EntryPoiPick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: const _AlternateSearchSheet(),
      ),
    );
    if (selected == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(tripRepositoryProvider)
          .addEntryAlternate(
            tripId: tripId,
            entryId: entryId,
            poiId: selected.poiId,
            poi: selected.poi,
            customPoi: selected.customPoi,
            entryPoisVersion: entry.entryPoisVersion,
          ),
      success: '已加入備選',
    );
  }

  Future<void> _changeMaster(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
  ) async {
    final selected = await showModalBottomSheet<_EntryPoiPick>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: const _AlternateSearchSheet(hintText: '搜尋地點置換正選'),
      ),
    );
    if (selected == null || !context.mounted) return;
    await _run(context, ref, () async {
      await ref
          .read(tripRepositoryProvider)
          .changeEntryPoi(
            tripId: tripId,
            entryId: entryId,
            poiId: selected.poiId,
            poi: selected.poi,
            customPoi: selected.customPoi,
            entryPoisVersion: entry.entryPoisVersion,
          );
    }, success: '已置換正選');
  }
}

class _EntryPoiPick {
  const _EntryPoiPick.search(this.poi) : poiId = null, customPoi = null;

  const _EntryPoiPick.favorite(this.poiId) : poi = null, customPoi = null;

  const _EntryPoiPick.custom(this.customPoi) : poi = null, poiId = null;

  final PoiSearchResult? poi;
  final int? poiId;
  final CustomEntryPoi? customPoi;
}

/// 正選/備選共用卡：名稱 + 分類 label + 評分 + 備註/訂位 + 尾端操作。
class _PoiCard extends StatelessWidget {
  const _PoiCard({
    required this.poi,
    required this.isMaster,
    required this.reservationUrlLauncher,
    required this.trailing,
  });

  final EntryPoiInfo poi;
  final bool isMaster;
  final ReservationUrlLauncher reservationUrlLauncher;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final reservationUri = _safeReservationUri(poi.reservationUrl);
    return Container(
      key: ValueKey('poi-card-${poi.poiId}'),
      margin: const EdgeInsets.only(bottom: TpSpacing.s2),
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poi.name ?? '未命名地點',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  [
                    kPoiTypeLabels[poi.type] ?? 'POI',
                    if (poi.rating != null)
                      '★ ${poi.rating!.toStringAsFixed(1)}',
                  ].join('  ·  '),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                if (poi.note != null && poi.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: TpSpacing.s1),
                    child: Text(
                      poi.note!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ),
                if (poi.reservation != null && poi.reservation!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: TpSpacing.s1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '訂位:${poi.reservation!}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                        if (reservationUri != null) ...[
                          const SizedBox(width: TpSpacing.s1),
                          IconButton(
                            key: ValueKey('poi-reservation-link-${poi.poiId}'),
                            tooltip: '開啟訂位連結',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            iconSize: 18,
                            icon: const Icon(Icons.open_in_new_rounded),
                            onPressed: () => _openReservationUrl(
                              context,
                              reservationUrlLauncher,
                              reservationUri,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

typedef _LatLng = ({double lat, double lng});

const _crossRegionThresholdM = 50000.0;
const _earthRadiusM = 6371000.0;

List<TimelineEntry> _sameDayEntries(List<TripDay> days, int entryId) {
  for (final day in days) {
    for (final entry in day.timeline) {
      if (entry.id == entryId) return day.timeline;
    }
  }
  return const <TimelineEntry>[];
}

String? _crossRegionWarning(
  EntryPoiInfo alternate,
  List<TimelineEntry> sameDayEntries,
  int entryId,
) {
  final lat = alternate.lat;
  final lng = alternate.lng;
  if (lat == null || lng == null) return null;

  final siblingCoords = <_LatLng>[
    for (final entry in sameDayEntries)
      if (entry.id != entryId &&
          entry.master?.lat != null &&
          entry.master?.lng != null)
        (lat: entry.master!.lat!, lng: entry.master!.lng!),
  ];
  final center = _avgLatLng(siblingCoords);
  if (center == null) return null;

  final distance = _haversineMeters((lat: lat, lng: lng), center);
  if (distance <= _crossRegionThresholdM) return null;

  final km = distance >= 100000
      ? (distance / 1000).round().toString()
      : (distance / 1000).toStringAsFixed(1);
  return '新正選距離本日其他點約 $km km，可能跨區，前後車程會誤算。確定要設為正選？';
}

_LatLng? _avgLatLng(List<_LatLng> points) {
  if (points.isEmpty) return null;
  var lat = 0.0;
  var lng = 0.0;
  for (final point in points) {
    lat += point.lat;
    lng += point.lng;
  }
  return (lat: lat / points.length, lng: lng / points.length);
}

double _haversineMeters(_LatLng a, _LatLng b) {
  final phi1 = _toRadians(a.lat);
  final phi2 = _toRadians(b.lat);
  final dPhi = _toRadians(b.lat - a.lat);
  final dLambda = _toRadians(b.lng - a.lng);
  final h =
      math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(dLambda / 2) *
          math.sin(dLambda / 2);
  return 2 * _earthRadiusM * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

double _toRadians(double degrees) => degrees * math.pi / 180;

Uri? _safeReservationUri(String? rawUrl) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) return null;
  return switch (uri.scheme.toLowerCase()) {
    'http' || 'https' => uri,
    _ => null,
  };
}

Future<void> _openReservationUrl(
  BuildContext context,
  ReservationUrlLauncher launcher,
  Uri url,
) async {
  try {
    await launcher(url);
  } on Exception {
    if (!context.mounted) return;
    showAppError(context, '無法開啟訂位連結');
  }
}

/// per-POI 資訊編輯 dialog（自持 controller,route 移除時才 dispose,避免關閉動畫
/// 期間用到已 dispose 的 controller）。回傳 note/type/reservation 的 record。
class _PoiInfoDialog extends StatefulWidget {
  const _PoiInfoDialog({required this.poi});

  final EntryPoiInfo poi;

  @override
  State<_PoiInfoDialog> createState() => _PoiInfoDialogState();
}

class _PoiInfoDialogState extends State<_PoiInfoDialog> {
  late final TextEditingController _note;
  late final TextEditingController _resv;
  late String _type;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.poi.note ?? '');
    _resv = TextEditingController(text: widget.poi.reservation ?? '');
    _type = widget.poi.type ?? 'attraction';
  }

  @override
  void dispose() {
    _note.dispose();
    _resv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: const Text('編輯地點資訊'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('poi-note'),
              controller: _note,
              decoration: const InputDecoration(labelText: '備註'),
              maxLines: 2,
            ),
            const SizedBox(height: TpSpacing.s3),
            const Text('分類'),
            const SizedBox(height: TpSpacing.s1),
            Wrap(
              spacing: TpSpacing.s2,
              children: [
                for (final e in kPoiTypeLabels.entries)
                  ChoiceChip(
                    key: ValueKey('poi-type-${e.key}'),
                    label: Text(e.value),
                    selected: _type == e.key,
                    onSelected: (_) => setState(() => _type = e.key),
                  ),
              ],
            ),
            const SizedBox(height: TpSpacing.s3),
            TextField(
              key: const ValueKey('poi-reservation'),
              controller: _resv,
              decoration: const InputDecoration(labelText: '訂位資訊'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('poi-save'),
          onPressed: () {
            final note = _note.text.trim();
            final resv = _resv.text.trim();
            Navigator.of(context).pop((
              note: note.isEmpty ? null : note,
              type: _type,
              reservation: resv.isEmpty ? null : resv,
            ));
          },
          child: const Text('儲存'),
        ),
      ],
    );
  }
}

/// Entry POI 操作共用搜尋 sheet（複用探索的 poiRepositoryProvider.searchPois）。
class _AlternateSearchSheet extends ConsumerStatefulWidget {
  const _AlternateSearchSheet({this.hintText = '搜尋地點加入備選'});

  final String hintText;

  @override
  ConsumerState<_AlternateSearchSheet> createState() =>
      _AlternateSearchSheetState();
}

enum _PoiPickerTab { search, favorites, custom }

class _AlternateSearchSheetState extends ConsumerState<_AlternateSearchSheet> {
  final _ctrl = TextEditingController();
  final _customNameCtrl = TextEditingController();
  final _customLatCtrl = TextEditingController();
  final _customLngCtrl = TextEditingController();
  _PoiPickerTab _tab = _PoiPickerTab.search;
  List<PoiSearchResult> _results = const [];
  List<PoiFavorite> _favorites = const [];
  bool _searching = false;
  bool _favoritesLoaded = false;
  bool _favoritesLoading = false;
  String? _favoritesError;
  String _customPoiType = 'attraction';
  String? _customError;

  @override
  void dispose() {
    _ctrl.dispose();
    _customNameCtrl.dispose();
    _customLatCtrl.dispose();
    _customLngCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.length < 2) return;
    setState(() => _searching = true);
    try {
      final results = await ref.read(poiRepositoryProvider).searchPois(q: q);
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
        });
      }
    } on Exception {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectTab(_PoiPickerTab tab) async {
    if (_tab != tab) {
      setState(() => _tab = tab);
    }
    if (tab == _PoiPickerTab.favorites &&
        !_favoritesLoaded &&
        !_favoritesLoading) {
      await _loadFavorites();
    }
  }

  Future<void> _loadFavorites() async {
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
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _favoritesLoading = false;
        _favoritesError = '載入收藏失敗，請稍後再試';
      });
    }
  }

  Widget _tabButton({
    required _PoiPickerTab tab,
    required String label,
    required Key key,
  }) {
    final selected = _tab == tab;
    return Expanded(
      child: selected
          ? FilledButton(
              key: key,
              onPressed: () => _selectTab(tab),
              child: Text(label),
            )
          : OutlinedButton(
              key: key,
              onPressed: () => _selectTab(tab),
              child: Text(label),
            ),
    );
  }

  void _submitCustom() {
    final name = _customNameCtrl.text.trim();
    final lat = double.tryParse(_customLatCtrl.text.trim());
    final lng = double.tryParse(_customLngCtrl.text.trim());
    if (name.isEmpty || lat == null || lng == null) {
      setState(() => _customError = '請輸入名稱與有效座標');
      return;
    }
    Navigator.of(context).pop(
      _EntryPoiPick.custom(
        CustomEntryPoi(name: name, lat: lat, lng: lng, poiType: _customPoiType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _tabButton(
                  tab: _PoiPickerTab.search,
                  label: '搜尋',
                  key: const ValueKey('poi-picker-tab-search'),
                ),
                const SizedBox(width: TpSpacing.s2),
                _tabButton(
                  tab: _PoiPickerTab.favorites,
                  label: '收藏',
                  key: const ValueKey('poi-picker-tab-favorites'),
                ),
                const SizedBox(width: TpSpacing.s2),
                _tabButton(
                  tab: _PoiPickerTab.custom,
                  label: '自訂',
                  key: const ValueKey('poi-picker-tab-custom'),
                ),
              ],
            ),
            const SizedBox(height: TpSpacing.s3),
            if (_tab == _PoiPickerTab.search) ...[
              Row(
                children: [
                  Expanded(
                    child: AppSearchField(
                      fieldKey: const ValueKey('alt-search-field'),
                      controller: _ctrl,
                      placeholder: widget.hintText,
                      autofocus: true,
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: TpSpacing.s2),
                  FilledButton(
                    key: const ValueKey('alt-search-button'),
                    onPressed: _searching ? null : _search,
                    child: Text(_searching ? '搜尋中…' : '搜尋'),
                  ),
                ],
              ),
              const SizedBox(height: TpSpacing.s3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final poi in _results)
                      ListTile(
                        key: ValueKey('alt-result-${poi.placeId}'),
                        title: Text(poi.name),
                        subtitle: poi.address == null
                            ? null
                            : Text(poi.address!),
                        onTap: () => Navigator.of(
                          context,
                        ).pop(_EntryPoiPick.search(poi)),
                      ),
                  ],
                ),
              ),
            ] else if (_tab == _PoiPickerTab.favorites) ...[
              if (_favoritesLoading)
                const Padding(
                  padding: EdgeInsets.all(TpSpacing.s4),
                  child: CircularProgressIndicator(),
                )
              else if (_favoritesError != null)
                Padding(
                  padding: const EdgeInsets.all(TpSpacing.s4),
                  child: Text(_favoritesError!),
                )
              else if (_favoritesLoaded && _favorites.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(TpSpacing.s4),
                  child: Text('還沒有收藏景點'),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final favorite in _favorites)
                        ListTile(
                          key: ValueKey('poi-picker-favorite-${favorite.id}'),
                          title: Text(favorite.displayName),
                          subtitle: favorite.poiAddress == null
                              ? null
                              : Text(favorite.poiAddress!),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(_EntryPoiPick.favorite(favorite.poiId)),
                        ),
                    ],
                  ),
                ),
            ] else ...[
              TextField(
                key: const ValueKey('poi-picker-custom-name'),
                controller: _customNameCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '名稱',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_customError != null) setState(() => _customError = null);
                },
              ),
              const SizedBox(height: TpSpacing.s2),
              DropdownButtonFormField<String>(
                key: const ValueKey('poi-picker-custom-type'),
                initialValue: _customPoiType,
                decoration: const InputDecoration(
                  labelText: '類型',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final entry in kPoiTypeLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _customPoiType = value ?? _customPoiType),
              ),
              const SizedBox(height: TpSpacing.s2),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('poi-picker-custom-lat'),
                      controller: _customLatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '緯度',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (_customError != null) {
                          setState(() => _customError = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: TpSpacing.s2),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('poi-picker-custom-lng'),
                      controller: _customLngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '經度',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (_customError != null) {
                          setState(() => _customError = null);
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (_customError != null) ...[
                const SizedBox(height: TpSpacing.s2),
                Text(
                  _customError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: TpSpacing.s3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('poi-picker-custom-submit'),
                  onPressed: _submitCustom,
                  child: const Text('使用自訂地點'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
