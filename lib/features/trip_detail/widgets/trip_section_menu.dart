import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/tp_scope_menu.dart';

enum TripSection { itinerary, map, notes }

class TripSectionMenu extends StatelessWidget {
  const TripSectionMenu({
    super.key,
    required this.section,
    required this.tripId,
    this.onSectionSelected,
  });

  final TripSection section;
  final String tripId;
  final ValueChanged<TripSection>? onSectionSelected;

  String get _value => 'section:${section.name}';

  String get _label => switch (section) {
    TripSection.itinerary => '行程',
    TripSection.map => '地圖',
    TripSection.notes => '筆記',
  };

  List<TpScopeOption<String>> get _options => const [
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

  void _select(BuildContext context, String value) {
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
