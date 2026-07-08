import 'package:flutter/material.dart';

import '../../../models/day.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

/// 頂部橫向 day pills（DAY NN + 日期）；點擊以回呼通知捲動至該日。
class DayPills extends StatelessWidget {
  const DayPills({
    super.key,
    required this.days,
    required this.activeDayNum,
    required this.onDaySelected,
  });

  final List<TripDay> days;
  final int activeDayNum;
  final ValueChanged<int> onDaySelected;

  /// "YYYY-MM-DD" → "M/D"；解析失敗回原字串。
  static String shortDate(String? date) {
    if (date == null) return '';
    final parts = date.split('-');
    if (parts.length < 3) return date;
    final month = int.tryParse(parts[1]);
    final dayOfMonth = int.tryParse(parts[2]);
    if (month == null || dayOfMonth == null) return date;
    return '$month/$dayOfMonth';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 60,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: TpSpacing.s4,
          vertical: TpSpacing.s2,
        ),
        itemCount: days.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: TpSpacing.s2),
        itemBuilder: (context, index) => _DayPill(
          day: days[index],
          isActive: days[index].dayNum == activeDayNum,
          onTap: () => onDaySelected(days[index].dayNum),
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.isActive,
    required this.onTap,
  });

  final TripDay day;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;

    return InkWell(
      borderRadius: BorderRadius.circular(TpSpacing.tapMin / 2),
      onTap: onTap,
      child: Container(
        key: ValueKey('day-pill-${day.dayNum}'),
        constraints: const BoxConstraints(
          minHeight: TpSpacing.tapMin,
          minWidth: 64,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? tones.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(TpSpacing.tapMin / 2),
          border: Border.all(
            color: isActive ? tones.accent : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'DAY ${day.dayNum.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 11,
                // 兩行文字需塞進 44px tap target 的內容區，行高固定避免 overflow
                height: 1.35,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: isActive
                    ? tones.accentDeep
                    : theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              DayPills.shortDate(day.date),
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
