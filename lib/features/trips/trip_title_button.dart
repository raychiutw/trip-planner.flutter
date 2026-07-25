import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/adaptive.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';

/// 下拉箭頭相對標題的不透明度 —— 次要提示，比標題淡一階。
const double _chevronOpacity = 0.6;

/// AppBar 內的目前行程標題；點擊後以 HIG sheet 切換行程。
class TripTitleButton extends StatelessWidget {
  const TripTitleButton({
    super.key,
    required this.currentTripId,
    required this.currentTitle,
    required this.trips,
    required this.onSelected,
  });

  final String currentTripId;
  final String currentTitle;
  final List<TripSummary> trips;
  final ValueChanged<String> onSelected;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showAppSelectionSheet<String>(
      context,
      title: '切換行程',
      builder: (sheetContext, select) => _TripPickerSheet(
        currentTripId: currentTripId,
        trips: trips,
        onSelected: select,
      ),
    );
    if (selected != null && selected != currentTripId) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final hasTrips = trips.isNotEmpty;
    final canSelect = trips.length > 1;
    // 跟著所在 bar 的前景色，媒體背景上才不會變成讀不到的暗色。
    final foreground = IconTheme.of(context).color;
    return Semantics(
      key: const ValueKey('trip-title-button'),
      container: true,
      button: true,
      enabled: canSelect,
      label: '目前行程',
      value: currentTitle,
      hint: canSelect
          ? '點兩下切換行程'
          : hasTrips
          ? '只有一個行程'
          : null,
      onTap: canSelect ? () => _openPicker(context) : null,
      excludeSemantics: true,
      child: TextButton(
        onPressed: canSelect ? () => _openPicker(context) : null,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: const Size(44, 44),
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                currentTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (canSelect) ...[
              const SizedBox(width: TpSpacing.s1),
              // 箭頭是次要提示，比標題淡一階，讓標題看得出可點；沿用 bar 的
              // 前景色再降階，媒體背景與一般背景都成立。
              Icon(
                CupertinoIcons.chevron_down,
                size: 14,
                color: foreground?.withValues(alpha: _chevronOpacity),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripPickerSheet extends StatefulWidget {
  const _TripPickerSheet({
    required this.currentTripId,
    required this.trips,
    required this.onSelected,
  });

  final String currentTripId;
  final List<TripSummary> trips;
  final ValueChanged<String> onSelected;

  @override
  State<_TripPickerSheet> createState() => _TripPickerSheetState();
}

class _TripPickerSheetState extends State<_TripPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _title(TripSummary trip) {
    final title = trip.title?.trim();
    return title == null || title.isEmpty ? trip.name : title;
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final trips = query.isEmpty
        ? widget.trips
        : widget.trips
              .where(
                (trip) =>
                    _title(trip).toLowerCase().contains(query) ||
                    trip.name.toLowerCase().contains(query),
              )
              .toList();
    final colors = Theme.of(context).colorScheme;

    return Column(
      key: const ValueKey('trip-picker-sheet'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
          child: TextField(
            key: const ValueKey('trip-picker-search'),
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: '搜尋行程',
              prefixIcon: Icon(CupertinoIcons.search),
            ),
          ),
        ),
        const SizedBox(height: TpSpacing.s4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
          child: Text(
            '最近的行程',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: TpSpacing.s2),
        Expanded(
          child: trips.isEmpty
              ? Center(
                  child: Text(
                    '找不到行程',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: trips.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 56,
                    color: colors.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    final selected = trip.tripId == widget.currentTripId;
                    final meta = [
                      if (trip.countries?.trim().isNotEmpty ?? false)
                        trip.countries!.trim(),
                      if (trip.totalDays != null) '${trip.totalDays} 天',
                    ].join(' · ');
                    return ListTile(
                      key: ValueKey('trip-picker-item-${trip.tripId}'),
                      selected: selected,
                      minTileHeight: 56,
                      leading: Icon(
                        CupertinoIcons.map,
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      title: Text(_title(trip)),
                      subtitle: meta.isEmpty ? null : Text(meta),
                      trailing: selected
                          ? Icon(
                              CupertinoIcons.check_mark,
                              color: colors.primary,
                            )
                          : null,
                      onTap: () => widget.onSelected(trip.tripId),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
