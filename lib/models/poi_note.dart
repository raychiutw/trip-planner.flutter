/// POI note helpers shared by Google Place add flows.
library;

const Map<String, String> _priceLevelSymbol = {
  'PRICE_LEVEL_FREE': '免費',
  'PRICE_LEVEL_INEXPENSIVE': '￥',
  'PRICE_LEVEL_MODERATE': '￥￥',
  'PRICE_LEVEL_EXPENSIVE': '￥￥￥',
  'PRICE_LEVEL_VERY_EXPENSIVE': '￥￥￥￥',
};

const List<String> _weekdayKeys = ['一', '二', '三', '四', '五'];
const List<String> _weekendKeys = ['六', '日'];

String priceLevelSymbol(String? level) {
  if (level == null || level.isEmpty) return '';
  return _priceLevelSymbol[level] ?? '';
}

String condenseHours(String? raw) {
  if (raw == null) return '';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  if (RegExp(r'^24\s*時間(?:営業)?$').hasMatch(trimmed)) {
    return '24 小時';
  }

  final parsed = _parseWeeklyHours(trimmed);
  if (parsed == null) return trimmed;

  final uniqueValues = parsed.values.toSet();
  if (uniqueValues.length == 1) {
    final value = uniqueValues.single;
    return RegExp(r'^24\s*時間(?:営業)?$').hasMatch(value) ? '24 小時' : value;
  }

  final weekdayValues = [
    for (final key in _weekdayKeys)
      if (parsed[key] != null) parsed[key]!,
  ];
  final weekendValues = [
    for (final key in _weekendKeys)
      if (parsed[key] != null) parsed[key]!,
  ];
  if (weekdayValues.length == 5 && weekendValues.length == 2) {
    final weekdaySet = weekdayValues.toSet();
    final weekendSet = weekendValues.toSet();
    if (weekdaySet.length == 1 && weekendSet.length == 1) {
      final weekday = weekdaySet.single;
      final weekend = weekendSet.single;
      if (weekday == weekend) return weekday;
      return '週一–五 $weekday · 週末 $weekend';
    }
  }

  return trimmed;
}

String? buildPoiNote({String? hoursRaw, String? priceLevel, String? address}) {
  final parts = <String>[];
  final hours = condenseHours(hoursRaw);
  if (hours.isNotEmpty) parts.add('營業 $hours');
  final price = priceLevelSymbol(priceLevel);
  if (price.isNotEmpty) parts.add('消費 $price');
  final trimmedAddress = address?.trim();
  if (trimmedAddress != null && trimmedAddress.isNotEmpty) {
    parts.add(trimmedAddress);
  }
  return parts.isEmpty ? null : parts.join('\n');
}

Map<String, String>? _parseWeeklyHours(String raw) {
  final flat = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  final re = RegExp(r'(?:星期[一二三四五六日天])\s*:?\s*(.+?)(?=\s*星期[一二三四五六日天]|$)');
  final matches = re.allMatches(flat).toList();
  if (matches.length < 5) return null;

  final result = <String, String>{};
  final dayRe = RegExp(r'星期([一二三四五六日天])');
  for (final match in matches) {
    final fullMatch = match.group(0);
    final value = match.group(1);
    if (fullMatch == null || value == null) continue;
    final day = dayRe.firstMatch(fullMatch)?.group(1);
    if (day == null) continue;
    result[day == '天' ? '日' : day] = value.trim();
  }
  return result.length >= 5 ? result : null;
}
