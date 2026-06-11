# 時間軸 Entry CRUD（A+B）實作計畫

> **For agentic workers:** 用 superpowers:executing-plans / subagent-driven-development 逐 task 實作。步驟用 `- [ ]` 追蹤。

**Goal:** 時間軸可編輯/刪除停留點 meta，並在某天新增自訂停留點。

**Architecture:** 沿用 `tripDaysProvider` family 讀取；新增 repository mutation + 共用 bottom sheet；mutation 後 `ref.invalidate(tripDaysProvider(tripId))` 重抓刷新。

**Tech Stack:** Flutter / flutter_riverpod 3.x / go_router / dio mock + mocktail。

Spec：`docs/superpowers/specs/2026-06-11-timeline-entry-crud-a-design.md`。

---

## Task 1：Repository — updateEntry / deleteEntry / addEntryToDay+description

**Files:**
- Modify: `lib/api/trip_repository.dart`
- Test: `test/api/trip_repository_test.dart`

- [ ] **Step 1：寫失敗測試**（append 進 `test/api/trip_repository_test.dart` 的 `main()`，並改既有 addEntryToDay 測試加 description）

```dart
  test('updateEntry：PATCH /trips/:id/entries/:eid snake_case + expectedVersion', () async {
    dioAdapter.onPatch(
      '/trips/okinawa/entries/11',
      (server) => server.reply(200, {'id': 11, 'version': 3, 'title': '新標題'}),
      data: {
        'title': '新標題', 'description': '改描述',
        'start_time': '09:30', 'end_time': '10:30', 'expectedVersion': 2,
      },
    );

    await expectLater(
      tripRepository.updateEntry(
        tripId: 'okinawa', entryId: 11, expectedVersion: 2,
        title: '新標題', description: '改描述',
        startTime: '09:30', endTime: '10:30'),
      completes,
    );
  });

  test('updateEntry：409 STALE_ENTRY → 拋 ApiError(409)', () async {
    dioAdapter.onPatch(
      '/trips/okinawa/entries/11',
      (server) => server.reply(409, {
        'error': {'code': 'STALE_ENTRY', 'message': 'expected version 2, current 3'},
      }),
      data: {
        'title': '標題', 'description': null,
        'start_time': null, 'end_time': null, 'expectedVersion': 2,
      },
    );

    await expectLater(
      tripRepository.updateEntry(
        tripId: 'okinawa', entryId: 11, expectedVersion: 2, title: '標題'),
      throwsA(isA<ApiError>()
          .having((e) => e.status, 'status', 409)
          .having((e) => e.code, 'code', 'STALE_ENTRY')),
    );
  });

  test('deleteEntry：DELETE /trips/:id/entries/:eid（200 {ok:true}）', () async {
    dioAdapter.onDelete(
      '/trips/okinawa/entries/11',
      (server) => server.reply(200, {'ok': true}),
    );

    await expectLater(
      tripRepository.deleteEntry(tripId: 'okinawa', entryId: 11),
      completes,
    );
  });
```

並把既有 `addEntryToDay` 測試改為帶 description（body 加 `'description': '海景第一排'`，呼叫加 `description: '海景第一排'`）：

```dart
  test('addEntryToDay：POST /trips/:id/days/:num/entries snake_case body', () async {
    dioAdapter.onPost(
      '/trips/okinawa/days/1/entries',
      (server) => server.reply(201, {'id': 99}),
      data: {
        'title': '美麗海水族館', 'description': '海景第一排', 'poi_type': 'attraction',
        'lat': 26.69, 'lng': 127.87,
        'start_time': '10:00', 'end_time': '11:00', 'source': 'user-explore',
      },
    );

    await expectLater(
      tripRepository.addEntryToDay(
        tripId: 'okinawa', dayNum: 1, title: '美麗海水族館',
        description: '海景第一排', poiType: 'attraction', lat: 26.69, lng: 127.87,
        startTime: '10:00', endTime: '11:00'),
      completes,
    );
  });
```

確保 `import 'package:tripline/api/api_error.dart';` 已在測試檔頂（既有應已有；無則補）。

- [ ] **Step 2：跑測試確認失敗**　`flutter test test/api/trip_repository_test.dart`（updateEntry/deleteEntry 未定義 → 編譯失敗）

- [ ] **Step 3：實作**（`lib/api/trip_repository.dart`）。`addEntryToDay` 加 `String? description` 參數、body 加 `'description': description`；在 `addEntryToDay` 之後新增兩方法：

