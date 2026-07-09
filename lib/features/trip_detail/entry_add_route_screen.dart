import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/day.dart';
import '../../theme/tokens.dart';
import 'trip_providers.dart';
import 'widgets/entry_edit_sheet.dart';

/// Web 相容的自訂停留點新增頁，包裝既有 EntryEditSheet 新增模式。
class EntryAddRouteScreen extends ConsumerStatefulWidget {
  const EntryAddRouteScreen({
    super.key,
    required this.tripId,
    this.initialDayNum,
  });

  final String tripId;
  final int? initialDayNum;

  @override
  ConsumerState<EntryAddRouteScreen> createState() =>
      _EntryAddRouteScreenState();
}

class _EntryAddRouteScreenState extends ConsumerState<EntryAddRouteScreen> {
  int? _selectedDayNum;

  int _dayNumFor(List<TripDay> days) {
    final selected = _selectedDayNum ?? widget.initialDayNum;
    if (selected != null && days.any((day) => day.dayNum == selected)) {
      return selected;
    }
    return days.first.dayNum;
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
                      const SizedBox(height: TpSpacing.s2),
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
