import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/widgets/entry_field_merge.dart';
import 'package:tripline/models/entry.dart';

void main() {
  const base = {'description': '舊', 'startTime': '09:00', 'endTime': null};

  test('自己改過、對方沒動 → 保留自己的,不算衝突;沒改的欄位帶入對方值', () {
    final r = mergeEntryFields(
      base: base,
      ours: {'description': '我的', 'startTime': '09:00', 'endTime': null},
      theirs: {'description': '舊', 'startTime': '10:00', 'endTime': '11:00'},
      previousConflicts: const {},
    );
    expect(r.conflicts, isEmpty);
    expect(r.adopt, {'startTime', 'endTime'});
  });

  test('三方都不同 → 衝突;剛好同值不算', () {
    final r = mergeEntryFields(
      base: base,
      ours: {'description': '我的', 'startTime': '10:00', 'endTime': null},
      theirs: {'description': '對方的', 'startTime': '10:00', 'endTime': null},
      previousConflicts: const {},
    );
    expect(r.conflicts, {'description'});
    expect(r.adopt, {'endTime'});
  });

  test('先前已標衝突、表單值仍與對方不同 → 維持衝突;使用者已改成對方值 → 解除', () {
    final r = mergeEntryFields(
      base: base,
      ours: {'description': '我的', 'startTime': '10:00', 'endTime': null},
      theirs: {'description': '對方的', 'startTime': '10:00', 'endTime': null},
      previousConflicts: const {'description', 'startTime'},
    );
    expect(r.conflicts, {'description'});
  });

  test('對方這一版沒再動、但先前已是衝突且我仍未採用對方值 → 衝突不能被洗掉', () {
    // 上一輪 merge 後 base 已經等於對方的值;rebaseMerge 會因 base == theirs 判無衝突,
    // 只有 previousConflicts 記得這一欄還在打架。
    final r = mergeEntryFields(
      base: {'description': '對方的', 'startTime': null, 'endTime': null},
      ours: {'description': '我的', 'startTime': null, 'endTime': null},
      theirs: {'description': '對方的', 'startTime': null, 'endTime': null},
      previousConflicts: const {'description'},
    );
    expect(r.conflicts, {'description'});
  });

  test('entryFieldsOf:空 description 視為空字串,時間正規化成 HH:mm', () {
    const entry = TimelineEntry(
      id: 1,
      sortOrder: 0,
      title: 'a',
      version: 0,
      startTime: '9:05',
    );
    expect(entryFieldsOf(entry), {
      'description': '',
      'startTime': '09:05',
      'endTime': null,
    });
  });
}
