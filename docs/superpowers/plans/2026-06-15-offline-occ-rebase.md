# 離線寫 OCC 409 三方 merge rebase 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** flush 重播離線佇列遇 OCC 409 `STALE_ENTRY` 時自動 rebase 到 server 最新版本,只有同欄位真衝突才交使用者整筆二選一,杜絕離線編輯遺失。

**Architecture:** 三方 merge 純函式判斷衝突(後端 PATCH diff-only → 重送永遠是「原離線欄位 + 新 version」);真衝突存獨立持久化 conflict store,banner 點開 bottom sheet 逐筆解決。範圍只 `entry.update` + `note.update`。

**Tech Stack:** Dart/Flutter、dio、riverpod 3.x、sembast、flutter_test + mocktail + http_mock_adapter。

設計來源:`docs/superpowers/specs/2026-06-15-offline-occ-rebase-design.md`(已過 plan-eng-review,A1/A2/A3/C1/P1 已 fold)。

---

## File Structure

| 檔案 | 動作 | 責任 |
|---|---|---|
| `lib/api/cache/rebase_merge.dart` | 建立 | 三方 merge 純函式 + 型別正規化 + entry/note 欄位擷取 helper(base/theirs 共用) |
| `lib/api/cache/cache_store.dart` | 改 | `QueuedMutation` 加 `base`;新增 `ConflictRecord`;`CacheStore` 加 conflict store 介面;`InMemoryCacheStore` 實作 |
| `lib/api/cache/sembast_cache_store.dart` | 改 | conflict store 持久化(intMapStore，照 queue 模式) |
| `lib/api/api_client.dart` | 改 | `_send` 加 `writeCache`(A2);`sendMutation` 擷取 base;`flushQueue` STALE 分支 + `_tryRebase`(P1 去重);`resolveConflictKeepOurs/KeepTheirs`(A3) |
| `lib/features/offline/offline_sync.dart` | 改 | `syncConflictRecordsProvider` 取代 `syncConflictsProvider`(A1) |
| `lib/features/offline/offline_status_banner.dart` | 改 | 衝突態點開 bottom sheet |
| `lib/features/offline/conflict_resolve_sheet.dart` | 建立 | 逐筆「保留你的 / 用對方的」bottom sheet |

測試鏡像:`test/api/rebase_merge_test.dart`、`test/api/cache_store_test.dart`(若無則併入 api_client_test)、`test/api/api_client_test.dart`、`test/api/trip_repository_test.dart`、`test/features/offline/*`。

---

## Task 1: rebase_merge 純函式(含 C1 型別正規化)

**Files:**
- Create: `lib/api/cache/rebase_merge.dart`
- Test: `test/api/rebase_merge_test.dart`

- [ ] **Step 1: 寫失敗測試**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/rebase_merge.dart';

