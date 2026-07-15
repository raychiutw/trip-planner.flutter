import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../../../models/day.dart';
import '../../../ui/tp_scope_menu.dart';

enum TripSection { itinerary, map, notes }

class TripSectionMenu extends StatelessWidget {
  const TripSectionMenu({
    super.key,
    required this.section,
    required this.tripId,
    this.days = const [],
    this.selectedDayIndex = 0,
    this.onSectionSelected,
    this.onDaySelected,
  });

  final TripSection section;
  final String tripId;
  final List<TripDay> days;

  /// 0 為總覽，1..N 對應 [days] 的索引 + 1。
  final int selectedDayIndex;
  final ValueChanged<TripSection>? onSectionSelected;
  final ValueChanged<int>? onDaySelected;

  String get _value => section == TripSection.map
      ? 'day:$selectedDayIndex'
      : 'section:${section.name}';

  String get _label {
    if (section == TripSection.itinerary) return '行程';
    if (section == TripSection.notes) return '筆記';
    if (selectedDayIndex == 0 || selectedDayIndex > days.length) {
      return '地圖 · 總覽';
    }
    final day = days[selectedDayIndex - 1];
    return '地圖 · DAY ${day.dayNum.toString().padLeft(2, '0')}';
  }

  List<TpScopeOption<String>> get _options {
    if (section == TripSection.map) {
      return [
        const TpScopeOption(
          value: 'section:itinerary',
          label: '行程',
          icon: CupertinoIcons.list_bullet,
          key: ValueKey('trip-section-itinerary'),
        ),
        const TpScopeOption(
          value: 'section:notes',
          label: '筆記',
          icon: CupertinoIcons.doc_text,
          key: ValueKey('trip-section-notes'),
        ),
        const TpScopeOption(
          value: 'day:0',
          label: '地圖 · 總覽',
          icon: CupertinoIcons.map,
          key: ValueKey('trip-section-day-overview'),
        ),
        for (final (index, day) in days.indexed)
          TpScopeOption(
            value: 'day:${index + 1}',
            label: 'DAY ${day.dayNum.toString().padLeft(2, '0')}',
            icon: CupertinoIcons.location,
            key: ValueKey('trip-section-day-${day.dayNum}'),
          ),
      ];
    }
    return const [
      TpScopeOption(
        value: 'section:itinerary',
        label: '行程',
        icon: CupertinoIcons.list_bullet,
        key: ValueKey('trip-section-itinerary'),
      ),
      TpScopeOption(
        value: 'section:map',
        label: '地圖',
        icon: CupertinoIcons.map,
        key: ValueKey('trip-section-map'),
      ),
      TpScopeOption(
        value: 'section:notes',
        label: '筆記',
        icon: CupertinoIcons.doc_text,
        key: ValueKey('trip-section-notes'),
      ),
    ];
  }

  void _select(BuildContext context, String value) {
    if (value.startsWith('day:')) {
      final index = int.parse(value.substring(4));
      onDaySelected?.call(index);
      return;
    }
    final selected = TripSection.values.byName(value.substring(8));
    if (onSectionSelected != null) {
      onSectionSelected!(selected);
      return;
    }
    final encodedTripId = Uri.encodeComponent(tripId);
    final location = switch (selected) {
      TripSection.itinerary => '/trips/$encodedTripId',
      TripSection.map => '/trips/$encodedTripId/map',
      TripSection.notes => '/trips/$encodedTripId/notes',
    };
    GoRouter.maybeOf(context)?.go(location);
  }

  @override
  Widget build(BuildContext context) {
    return TpScopeMenu<String>(
      key: const ValueKey('trip-section-scope'),
      label: _label,
      value: _value,
      options: _options,
      onSelected: (value) => _select(context, value),
    );
  }
}
