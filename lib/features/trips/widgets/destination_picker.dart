/// 目的地編輯器(建立/編輯共用):POI 搜尋 + 熱門 chips + 已選清單(拖曳/移除)。
/// 自管搜尋狀態;透過 callback 回報加入/移除/排序。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/adaptive.dart';
import '../../../models/destination_input.dart';
import '../../../models/poi_search_result.dart';
import '../../../theme/tokens.dart';
import '../../favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;

const _hotDestinations = ['沖繩', '東京', '京都', '首爾', '曼谷', '台北'];

class DestinationPicker extends ConsumerStatefulWidget {
  const DestinationPicker({
    super.key,
    required this.destinations,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  final List<DestinationInput> destinations;
  final void Function(DestinationInput) onAdd;
  final void Function(int) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  ConsumerState<DestinationPicker> createState() => _DestinationPickerState();
}

class _DestinationPickerState extends ConsumerState<DestinationPicker> {
  final _search = TextEditingController();
  List<PoiSearchResult> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _search.text.trim();
    if (q.length < 2) return;
    setState(() => _searching = true);
    try {
      final r = await ref
          .read(poiRepositoryProvider)
          .searchPois(q: q, region: '全部地區');
      if (mounted) setState(() => _results = r);
    } on Exception {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pick(PoiSearchResult p) {
    widget.onAdd(DestinationInput.fromPoi(p));
    _search.clear();
    setState(() => _results = const []);
  }

  @override
  Widget build(BuildContext context) {
    final dests = widget.destinations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                fieldKey: const ValueKey('dest-poi-search'),
                controller: _search,
                placeholder: '搜尋地點（城市、景點）',
                onSubmitted: (_) => _run(),
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            IconButton.filled(
              key: const ValueKey('dest-poi-search-btn'),
              tooltip: '搜尋地點',
              onPressed: _run,
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: TpSpacing.s2),
          child: Wrap(
            spacing: TpSpacing.s2,
            children: [
              for (final h in _hotDestinations)
                ActionChip(
                  label: Text(h),
                  onPressed: () => widget.onAdd(DestinationInput(name: h)),
                ),
            ],
          ),
        ),
        if (_results.isNotEmpty)
          ..._results
              .take(8)
              .map(
                (r) => ListTile(
                  dense: true,
                  key: ValueKey('poi-result-${r.placeId}'),
                  title: Text(r.name),
                  subtitle: r.address == null ? null : Text(r.address!),
                  trailing: const Icon(CupertinoIcons.add),
                  onTap: () => _pick(r),
                ),
              ),
        if (dests.isNotEmpty)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorderItem: widget.onReorder,
            children: [
              for (var i = 0; i < dests.length; i++)
                ListTile(
                  key: ValueKey('dest-$i-${dests[i].name}'),
                  leading: const Icon(CupertinoIcons.location_solid),
                  title: Text(dests[i].name),
                  trailing: IconButton(
                    tooltip: '移除 ${dests[i].name}',
                    icon: const Icon(CupertinoIcons.xmark),
                    onPressed: () => widget.onRemove(i),
                  ),
                ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TpSpacing.s2),
            child: Text(
              '至少選 1 個目的地',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
