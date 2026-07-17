import 'package:flutter/material.dart';

import '../../../models/day.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

/// 頂部橫向 day pills（DAY NN + 日期）；點擊以回呼通知捲動至該日。
class DayPills extends StatefulWidget {
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
  State<DayPills> createState() => _DayPillsState();
}

class _DayPillsState extends State<DayPills> {
  final Map<int, GlobalKey> _pillKeys = {};

  @override
  void initState() {
    super.initState();
    _syncKeys();
    _scheduleCenterActive();
  }

  @override
  void didUpdateWidget(covariant DayPills oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncKeys();
    if (oldWidget.activeDayNum != widget.activeDayNum ||
        oldWidget.days != widget.days) {
      _scheduleCenterActive();
    }
  }

  void _syncKeys() {
    final dayNums = widget.days.map((day) => day.dayNum).toSet();
    _pillKeys.removeWhere((dayNum, key) => !dayNums.contains(dayNum));
    for (final day in widget.days) {
      _pillKeys.putIfAbsent(day.dayNum, GlobalKey.new);
    }
  }

  void _scheduleCenterActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _pillKeys[widget.activeDayNum]?.currentContext;
      if (target == null) return;
      final renderObject = target.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: TpMotion.resolve(context, TpMotion.normal),
        curve: TpMotion.appleEase,
      );
    });
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: TpSpacing.s4,
          vertical: TpSpacing.s2,
        ),
        child: Row(
          children: [
            for (var index = 0; index < widget.days.length; index++) ...[
              if (index > 0) const SizedBox(width: TpSpacing.s2),
              _DayPill(
                key: _pillKeys[widget.days[index].dayNum],
                day: widget.days[index],
                isActive: widget.days[index].dayNum == widget.activeDayNum,
                onTap: () => widget.onDaySelected(widget.days[index].dayNum),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    super.key,
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
      key: ValueKey('day-pill-${day.dayNum}'),
      borderRadius: BorderRadius.circular(TpSpacing.tapMin / 2),
      onTap: onTap,
      child: Container(
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