void main() {
  group('rebaseMerge', () {
    test('server 沒動該欄(theirs==base)→ 無衝突', () {
      expect(
        rebaseMerge({'title': 'A'}, {'title': 'B'}, {'title': 'A'}),
        isEmpty,
      );
    });
    test('離線與 server 同值(ours==theirs)→ 無衝突', () {
      expect(
        rebaseMerge({'title': 'A'}, {'title': 'B'}, {'title': 'B'}),
        isEmpty,
      );
    });
    test('三方不同 → 衝突欄位', () {
      expect(
        rebaseMerge({'title': 'A'}, {'title': 'B'}, {'title': 'C'}),
        ['title'],
      );
    });
    test('多欄位混合 → 只回衝突欄位', () {
      final r = rebaseMerge(
        {'title': 'A', 'description': 'x'},
        {'title': 'B', 'description': 'y'},
        {'title': 'A', 'description': 'z'}, // title server 沒動;description 三方不同
      );
      expect(r, ['description']);
    });
    test('base==null → 無衝突(降級 last-write-wins)', () {
      expect(rebaseMerge(null, {'title': 'B'}, {'title': 'C'}), isEmpty);
    });
    test('[C1] int vs double 同值 → 不誤判衝突', () {
      // base int 5、ours 改成 7、theirs server 仍 5.0(沒動)→ 安全採 ours,無衝突
      expect(rebaseMerge({'min': 5}, {'min': 7}, {'min': 5.0}), isEmpty);
    });
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/api/rebase_merge_test.dart`
Expected: FAIL（`rebase_merge.dart` 不存在 / `rebaseMerge` 未定義）

- [ ] **Step 3: 實作**

```dart
/// 三方 merge：回傳離線(ours)改過的欄位中,與 server(theirs)真衝突的欄位名。
/// 空 list = 可自動 rebase。base==null → 降級 last-write-wins(視為無衝突)。
library;

List<String> rebaseMerge(
  Map<String, dynamic>? base,
  Map<String, dynamic> ours,
  Map<String, dynamic> theirs,
) {
  if (base == null) return const [];
  final conflicts = <String>[];
  for (final f in ours.keys) {
    final b = _norm(base[f]);
    final t = _norm(theirs[f]);
    final o = _norm(ours[f]);
    if (b == t) continue; // server 沒動該欄 → 安全採 ours
    if (o == t) continue; // 剛好同值 → 無衝突
    conflicts.add(f); // base/ours/theirs 三方不同 → 真衝突
  }
  return conflicts;
}

/// [C1] 型別正規化:wire 數字可能 int 或 double,統一轉 double 再比;其餘原樣。
Object? _norm(Object? v) => v is num ? v.toDouble() : v;
```

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/api/rebase_merge_test.dart`
Expected: PASS（6 tests）

- [ ] **Step 5: Commit**

```bash
git add lib/api/cache/rebase_merge.dart test/api/rebase_merge_test.dart
git commit -m "feat: OCC rebase 三方 merge 純函式(含型別正規化)"
```

---

## Task 2: entry/note 欄位擷取 helper(base/theirs 共用)

擷取「某 entry/note 的指定欄位值 + version」,base 擷取(入佇列)與 theirs 擷取(重抓)共用。camelCase 輸出。

**Files:**
- Modify: `lib/api/cache/rebase_merge.dart`
- Test: `test/api/rebase_merge_test.dart`

- [ ] **Step 1: 寫失敗測試**(append 到 rebase_merge_test.dart main())

```dart
  group('extractEntryFields', () {
    final days = [
      {'dayNum': 1, 'timeline': [
        {'id': 7, 'title': '舊標題', 'description': 'd', 'startTime': '09:00',
         'endTime': '10:00', 'version': 3},
      ]},
    ];
    test('找到 entry → 取指定欄位 + version(camelCase)', () {
      final r = extractEntryFields(days, 7, ['title', 'startTime']);
      expect(r, {'title': '舊標題', 'startTime': '09:00', 'version': 3});
    });
    test('找不到 entry → null', () {
      expect(extractEntryFields(days, 999, ['title']), isNull);
    });
    test('cached 非 List → null', () {
      expect(extractEntryFields(null, 7, ['title']), isNull);
    });
  });

  group('extractNoteFields', () {
    final notes = {
      'pretripNotes': [
        {'id': 5, 'content': '舊內容', 'version': 2},
      ],
    };
    test('找到 note row → 取欄位 + version', () {
      final r = extractNoteFields(notes, 'pretripNotes', 5, ['content']);
      expect(r, {'content': '舊內容', 'version': 2});
    });
    test('段不存在 → null', () {
      expect(extractNoteFields(notes, 'flights', 5, ['content']), isNull);
    });
  });
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/api/rebase_merge_test.dart`
Expected: FAIL（`extractEntryFields` 未定義）

- [ ] **Step 3: 實作**(append 到 rebase_merge.dart)

```dart
/// 從 days 快取(List<day>)跨 day 找 timeline 內 id==entryId 的 row,
/// 取出 [fields] 各欄位 + `version`(camelCase wire)。找不到 → null。
Map<String, dynamic>? extractEntryFields(
  Object? cachedDays,
  int entryId,
  List<String> fields,
) {
  if (cachedDays is! List) return null;
  for (final day in cachedDays) {
    final timeline = (day is Map) ? day['timeline'] : null;
    if (timeline is! List) continue;
    for (final row in timeline) {
      if (row is Map && row['id'] == entryId) {
        return _pick(row, fields);
      }
    }
  }
  return null;
}

/// 從 notes 快取(Map<段名, List<row>>)的 [sectionKey] 段找 id==rowId 的 row,
/// 取出 [fields] + `version`。找不到 → null。
Map<String, dynamic>? extractNoteFields(
  Object? cachedNotes,
  String sectionKey,
  int rowId,
  List<String> fields,
) {
  if (cachedNotes is! Map) return null;
  final section = cachedNotes[sectionKey];
  if (section is! List) return null;
  for (final row in section) {
    if (row is Map && row['id'] == rowId) {
      return _pick(row, fields);
    }
  }
  return null;
}

Map<String, dynamic> _pick(Map row, List<String> fields) => {
  for (final f in fields)
    if (row.containsKey(f)) f: row[f],
  if (row.containsKey('version')) 'version': row['version'],
};
```

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/api/rebase_merge_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/api/cache/rebase_merge.dart test/api/rebase_merge_test.dart
git commit -m "feat: entry/note 欄位擷取 helper(base/theirs 共用)"
```

---

## Task 3: QueuedMutation 加 base 欄位

**Files:**
- Modify: `lib/api/cache/cache_store.dart:17-63`
- Test: `test/api/cache_store_test.dart`（若不存在則建立）

- [ ] **Step 1: 寫失敗測試**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_store.dart';

void main() {
  group('QueuedMutation base 序列化', () {
    test('toMap/fromMap round-trip 保留 base', () {
      const m = QueuedMutation(
        id: '1', method: 'PATCH', path: '/x', type: 'entry.update',
        cacheKey: 'k', args: {}, createdAt: 't',
        base: {'title': '舊'},
      );
      final back = QueuedMutation.fromMap(m.toMap());
      expect(back.base, {'title': '舊'});
    });
    test('舊資料缺 base → null(降級不崩)', () {
      final back = QueuedMutation.fromMap(const {
        'id': '1', 'method': 'PATCH', 'path': '/x', 'type': 'entry.update',
        'cacheKey': 'k', 'args': <String, dynamic>{}, 'createdAt': 't',
      });
      expect(back.base, isNull);
    });
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/api/cache_store_test.dart`
Expected: FAIL（`base` 具名參數不存在）

- [ ] **Step 3: 實作** — 在 `QueuedMutation` 加欄位

加建構參數 `this.base,`、欄位 `final Map<String, dynamic>? base;`、`toMap()` 加 `'base': base,`、`fromMap` 加 `base: (m['base'] as Map?)?.cast<String, dynamic>(),`。

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/api/cache_store_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/api/cache/cache_store.dart test/api/cache_store_test.dart
git commit -m "feat: QueuedMutation 加 base(rebase 三方比對用)"
```

---

## Task 4: ConflictRecord + conflict store(介面 + InMemory)

**Files:**
- Modify: `lib/api/cache/cache_store.dart`
- Test: `test/api/cache_store_test.dart`

- [ ] **Step 1: 寫失敗測試**(append)

```dart
  group('InMemoryCacheStore conflict store', () {
    ConflictRecord rec(String id) => ConflictRecord(
      id: id, type: 'entry.update', path: '/trips/t/entries/7',
      body: const {'title': 'B'}, args: const {'entryId': 7},
      cacheKey: 'k', ours: const {'title': 'B'}, theirs: const {'title': 'C'},
      newVersion: 5, conflictFields: const ['title'], createdAt: 't',
    );
    test('append → read 回該筆;remove 後消失', () async {
      final s = InMemoryCacheStore();
      await s.appendConflict(rec('a'));
      expect((await s.readConflicts()).map((c) => c.id), ['a']);
      await s.removeConflict('a');
      expect(await s.readConflicts(), isEmpty);
    });
    test('append/remove 觸發 changes', () async {
      final s = InMemoryCacheStore();
      final seen = <void>[];
      final sub = s.changes.listen(seen.add);
      await s.appendConflict(rec('a'));
      await s.removeConflict('a');
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, 2);
      await sub.cancel();
    });
    test('clear 一併清 conflict store', () async {
      final s = InMemoryCacheStore();
      await s.appendConflict(rec('a'));
      await s.clear();
      expect(await s.readConflicts(), isEmpty);
    });
    test('ConflictRecord toMap/fromMap round-trip', () {
      final back = ConflictRecord.fromMap(rec('a').toMap());
      expect(back.id, 'a');
      expect(back.conflictFields, ['title']);
      expect(back.newVersion, 5);
    });
  });
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/api/cache_store_test.dart`
Expected: FAIL（`ConflictRecord` / `appendConflict` 未定義）

- [ ] **Step 3: 實作**

在 cache_store.dart 加 `ConflictRecord`（含 toMap/fromMap，與 QueuedMutation 同風格）:

```dart
/// 一筆待使用者解決的同步衝突(真衝突:同欄位 base/ours/theirs 三方不同)。
class ConflictRecord {
  const ConflictRecord({
    required this.id,
    required this.type,
    required this.path,
    required this.body,
    required this.args,
    required this.cacheKey,
    required this.ours,
    required this.theirs,
    required this.newVersion,
    required this.conflictFields,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String path;
  final Object? body; // 原始離線 body(選「你的」重送用)
  final Map<String, dynamic> args;
  final String cacheKey;
  final Map<String, dynamic> ours; // 你的版本(離線值)
  final Map<String, dynamic> theirs; // 對方版本(server 最新)
  final int newVersion; // 重抓到的 server version
  final List<String> conflictFields;
  final String createdAt;

  Map<String, Object?> toMap() => {
    'id': id, 'type': type, 'path': path, 'body': body, 'args': args,
    'cacheKey': cacheKey, 'ours': ours, 'theirs': theirs,
    'newVersion': newVersion, 'conflictFields': conflictFields,
    'createdAt': createdAt,
  };

  factory ConflictRecord.fromMap(Map<String, Object?> m) => ConflictRecord(
    id: m['id'] as String,
    type: m['type'] as String,
    path: m['path'] as String,
    body: m['body'],
    args: (m['args'] as Map).cast<String, dynamic>(),
    cacheKey: m['cacheKey'] as String,
    ours: (m['ours'] as Map).cast<String, dynamic>(),
    theirs: (m['theirs'] as Map).cast<String, dynamic>(),
    newVersion: (m['newVersion'] as num).toInt(),
    conflictFields: (m['conflictFields'] as List).cast<String>(),
    createdAt: m['createdAt'] as String,
  );
}
```

在 `CacheStore` 抽象加三個方法:

```dart
  // 衝突區(待使用者解決;1A 獨立於主佇列)
  Future<List<ConflictRecord>> readConflicts();
  Future<void> appendConflict(ConflictRecord conflict);
  Future<void> removeConflict(String id);
```

在 `InMemoryCacheStore` 加 `final List<ConflictRecord> _conflicts = [];` 與實作(append/read/remove 各 `_changes.add(null)`),並在 `clear()` 加 `_conflicts.clear();`。

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/api/cache_store_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/api/cache/cache_store.dart test/api/cache_store_test.dart
git commit -m "feat: ConflictRecord + conflict store 介面(InMemory)"
```

---

## Task 5: SembastCacheStore conflict store 持久化

**Files:**
- Modify: `lib/api/cache/sembast_cache_store.dart`

（測試走 InMemoryCacheStore，依 CLAUDE.md 測試慣例不碰 sembast；本 task 為實作對齊，無新單元測試。）

- [ ] **Step 1: 實作** — 照 `_queueStore` 模式加 conflict store

加欄位:
```dart
  final StoreRef<int, Map<String, Object?>> _conflictStore =
      intMapStoreFactory.store('conflict_store');
```

加實作（照 queue 的 find/add/delete 模式）:
```dart
  @override
  Future<List<ConflictRecord>> readConflicts() async {
    final records = await _conflictStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder(Field.key)]),
    );
    return List.unmodifiable(
      records.map((r) => ConflictRecord.fromMap(r.value)),
    );
  }

  @override
  Future<void> appendConflict(ConflictRecord conflict) async {
    await _conflictStore.add(_db, conflict.toMap());
    _changes.add(null);
  }

  @override
  Future<void> removeConflict(String id) async {
    await _conflictStore.delete(
      _db,
      finder: Finder(filter: Filter.equals('id', id)),
    );
    _changes.add(null);
  }
```

在 `clear()` 加 `await _conflictStore.delete(_db);`。

- [ ] **Step 2: 驗證編譯**

Run: `flutter analyze lib/api/cache/sembast_cache_store.dart`
Expected: No issues（介面全實作）

- [ ] **Step 3: Commit**

```bash
git add lib/api/cache/sembast_cache_store.dart
git commit -m "feat: conflict store 持久化(sembast)"
```

---

## Task 6: `_send` 加 writeCache 參數(A2 重抓不污染快取)

**Files:**
- Modify: `lib/api/api_client.dart:237-337`
- Test: `test/api/api_client_test.dart`

- [ ] **Step 1: 寫失敗測試**

```dart
  test('[A2] GET writeCache:false → 不寫快取', () async {
    // 既有快取有一筆 pending-patched 資料;writeCache:false 的重抓不可覆蓋它
    final store = InMemoryCacheStore();
    await store.writeResponse(cacheKeyFor('GET', '/trips/t/days', {'all': 1}),
        [{'dayNum': 1, 'timeline': []}]);
    // ... 用 http_mock_adapter 讓 GET 回新資料,呼叫 client.get(..., writeCache:false)
    // 斷言:呼叫後 store.readResponse 仍是舊資料(未被覆蓋)
  });
```

（用既有 api_client_test.dart 的 mock adapter + InMemoryCacheStore 慣例補完）

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/api/api_client_test.dart --plain-name "writeCache"`
Expected: FAIL（無 writeCache 參數 / 快取被覆蓋）

- [ ] **Step 3: 實作** — `_send` 加參數,GET 寫快取受其控制

在 `_send` 簽名加 `bool writeCache = true,`;把寫快取那段改為:
```dart
    if (method == 'GET') {
      if (writeCache && !isEmpty && _isCacheableGet(path)) {
        await _cacheStore?.writeResponse(
          cacheKeyFor('GET', path, query), responseData,
        );
      }
    } else {
```
並讓公開 `get(...)` 透傳一個內部用的 `writeCache`（或新增私有重抓用呼叫直接走 `_send(..., writeCache:false)`）。`retry()` closure 也透傳 `writeCache`。

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/api/api_client_test.dart --plain-name "writeCache"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/api/api_client.dart test/api/api_client_test.dart
git commit -m "feat: _send 加 writeCache 參數(重抓不污染快取)"
```

---

## Task 7: sendMutation 入佇列時擷取 base

**Files:**
- Modify: `lib/api/api_client.dart:130-181`
- Test: `test/api/trip_repository_test.dart`

- [ ] **Step 1: 寫失敗測試**

```dart
  test('離線 updateEntry → 佇列項帶 base(快取當下值)', () async {
    // days 快取已有 entry 7 title=舊;離線 updateEntry(title:新)
    // 斷言:readQueue().single.base == {'title':'舊','description':..,'startTime':..,'endTime':..}
  });
  test('離線 updateNote → 佇列項帶 base(camel 欄位當下值)', () async {
    // notes 快取已有 row;離線 updateNote(fields)
    // 斷言:base 為該 row 對應 camel 欄位當下值
  });
```

（用既有 trip_repository_test.dart 的離線寫測試慣例補完 mock）

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/api/trip_repository_test.dart --plain-name "base"`
Expected: FAIL（base 為 null）

- [ ] **Step 3: 實作** — sendMutation 入佇列前擷取 base

在 `sendMutation` 的離線分支,建 `QueuedMutation` 前算 base:
```dart
        final base = await _extractBase(store, optimistic);
```
並把 `base: base,` 傳入 `QueuedMutation(...)`。新增私有:
```dart
  /// 入佇列時從快取擷取「離線改過欄位」的當下值,供 flush rebase 三方比對。
  /// 只對 entry.update / note.update;其餘回 null。
  Future<Map<String, dynamic>?> _extractBase(
    CacheStore store, OfflineOp op,
  ) async {
    final cached = (await store.readResponse(op.cacheKey))?.data;
    if (op.type == 'entry.update') {
      return extractEntryFields(
        cached, op.args['entryId'] as int, _entryFieldKeys(op.args),
      );
    }
    if (op.type == 'note.update') {
      final fields = (op.args['fields'] as Map).cast<String, dynamic>();
      final camelKeys = fields.keys.map(snakeToCamel).toList();
      return extractNoteFields(
        cached, op.args['sectionKey'] as String, op.args['rowId'] as int,
        camelKeys,
      );
    }
    return null;
  }

  /// entry.update args 內實際帶的可編輯欄位(camelCase)。
  List<String> _entryFieldKeys(Map<String, dynamic> args) => [
    for (final k in const ['title', 'description', 'startTime', 'endTime'])
      if (args.containsKey(k)) k,
  ];
```

注意:`snakeToCamel` 需從 optimistic_patchers 匯出(目前是私有 `_snakeToCamel`)— 在 optimistic_patchers.dart 把它改為公開 `snakeToCamel` 並更新內部呼叫。

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/api/trip_repository_test.dart --plain-name "base"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/api/api_client.dart lib/api/cache/optimistic_patchers.dart test/api/trip_repository_test.dart
git commit -m "feat: 入佇列時擷取 base(entry/note 當下值)"
```

---

## Task 8: `_tryRebase` + flushQueue 整合(含 P1 去重)

**Files:**
- Modify: `lib/api/api_client.dart:186-214`
- Test: `test/api/api_client_test.dart` / `test/api/trip_repository_test.dart`

- [ ] **Step 1: 寫失敗測試**

```dart
  test('flush STALE 無衝突 → 重抓 + 重送(帶新 version)+ remove + synced', () async {
    // 佇列有 entry.update(base title=舊, body expectedVersion=3);
    // 第一次 PATCH 回 409 STALE_ENTRY;重抓 days 回 entry version=5、title 仍=舊(server 沒動 title);
    // 斷言:第二次 PATCH body.expectedVersion==5;flushQueue().synced==1;佇列清空;無 conflict
  });
  test('flush STALE 有衝突 → appendConflict、不重送、移出主佇列、上報', () async {
    // 重抓 days 回 title=他人改的值(三方不同)→ conflictFields=['title']
    // 斷言:readConflicts().length==1;佇列清空;FlushResult.conflicts.length==1;無第二次 PATCH
  });
  test('flush STALE 重抓時離線 → break 保留佇列', () async {
    // 409 後重抓 GET 連線錯誤 → break;佇列仍在;synced==0
  });
  test('flush STALE 重送再 409 → break 保留', () async {
    // 重抓成功無衝突,重送又 409(race)→ break 保留待下次
  });
  test('非 STALE 的 409(時段衝突)→ 維持上報+drop(回歸)', () async {
    // add entry 的 409 conflictWith → conflicts.add + remove(現有行為不變)
  });
  test('[P1] 同 trip 多筆 STALE → 整包 days GET 只打一次', () async {
    // 佇列兩筆 entry.update 同 trip,皆 STALE;斷言重抓 GET /days 只發一次
  });
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/api/api_client_test.dart --plain-name "STALE"`
Expected: FAIL

- [ ] **Step 3: 實作** — flushQueue catch 分支 + `_tryRebase`

把 `flushQueue` 的 `on ApiError catch (e)` 改為:
```dart
        } on ApiError catch (e) {
          if (e.status == 409 && e.code == 'STALE_ENTRY' && _rebasable(m.type)) {
            final outcome = await _tryRebase(m, refetchCache);
            if (outcome == _RebaseOutcome.synced) {
              await store.removeMutation(m.id);
              synced++;
            } else if (outcome == _RebaseOutcome.conflict) {
              await store.removeMutation(m.id);
              conflicts.add(m);
            } else {
              break; // offline / retryLater → 保留佇列待下次
            }
          } else if (e.status >= 500 || e.status == 401 || e.status == 403) {
            break;
          } else {
            conflicts.add(m);
            await store.removeMutation(m.id);
          }
        }
```

在迴圈外宣告 P1 去重暫存:`final refetchCache = <String, Future<Object?>>{};`(key = cacheKey,值為重抓 Future,同 flush 內共用)。

新增:
```dart
  static const _rebasableTypes = {'entry.update', 'note.update'};
  bool _rebasable(String type) => _rebasableTypes.contains(type);

  /// STALE 重抓 server 真相 → 三方 merge → 無衝突重送 / 有衝突入 conflict store。
  Future<_RebaseOutcome> _tryRebase(
    QueuedMutation m, Map<String, Future<Object?>> refetchCache,
  ) async {
    final store = _cacheStore!;
    final tripId = _tripIdFromPath(m.path);
    if (tripId == null) return _RebaseOutcome.conflict; // 異常 path → 當衝突上報
    // 重抓(P1:同 cacheKey 一次 flush 內共用同一 Future;A2:writeCache:false)
    final Object? fresh;
    try {
      fresh = await refetchCache.putIfAbsent(
        m.cacheKey, () => _refetchFor(m, tripId));
    } on DioException catch (e) {
      return _isOfflineError(e) ? _RebaseOutcome.offline : _RebaseOutcome.conflict;
    }
    final theirs = _theirsFrom(m, fresh);
    if (theirs == null) return _RebaseOutcome.conflict; // 找不到 row(可能已被刪)
    final newVersion = (theirs.remove('version') as num?)?.toInt();
    final ours = _oursFrom(m);
    final conflictFields = rebaseMerge(m.base, ours, theirs);
    if (conflictFields.isEmpty) {
      // 無衝突 → 重送原 body,換新 expectedVersion
      try {
        await _send(m.method, m.path,
            body: _withExpectedVersion(m.body, newVersion), query: m.query);
        return _RebaseOutcome.synced;
      } on ApiError {
        return _RebaseOutcome.retryLater; // 再 409 等 → 保留待下次
      } on DioException catch (e) {
        return _isOfflineError(e) ? _RebaseOutcome.offline : _RebaseOutcome.retryLater;
      }
    }
    await store.appendConflict(ConflictRecord(
      id: m.id, type: m.type, path: m.path, body: m.body, args: m.args,
      cacheKey: m.cacheKey, ours: ours, theirs: theirs,
      newVersion: newVersion ?? 0, conflictFields: conflictFields,
      createdAt: m.createdAt,
    ));
    return _RebaseOutcome.conflict;
  }
```

新增輔助:
```dart
  static final _tripIdRe = RegExp(r'/trips/([^/]+)/');
  String? _tripIdFromPath(String path) =>
      _tripIdRe.firstMatch(path)?.group(1);

  /// 依 type 重抓對應整包(entry→days?all=1;note→notes),writeCache:false。
  Future<Object?> _refetchFor(QueuedMutation m, String tripId) {
    if (m.type == 'entry.update') {
      return _send('GET', '/trips/$tripId/days',
          query: {'all': 1}, writeCache: false, fallbackToCache: false);
    }
    return _send('GET', '/trips/$tripId/notes',
        writeCache: false, fallbackToCache: false);
  }

  /// 從重抓結果抽 theirs(含 version);找不到 row → null。
  Map<String, dynamic>? _theirsFrom(QueuedMutation m, Object? fresh) {
    if (m.type == 'entry.update') {
      return extractEntryFields(
          fresh, m.args['entryId'] as int, _ourKeys(m));
    }
    final fields = (m.args['fields'] as Map).cast<String, dynamic>();
    return extractNoteFields(fresh, m.args['sectionKey'] as String,
        m.args['rowId'] as int, fields.keys.map(snakeToCamel).toList());
  }

  /// ours = 離線改成的值(camelCase),與 base/theirs 同鍵集合。
  Map<String, dynamic> _oursFrom(QueuedMutation m) {
    if (m.type == 'entry.update') {
      return {for (final k in _ourKeys(m)) k: m.args[k]};
    }
    final fields = (m.args['fields'] as Map).cast<String, dynamic>();
    return {for (final e in fields.entries) snakeToCamel(e.key): e.value};
  }

  List<String> _ourKeys(QueuedMutation m) => [
    for (final k in const ['title', 'description', 'startTime', 'endTime'])
      if (m.args.containsKey(k)) k,
  ];

  /// 把 body(Map)的 expectedVersion 換成新值(body 非 Map 則原樣)。
  Object? _withExpectedVersion(Object? body, int? v) {
    if (body is! Map || v == null) return body;
    return {...body, 'expectedVersion': v};
  }
```

並在檔尾(或頂部)加:
```dart
enum _RebaseOutcome { synced, conflict, offline, retryLater }
```

import `rebase_merge.dart`、`optimistic_patchers.dart`（`snakeToCamel`）。

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/api/api_client_test.dart --plain-name "STALE"`
Expected: PASS（含 P1 去重）

- [ ] **Step 5: Commit**

```bash
git add lib/api/api_client.dart test/api/api_client_test.dart
git commit -m "feat: flush STALE_ENTRY 三方 rebase(重抓/重送/衝突入庫 + 去重)"
```

---

## Task 9: resolveConflictKeepOurs / KeepTheirs(含 A3 錯誤處理)

**Files:**
- Modify: `lib/api/api_client.dart`
- Test: `test/api/api_client_test.dart`

- [ ] **Step 1: 寫失敗測試**

```dart
  test('resolveKeepOurs 重送成功 → removeConflict', () async {
    // conflict store 有一筆;PATCH 回 2xx → readConflicts 清空
  });
  test('[A3] resolveKeepOurs 重送離線 → 不 removeConflict(留存)+ throw', () async {
    // PATCH 連線錯誤 → 衝突仍在;呼叫端可提示
  });
  test('[A3] resolveKeepOurs 重送再 409 → 重新 rebase(更新 theirs / 自動解)', () async {
    // 重送又 STALE → 重抓比對:若無衝突自動 synced+removeConflict;若仍衝突更新該筆 theirs
  });
  test('resolveKeepTheirs → 僅 removeConflict(不發 PATCH)', () async {
    // 不呼叫網路;readConflicts 清空
  });
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/api/api_client_test.dart --plain-name "resolve"`
Expected: FAIL（方法未定義）

- [ ] **Step 3: 實作**

```dart
  /// 衝突解決:保留離線版本 → 重送原 body(新 version)。
  /// 成功才 removeConflict;離線 → throw 保留;再 409 → 重新 rebase(自動解或更新 theirs)。
  Future<void> resolveConflictKeepOurs(ConflictRecord c) async {
    final store = _cacheStore!;
    try {
      await _send('PATCH', c.path,
          body: _withExpectedVersion(c.body, c.newVersion));
      await store.removeConflict(c.id);
    } on ApiError catch (e) {
      if (e.status == 409 && e.code == 'STALE_ENTRY') {
        // server 又變 → 以原佇列語意重新 rebase
        await store.removeConflict(c.id);
        final outcome = await _tryRebase(_asQueued(c), <String, Future<Object?>>{});
        // synced → 已解;conflict → _tryRebase 內已 appendConflict 更新版本;
        // offline/retryLater → 重新入主佇列待下次 flush
        if (outcome == _RebaseOutcome.offline ||
            outcome == _RebaseOutcome.retryLater) {
          await store.appendMutation(_asQueued(c));
        }
        return;
      }
      rethrow; // 其他 4xx → 上報給呼叫端
    }
    // DioException(離線)不 catch → 往上拋,衝突留存,UI 提示「仍離線」
  }

  /// 衝突解決:採用 server 版本 → 丟棄離線改動(純本機,不會失敗)。
  Future<void> resolveConflictKeepTheirs(ConflictRecord c) =>
      _cacheStore!.removeConflict(c.id);

  /// ConflictRecord → QueuedMutation(重新 rebase / 入佇列用)。
  QueuedMutation _asQueued(ConflictRecord c) => QueuedMutation(
    id: c.id, method: 'PATCH', path: c.path, body: c.body,
    type: c.type, cacheKey: c.cacheKey, args: c.args,
    createdAt: c.createdAt, base: c.ours, // 以「上次離線值」為新 base
  );
```

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/api/api_client_test.dart --plain-name "resolve"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/api/api_client.dart test/api/api_client_test.dart
git commit -m "feat: resolveConflict keepOurs/keepTheirs(含離線/再衝突處理)"
```

---

## Task 10: A1 — syncConflictRecordsProvider 取代 + 衝突解決 bottom sheet UI

**Files:**
- Modify: `lib/features/offline/offline_sync.dart`
- Modify: `lib/features/offline/offline_status_banner.dart`
- Create: `lib/features/offline/conflict_resolve_sheet.dart`
- Test: `test/features/offline/offline_status_banner_test.dart`

- [ ] **Step 1: 寫失敗測試**

```dart
  testWidgets('[A1] banner 顯示 conflict store 衝突數', (tester) async {
    final store = InMemoryCacheStore();
    await store.appendConflict(/* rec */);
    // pump OfflineStatusBanner with cacheStoreProvider override → store
    // 斷言:find.textContaining('衝突') findsOneWidget;數字為 1
  });
  testWidgets('點「檢視」開 bottom sheet,逐筆二選一', (tester) async {
    // 點檢視 → showModalBottomSheet;點「用對方的」→ resolveKeepTheirs → 清單少一筆
  });
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/features/offline/offline_status_banner_test.dart`
Expected: FAIL

- [ ] **Step 3: 實作**

(a) `offline_sync.dart`:移除 `syncConflictsProvider` + `SyncConflictsController`;新增:
```dart
/// 待解決衝突(持久化 conflict store);store 變動反應式刷新。
final syncConflictRecordsProvider = StreamProvider<List<ConflictRecord>>((
  ref,
) async* {
  final store = ref.watch(cacheStoreProvider);
  yield await store.readConflicts();
  await for (final _ in store.changes) {
    yield await store.readConflicts();
  }
});
```
並把 `OfflineSyncController.sync()` 內 `ref.read(syncConflictsProvider.notifier).set(result.conflicts);` 該行刪除（衝突已由 flush 寫入 store）。

(b) `conflict_resolve_sheet.dart`:`showConflictResolveSheet(context, ref)` → `showModalBottomSheet`,`ConsumerWidget` watch `syncConflictRecordsProvider`,逐筆卡片顯示標題 + `conflictFields` 並排「你的 / 對方」+ 兩鈕:
```dart
FilledButton(onPressed: () async {
  try {
    await ref.read(apiClientProvider).resolveConflictKeepOurs(c);
  } on Exception {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仍離線,稍後重試')));
    }
  }
}, child: const Text('保留你的')),
OutlinedButton(onPressed: () =>
  ref.read(apiClientProvider).resolveConflictKeepTheirs(c),
  child: const Text('用對方的')),
```
解完 invalidate trip 家族(重用 `OfflineSyncController` 的 invalidate,或直接在 sheet 內 invalidate 對應 providers)。欄位名→人話標籤用小 map(`title`→標題、`startTime`→開始時間…)。

(c) `offline_status_banner.dart`:衝突態改 watch `syncConflictRecordsProvider`,文案「N 筆同步衝突 ・檢視」,`onTap: () => showConflictResolveSheet(context, ref)`。移除舊「知道了」dismiss。

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/features/offline/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/offline/ test/features/offline/
git commit -m "feat: 衝突解決 UI — banner 點開 bottom sheet 二選一(A1 取代記憶體源)"
```

---

## Task 11: 全套驗證 + 跨帳號清理確認

**Files:**
- 驗證 `lib/api/cache/cache_store.dart` 的 `clear()` 已含 conflict store(Task 4/5 已加)。
- 確認 `AuthNotifier` 換帳號 owner-check 走的是 `cacheStore.clear()`(PR #24),clear 已含 conflict store → 自動涵蓋。

- [ ] **Step 1: 跨帳號清理回歸測試**

```dart
  test('clear() 一併清 conflict store(換帳號不外洩)', () async {
    final s = InMemoryCacheStore();
    await s.appendConflict(/* rec */);
    await s.clear();
    expect(await s.readConflicts(), isEmpty);
  });
```
（Task 4 已涵蓋此測試;此處確認 `AuthNotifier` 換帳號路徑呼叫的是 `clear()`,若是部分清理則補。）

- [ ] **Step 2: 全套測試 + analyze**

Run: `flutter test && flutter analyze`
Expected: All tests passed + No issues found

- [ ] **Step 3: Commit（若有補強）**

```bash
git add -A
git commit -m "test: OCC rebase 跨帳號清理回歸 + 全套驗證"
```

---

## 完成定義

- `flutter test` 全綠、`flutter analyze` 零 error/warning
- 離線編輯 → 重連遇他人改動:同欄位衝突彈 bottom sheet 二選一,其餘自動 rebase,零遺失
- spec 的 A1/A2/A3/C1/P1 全部落地且有對應測試
- 走 `/ship` 開 PR(base `master`,繁中 commit;發版版號依需要 bump)