```dart
  /// PATCH /trips/:id/entries/:eid（meta 編輯;欄位 snake_case + OCC camelCase expectedVersion）。
  /// 409 STALE_ENTRY 時 ApiClient 丟 ApiError(status 409)。
  Future<void> updateEntry({
    required String tripId,
    required int entryId,
    required int expectedVersion,
    required String title,
    String? description,
    String? startTime,
    String? endTime,
  }) {
    return _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId',
      body: {
        'title': title,
        'description': description,
        'start_time': startTime,
        'end_time': endTime,
        'expectedVersion': expectedVersion,
      },
    );
  }

  /// DELETE /trips/:id/entries/:eid（後端回 200 {ok:true},忽略 body）。
  Future<void> deleteEntry({required String tripId, required int entryId}) {
    return _client.delete(
      '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId',
    );
  }
```

- [ ] **Step 4：跑測試確認通過**　`flutter test test/api/trip_repository_test.dart`
- [ ] **Step 5：commit**　`feat: TripRepository updateEntry/deleteEntry + addEntryToDay description`

---

## Task 2：EntryEditSheet（編輯/新增共用 bottom sheet）

**Files:**
- Create: `lib/features/trip_detail/widgets/entry_edit_sheet.dart`
- Test: `test/features/trip_detail/widgets/entry_edit_sheet_test.dart`

- [ ] **Step 1：寫失敗測試**（新檔）

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trip_detail/widgets/entry_edit_sheet.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

const _entry = TimelineEntry(
  id: 11, sortOrder: 0, startTime: '09:00', endTime: '10:00',
  title: '首里城', description: '世界遺產', version: 2);

