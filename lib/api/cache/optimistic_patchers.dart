/// 樂觀 patcher:純函式 `(cachedJson, args) → patchedJson`,離線寫入即時反映用。
///
/// 操作對象是 ApiClient 快取的「原始 wire JSON」。entry 系列操作的是
/// `GET /trips/:id/days?all=1` 的 `List<day>`(每個 day 有 `dayNum` 與 `timeline`)。
/// 一律回傳新結構、不就地改原 cached(避免污染共用的快取物件)。
library;

typedef OptimisticPatcher =
    Object? Function(Object? cached, Map<String, dynamic> args);

/// 樂觀 entry 的 sortOrder:遠大於任何真實 sortOrder,確保 UI 排在當天末端。
const int _kOptimisticSortOrder = 1 << 30;

const Map<String, OptimisticPatcher> _patchers = {
  'entry.add': _entryAdd,
  'entry.update': _entryUpdate,
  'entry.delete': _entryDelete,
  'note.create': _noteCreate,
  'note.update': _noteUpdate,
  'note.delete': _noteDelete,
};

/// 套用樂觀 patch;查無 type 或 base 無法處理 → 回原 cached。
Object? applyOptimisticPatch(
  String type,
  Object? cached,
  Map<String, dynamic> args,
) {
  final patcher = _patchers[type];
  return patcher == null ? cached : patcher(cached, args);
}

Map<String, dynamic> _asMap(Object? o) => Map<String, dynamic>.from(o as Map);

/// 在指定 dayNum 的 timeline 末端插入一筆樂觀 entry(臨時負 id)。
Object? _entryAdd(Object? cached, Map<String, dynamic> args) {
  if (cached is! List) return cached;
  final dayNum = args['dayNum'];
  final newEntry = _buildOptimisticEntry(args);
  return [
    for (final day in cached)
      if (day is Map && day['dayNum'] == dayNum)
        {
          ..._asMap(day),
          'timeline': [...?(day['timeline'] as List?), newEntry],
        }
      else
        day,
  ];
}

/// 跨 day 找 entryId,merge 可編輯欄位。
Object? _entryUpdate(Object? cached, Map<String, dynamic> args) {
  if (cached is! List) return cached;
  final entryId = args['entryId'];
  final fields = _entryUpdateFields(args);
  return [
    for (final day in cached)
      if (day is Map && day['timeline'] is List)
        {
          ..._asMap(day),
          'timeline': [
            for (final e in (day['timeline'] as List))
              if (e is Map && e['id'] == entryId)
                {..._asMap(e), ...fields}
              else
                e,
          ],
        }
      else
        day,
  ];
}

/// 跨 day 移除 entryId。
Object? _entryDelete(Object? cached, Map<String, dynamic> args) {
  if (cached is! List) return cached;
  final entryId = args['entryId'];
  return [
    for (final day in cached)
      if (day is Map && day['timeline'] is List)
        {
          ..._asMap(day),
          'timeline': [
            for (final e in (day['timeline'] as List))
              if (!(e is Map && e['id'] == entryId)) e,
          ],
        }
      else
        day,
  ];
}

Map<String, dynamic> _buildOptimisticEntry(Map<String, dynamic> args) {
  // 臨時負 id:正常路徑由 sendMutation 在入佇列時產生並存進 args(冪等、不碰撞);
  // 此處 fallback 僅供直接呼叫 patcher 的情況。PR-4 flush 成功後 evict+refetch 換 server id。
  final tempId =
      (args['tempId'] as int?) ?? -DateTime.now().microsecondsSinceEpoch;
  final lat = args['lat'];
  final lng = args['lng'];
  return {
    'id': tempId,
    'sortOrder': _kOptimisticSortOrder,
    'title': args['title'],
    'description': args['description'],
    'startTime': args['startTime'],
    'endTime': args['endTime'],
    'time': args['startTime'],
    'version': 0,
    'travel': null,
    'master': (lat != null && lng != null)
        ? {
            'poiId': tempId,
            'name': args['title'],
            'lat': lat,
            'lng': lng,
            'type': args['poiType'],
            'sortOrder': 0,
          }
        : null,
    'alternates': <dynamic>[],
  };
}

Map<String, dynamic> _entryUpdateFields(Map<String, dynamic> args) => {
  if (args.containsKey('title')) 'title': args['title'],
  if (args.containsKey('description')) 'description': args['description'],
  if (args.containsKey('startTime')) ...{
    'startTime': args['startTime'],
    'time': args['startTime'],
  },
  if (args.containsKey('endTime')) 'endTime': args['endTime'],
};

// ── notes ──────────────────────────────────────────────────────────────────
// 操作 `GET /trips/:id/notes` 的 Map(key 為 response 段名:flights/lodgings/
// reservations/pretripNotes/emergencyContacts)。fields 是 request 的 snake_case,
// 樂觀 row 需轉 camelCase 對齊 wire(轉換對已是 camelCase 的 key 為 no-op)。

/// 在指定段末端插入一筆樂觀 note(臨時負 id)。
Object? _noteCreate(Object? cached, Map<String, dynamic> args) {
  if (cached is! Map) return cached;
  final sectionKey = args['sectionKey'] as String;
  final tempId =
      (args['tempId'] as int?) ?? -DateTime.now().microsecondsSinceEpoch;
  final row = {
    'id': tempId,
    'sortOrder': _kOptimisticSortOrder,
    'version': 0,
    ..._camelKeys(args['fields'] as Map),
  };
  final section = (cached[sectionKey] as List?) ?? const [];
  return {
    ..._asMap(cached),
    sectionKey: [...section, row],
  };
}

/// 在指定段找 rowId,merge 欄位。
Object? _noteUpdate(Object? cached, Map<String, dynamic> args) {
  if (cached is! Map) return cached;
  final sectionKey = args['sectionKey'] as String;
  final rowId = args['rowId'];
  final section = cached[sectionKey];
  if (section is! List) return cached;
  final fields = _camelKeys(args['fields'] as Map);
  return {
    ..._asMap(cached),
    sectionKey: [
      for (final r in section)
        if (r is Map && r['id'] == rowId) {..._asMap(r), ...fields} else r,
    ],
  };
}

/// 在指定段移除 rowId。
Object? _noteDelete(Object? cached, Map<String, dynamic> args) {
  if (cached is! Map) return cached;
  final sectionKey = args['sectionKey'] as String;
  final rowId = args['rowId'];
  final section = cached[sectionKey];
  if (section is! List) return cached;
  return {
    ..._asMap(cached),
    sectionKey: [
      for (final r in section)
        if (!(r is Map && r['id'] == rowId)) r,
    ],
  };
}

Map<String, dynamic> _camelKeys(Map<dynamic, dynamic> src) => {
  for (final e in src.entries) _snakeToCamel(e.key as String): e.value,
};

String _snakeToCamel(String s) {
  final parts = s.split('_');
  if (parts.length == 1) return s;
  return parts.first +
      parts
          .skip(1)
          .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
          .join();
}
