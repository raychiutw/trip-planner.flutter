String humanAccountTime(String raw, {DateTime? now}) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final reference = now ?? DateTime.now();
  final difference = reference.toUtc().difference(parsed.toUtc());
  if (!difference.isNegative) {
    if (difference.inMinutes < 1) return '剛剛';
    if (difference.inHours < 1) return '${difference.inMinutes} 分鐘前';
    if (difference.inDays < 1) return '${difference.inHours} 小時前';
    if (difference.inDays < 7) return '${difference.inDays} 天前';
  }
  return _calendarDate(parsed.toLocal());
}

String humanEpochTime(int epochMilliseconds) {
  return _calendarDate(
    DateTime.fromMillisecondsSinceEpoch(epochMilliseconds).toLocal(),
  );
}

String _calendarDate(DateTime value) {
  return '${value.year}/${value.month}/${value.day}';
}