Future<void> _open(WidgetTester tester, _MockTripRepository repo,
    EntryEditArgs args) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      tripRepositoryProvider.overrideWithValue(repo),
      tripDaysProvider('t1').overrideWith((ref) async => const <TripDay>[]),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                showEntryEditSheet(context, tripId: 't1', args: args),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  group('entryTimeRangeValid', () {
    test('皆 null / 任一 null → true', () {
      expect(entryTimeRangeValid(null, null), isTrue);
      expect(entryTimeRangeValid(const TimeOfDay(hour: 9, minute: 0), null), isTrue);
      expect(entryTimeRangeValid(null, const TimeOfDay(hour: 9, minute: 0)), isTrue);
    });
    test('end > start → true；end <= start → false', () {
      expect(entryTimeRangeValid(const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 10, minute: 0)), isTrue);
      expect(entryTimeRangeValid(const TimeOfDay(hour: 10, minute: 0),
          const TimeOfDay(hour: 10, minute: 0)), isFalse);
      expect(entryTimeRangeValid(const TimeOfDay(hour: 11, minute: 0),
          const TimeOfDay(hour: 10, minute: 0)), isFalse);
    });
  });

  testWidgets('編輯模式：預填標題 + 送出呼叫 updateEntry', (tester) async {
    final repo = _MockTripRepository();
    when(() => repo.updateEntry(
          tripId: any(named: 'tripId'),
          entryId: any(named: 'entryId'),
          expectedVersion: any(named: 'expectedVersion'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        )).thenAnswer((_) async {});

    await _open(tester, repo, const EntryEditExisting(_entry));
    expect(find.widgetWithText(TextField, '首里城'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(() => repo.updateEntry(
        tripId: 't1', entryId: 11, expectedVersion: 2,
        title: '首里城', description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'))).called(1);
  });

  testWidgets('新增模式：送出呼叫 addEntryToDay(source custom)', (tester) async {
    final repo = _MockTripRepository();
    when(() => repo.addEntryToDay(
          tripId: any(named: 'tripId'),
          dayNum: any(named: 'dayNum'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          poiType: any(named: 'poiType'),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
          source: any(named: 'source'),
        )).thenAnswer((_) async {});

    await _open(tester, repo, const EntryEditNew(2));
    await tester.enterText(find.byKey(const ValueKey('entry-edit-title')), '自由活動');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(() => repo.addEntryToDay(
        tripId: 't1', dayNum: 2, title: '自由活動',
        description: any(named: 'description'),
        startTime: any(named: 'startTime'), endTime: any(named: 'endTime'),
        source: 'custom')).called(1);
  });

  testWidgets('標題清空 → 送出鈕 disabled', (tester) async {
    final repo = _MockTripRepository();
    await _open(tester, repo, const EntryEditNew(1));
    final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('entry-edit-submit')));
    expect(button.onPressed, isNull);
  });
}
```

- [ ] **Step 2：跑測試確認失敗**　`flutter test test/features/trip_detail/widgets/entry_edit_sheet_test.dart`（檔案未建 → 編譯失敗）

- [ ] **Step 3：實作**（`lib/features/trip_detail/widgets/entry_edit_sheet.dart`）

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../models/entry.dart';
import '../../../theme/tokens.dart';
import '../trip_providers.dart';

/// 編輯/新增停留點的模式參數。
sealed class EntryEditArgs {
  const EntryEditArgs();
}

class EntryEditExisting extends EntryEditArgs {
  const EntryEditExisting(this.entry);
  final TimelineEntry entry;
}

class EntryEditNew extends EntryEditArgs {
  const EntryEditNew(this.dayNum);
  final int dayNum;
}

/// 時間區間有效性：start/end 皆設時 end 須晚於 start;任一未設視為有效（時間選填）。
bool entryTimeRangeValid(TimeOfDay? start, TimeOfDay? end) {
  if (start == null || end == null) return true;
  return end.hour * 60 + end.minute > start.hour * 60 + start.minute;
}

/// 以 modal bottom sheet 開啟編輯/新增停留點表單。
Future<void> showEntryEditSheet(
  BuildContext context, {
  required String tripId,
  required EntryEditArgs args,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: EntryEditSheet(tripId: tripId, args: args),
    ),
  );
}

class EntryEditSheet extends ConsumerStatefulWidget {
  const EntryEditSheet({super.key, required this.tripId, required this.args});

  final String tripId;
  final EntryEditArgs args;

  @override
  ConsumerState<EntryEditSheet> createState() => _EntryEditSheetState();
}

class _EntryEditSheetState extends ConsumerState<EntryEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _submitting = false;

  bool get _isEdit => widget.args is EntryEditExisting;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args is EntryEditExisting) {
      _title = TextEditingController(text: args.entry.title);
      _desc = TextEditingController(text: args.entry.description ?? '');
      _start = _parseHm(args.entry.startTime);
      _end = _parseHm(args.entry.endTime);
    } else {
      _title = TextEditingController();
      _desc = TextEditingController();
    }
    _title.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseHm(String? hm) {
    if (hm == null) return null;
    final parts = hm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String? _fmt(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool get _canSubmit =>
      !_submitting &&
      _title.text.trim().isNotEmpty &&
      entryTimeRangeValid(_start, _end);

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _start : _end) ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final description = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    setState(() => _submitting = true);
    final repo = ref.read(tripRepositoryProvider);
    try {
      switch (widget.args) {
        case EntryEditExisting(:final entry):
          await repo.updateEntry(
            tripId: widget.tripId,
            entryId: entry.id,
            expectedVersion: entry.version,
            title: title,
            description: description,
            startTime: _fmt(_start),
            endTime: _fmt(_end),
          );
        case EntryEditNew(:final dayNum):
          await repo.addEntryToDay(
            tripId: widget.tripId,
            dayNum: dayNum,
            title: title,
            description: description,
            startTime: _fmt(_start),
            endTime: _fmt(_end),
            source: 'custom',
          );
      }
      ref.invalidate(tripDaysProvider(widget.tripId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_isEdit ? '已儲存' : '已新增')));
    } on ApiError catch (error) {
      if (!mounted) return;
      if (error.status == 409) {
        ref.invalidate(tripDaysProvider(widget.tripId));
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('此停留點已更新，已重新載入，請再編輯一次')));
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('儲存失敗，請稍後再試')));
    } on Exception {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('儲存失敗，請稍後再試')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeValid = entryTimeRangeValid(_start, _end);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? '編輯停留點' : '新增停留點',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: TpSpacing.s4),
            TextField(
              key: const ValueKey('entry-edit-title'),
              controller: _title,
              decoration: const InputDecoration(labelText: '標題'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: TpSpacing.s3),
            TextField(
              key: const ValueKey('entry-edit-desc'),
              controller: _desc,
              decoration: const InputDecoration(labelText: '描述（選填）'),
              maxLines: 2,
            ),
            const SizedBox(height: TpSpacing.s3),
            _timeField(true),
            const SizedBox(height: TpSpacing.s2),
            _timeField(false),
            if (!timeValid)
              Padding(
                padding: const EdgeInsets.only(top: TpSpacing.s2),
                child: Text('結束時間需晚於開始時間',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12)),
              ),
            const SizedBox(height: TpSpacing.s6),
            FilledButton(
              key: const ValueKey('entry-edit-submit'),
              onPressed: _canSubmit ? _submit : null,
              child: Text(_submitting ? '處理中…' : (_isEdit ? '儲存' : '新增')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeField(bool isStart) {
    final t = isStart ? _start : _end;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: ValueKey(isStart ? 'entry-edit-start' : 'entry-edit-end'),
            onPressed: () => _pick(isStart),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${isStart ? '開始' : '結束'}　${_fmt(t) ?? '未設定'}'),
            ),
          ),
        ),
        if (t != null)
          IconButton(
            key: ValueKey(
                isStart ? 'entry-edit-start-clear' : 'entry-edit-end-clear'),
            tooltip: '清除',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => isStart ? _start = null : _end = null),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4：跑測試確認通過**　`flutter test test/features/trip_detail/widgets/entry_edit_sheet_test.dart`
- [ ] **Step 5：commit**　`feat: EntryEditSheet 編輯/新增停留點 bottom sheet`

---

## Task 3：TimelineEntryTile 加 onTap

**Files:**
- Modify: `lib/features/trip_detail/widgets/timeline_entry_tile.dart`
- Test: `test/features/trip_detail/widgets/timeline_entry_tile_test.dart`

- [ ] **Step 1：寫失敗測試**（append；若該檔的 pump helper 不同，依其既有風格調整）。新增一例：傳 `onTap`，點內容卡（找 entry.title 文字）→ callback 被呼叫一次；既有測試（dot tone 等）保持。

```dart
  testWidgets('有 onTap：點內容卡觸發 callback', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: TimelineEntryTile(
          entry: const TimelineEntry(
              id: 11, sortOrder: 0, title: '首里城', version: 1),
          onTap: () => tapped++,
        ),
      ),
    ));
    await tester.tap(find.text('首里城'));
    expect(tapped, 1);
  });
