import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../models/entry.dart';
import '../../models/poi_search_result.dart';
import '../../models/poi_type.dart';
import '../../theme/tokens.dart';
import '../favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;
import 'trip_providers.dart';

/// 地點管理全頁：正選切換、備選增刪、per-POI 備註/分類/訂位。
/// OCC = entryPoisVersion（string）;每次操作後重抓 entryDetail 取最新 token。
class EntryPoiScreen extends ConsumerWidget {
  const EntryPoiScreen({
    super.key,
    required this.tripId,
    required this.entryId,
  });

  final String tripId;
  final int entryId;

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
      showAppNotice(
        context,
        error.status == 409 ? '地點已更新，已重新載入' : '操作失敗，請稍後再試',
      );
    } on Exception {
      if (!context.mounted) return;
      showAppNotice(context, '操作失敗，請稍後再試');
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
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
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

    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        Text('正選地點', style: theme.textTheme.titleMedium),
        const SizedBox(height: TpSpacing.s2),
        if (entry.master != null)
          _PoiCard(
            poi: entry.master!,
            isMaster: true,
            trailing: TextButton(
              key: const ValueKey('poi-edit-master'),
              onPressed: () => _editPoiInfo(context, ref, entry.master!),
              child: const Text('編輯資訊'),
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
          for (final alt in entry.alternates)
            _PoiCard(
              poi: alt,
              isMaster: false,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    key: ValueKey('alt-setmaster-${alt.poiId}'),
                    onPressed: () => _run(
                      context,
                      ref,
                      () => repo.setEntryMaster(
                        tripId: tripId,
                        entryId: entryId,
                        poiId: alt.poiId,
                        entryPoisVersion: version,
                      ),
                      success: '已設為正選',
                      recomputeTravel: true,
                    ),
                    child: const Text('設為正選'),
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
            ),
      ],
    );
  }

  Future<void> _editPoiInfo(
    BuildContext context,
    WidgetRef ref,
    EntryPoiInfo poi,
  ) async {
    final result =
        await showAdaptiveDialog<({String? note, String type, String? reservation})>(
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

  Future<void> _addAlternate(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
  ) async {
    final selected = await showModalBottomSheet<PoiSearchResult>(
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
            poi: selected,
            entryPoisVersion: entry.entryPoisVersion,
          ),
      success: '已加入備選',
    );
  }
}

/// 正選/備選共用卡：名稱 + 分類 label + 評分 + 備註/訂位 + 尾端操作。
class _PoiCard extends StatelessWidget {
  const _PoiCard({
    required this.poi,
    required this.isMaster,
    required this.trailing,
  });

  final EntryPoiInfo poi;
  final bool isMaster;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
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
                    child: Text(
                      '訂位:${poi.reservation!}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
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

/// 加入備選的 POI 搜尋 sheet（複用探索的 poiRepositoryProvider.searchPois）。
class _AlternateSearchSheet extends ConsumerStatefulWidget {
  const _AlternateSearchSheet();

  @override
  ConsumerState<_AlternateSearchSheet> createState() =>
      _AlternateSearchSheetState();
}

class _AlternateSearchSheetState extends ConsumerState<_AlternateSearchSheet> {
  final _ctrl = TextEditingController();
  List<PoiSearchResult> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _ctrl.dispose();
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
                Expanded(
                  child: TextField(
                    key: const ValueKey('alt-search-field'),
                    controller: _ctrl,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(hintText: '搜尋地點加入備選'),
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
                      subtitle: poi.address == null ? null : Text(poi.address!),
                      onTap: () => Navigator.of(context).pop(poi),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