```

- [ ] **Step 2：跑測試確認失敗**（`onTap` 參數未定義）
- [ ] **Step 3：實作**：建構子加 `this.onTap`、欄位 `final VoidCallback? onTap;`，將內容卡包進 `InkWell`：

```dart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: TpSpacing.s3),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(TpRadius.md),
                child: _EntryCard(entry: entry, tone: tone),
              ),
            ),
          ),
```

- [ ] **Step 4：跑測試確認通過**　`flutter test test/features/trip_detail/widgets/timeline_entry_tile_test.dart`
- [ ] **Step 5：commit**　`feat: TimelineEntryTile onTap（點卡進編輯）`

---

## Task 4：Timeline 串接（tripId、Dismissible 刪除、新增鈕、tap→sheet）

**Files:**
- Modify: `lib/features/trip_detail/trip_timeline_screen.dart`
- Test: `test/features/trip_detail/trip_timeline_screen_test.dart`

- [ ] **Step 1：寫失敗測試**。`_pumpTimeline` 增加可選 `TripRepository? repo` 參數，有值時加 `tripRepositoryProvider.overrideWithValue(repo)` 到 overrides。新增三例：

```dart
  testWidgets('點 entry tile 開啟編輯 sheet（預填標題）', (tester) async {
    await _pumpTimeline(tester);
    await tester.tap(find.text('美麗海水族館'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-edit-title')), findsOneWidget);
    expect(find.widgetWithText(TextField, '美麗海水族館'), findsOneWidget);
  });

  testWidgets('左滑 entry → 確認 → 呼叫 deleteEntry', (tester) async {
    final repo = _MockTripRepository();
    when(() => repo.deleteEntry(
          tripId: any(named: 'tripId'),
          entryId: any(named: 'entryId'),
        )).thenAnswer((_) async {});
    await _pumpTimeline(tester, repo: repo);

    await tester.drag(
        find.byKey(const ValueKey('entry-dismiss-11')), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();

    verify(() => repo.deleteEntry(tripId: _tripId, entryId: 11)).called(1);
  });

  testWidgets('點「新增停留點」開啟新增 sheet', (tester) async {
    await _pumpTimeline(tester);
    await tester.tap(find.byKey(const ValueKey('add-entry-1')).first);
    await tester.pumpAndSettle();
    expect(find.text('新增停留點'), findsOneWidget);
  });
```

測試檔頂補：`import 'package:mocktail/mocktail.dart';`、`import 'package:tripline/api/providers.dart';`、`import 'package:tripline/api/trip_repository.dart';`，並加 `class _MockTripRepository extends Mock implements TripRepository {}` 與 `setUpAll(() => registerFallbackValue(<String, dynamic>{}));`（若無）。`_pumpTimeline` 簽名加 `_MockTripRepository? repo`，overrides 內條件加入。

- [ ] **Step 2：跑測試確認失敗**（onTap/Dismissible/新增鈕未接 → 找不到 key）
- [ ] **Step 3：實作**（`trip_timeline_screen.dart`）：
  - 頂部 import 加 `import '../../api/providers.dart';` 與 `import 'widgets/entry_edit_sheet.dart';`。
  - `TripTimelineScreen.build`：`_TimelineBody(days: days, tripId: tripId)`。
  - `_TimelineBody` 加 `final String tripId;`（建構子 `{required this.days, required this.tripId}`），`build` 內 `_DaySection(key: ..., day: day, tripId: widget.tripId)`。
  - `_DaySection` 由 `StatelessWidget` 改 `ConsumerWidget`，加 `final String tripId;`：

```dart
class _DaySection extends ConsumerWidget {
  const _DaySection({super.key, required this.tripId, required this.day});

  final String tripId;
  final TripDay day;

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TimelineEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除停留點'),
        content: Text('確定要刪除「${entry.title}」嗎？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('刪除')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(tripRepositoryProvider)
          .deleteEntry(tripId: tripId, entryId: entry.id);
      ref.invalidate(tripDaysProvider(tripId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已刪除')));
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('刪除失敗，請稍後再試')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = day.timeline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DayHeader(day: day),
        const SizedBox(height: TpSpacing.s3),
        if (day.hotel != null) ...[
          HotelCard(hotel: day.hotel!),
          const SizedBox(height: TpSpacing.s3),
        ],
        for (var i = 0; i < timeline.length; i++) ...[
          if (i > 0 && timeline[i].travel != null)
            _TravelRow(travel: timeline[i].travel!),
          Dismissible(
            key: ValueKey('entry-dismiss-${timeline[i].id}'),
            direction: DismissDirection.endToStart,
            background: _DeleteBackground(),
            confirmDismiss: (_) async {
              await _confirmDelete(context, ref, timeline[i]);
              return false; // 靠 invalidate 重抓移除,避免與 provider 資料雙重移除
            },
            child: TimelineEntryTile(
              entry: timeline[i],
              isFirst: i == 0,
              isLast: i == timeline.length - 1,
              onTap: () => showEntryEditSheet(context,
                  tripId: tripId, args: EntryEditExisting(timeline[i])),
            ),
          ),
        ],
        const SizedBox(height: TpSpacing.s2),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('add-entry-${day.dayNum}'),
            onPressed: () => showEntryEditSheet(context,
                tripId: tripId, args: EntryEditNew(day.dayNum)),
            icon: const Icon(Icons.add),
            label: const Text('新增停留點'),
          ),
        ),
        const SizedBox(height: TpSpacing.s6),
      ],
    );
  }
}

/// 左滑刪除背景。
class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.only(bottom: TpSpacing.s3),
      padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}
```

> `_DeleteBackground` 加 `const` 建構子可省略；若加 `const` 則 `key: ValueKey(...)` 用法不變。lint 可能要求 `const _DeleteBackground()` 呼叫處；實作時若 analyze 提示則補 const 建構子。

- [ ] **Step 4：跑全測試**　`flutter test`（確認既有 timeline 測試仍綠 + 新例通過）
- [ ] **Step 5：commit**　`feat: timeline entry 編輯/刪除/新增串接（tap sheet + 左滑刪除 + 新增鈕）`

---

## 收尾

- [ ] `flutter analyze`（0 issue）+ `flutter test`（全綠）
- [ ] iOS simulator smoke（測試帳號）：進某行程 timeline → 點 tile 編輯改時間存 → 左滑刪 → 新增自訂停留點
- [ ] finishing-a-development-branch：push + 開 PR（base master）

## 自我審查（plan vs spec）
- spec 各端點/欄位 → Task 1 覆蓋（updateEntry/deleteEntry/addEntryToDay+description）。
- EntryEditSheet（sealed args、時間選填、驗證、409）→ Task 2。
- 觸發入口（tap/swipe/新增鈕）→ Task 3+4。
- 型別一致：`updateEntry`/`addEntryToDay`/`deleteEntry` 簽名、`entryTimeRangeValid`、ValueKey（entry-edit-*/entry-dismiss-*/add-entry-*）三處一致。
- 無 placeholder。
