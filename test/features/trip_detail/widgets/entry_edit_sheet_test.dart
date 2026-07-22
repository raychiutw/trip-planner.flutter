import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoDatePicker;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trip_detail/widgets/entry_edit_sheet.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';

class _MockTripRepository extends Mock implements TripRepository {}

const _entry = TimelineEntry(
  id: 11,
  sortOrder: 0,
  startTime: '09:00',
  endTime: '10:00',
  title: '首里城',
  description: '世界遺產',
  version: 2,
);

TripDay _day(int dayNum, String date) =>
    TripDay(id: dayNum, dayNum: dayNum, date: date, version: 0);

Future<void> _open(
  WidgetTester tester,
  _MockTripRepository repo,
  EntryEditArgs args, {
  TargetPlatform platform = TargetPlatform.android,
  Stream<TimelineEntry>? entryStream,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        tripDaysProvider(
          't1',
        ).overrideWith((ref) => Stream.value(const <TripDay>[])),
        if (args case EntryEditExisting(:final entry))
          entryDetailProvider((
            tripId: 't1',
            entryId: entry.id,
          )).overrideWith((ref) => entryStream ?? Stream.value(entry)),
      ],
      child: MaterialApp(
        theme: AppTheme.light().copyWith(platform: platform),
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
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  group('entryTimeRangeValid', () {
    test('皆 null / 任一 null → true', () {
      expect(entryTimeRangeValid(null, null), isTrue);
      expect(
        entryTimeRangeValid(const TimeOfDay(hour: 9, minute: 0), null),
        isTrue,
      );
      expect(
        entryTimeRangeValid(null, const TimeOfDay(hour: 9, minute: 0)),
        isTrue,
      );
    });
    test('end > start → true；end <= start → false', () {
      expect(
        entryTimeRangeValid(
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 10, minute: 0),
        ),
        isTrue,
      );
      expect(
        entryTimeRangeValid(
          const TimeOfDay(hour: 10, minute: 0),
          const TimeOfDay(hour: 10, minute: 0),
        ),
        isFalse,
      );
      expect(
        entryTimeRangeValid(
          const TimeOfDay(hour: 11, minute: 0),
          const TimeOfDay(hour: 10, minute: 0),
        ),
        isFalse,
      );
    });
  });

  testWidgets('編輯模式：不顯示 legacy 標題欄 + 送出呼叫 updateEntry', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.recomputeTravel(tripId: 't1')).thenAnswer((_) async {});

    await _open(tester, repo, const EntryEditExisting(_entry));
    expect(find.byKey(const ValueKey('entry-edit-title')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateEntry(
        tripId: 't1',
        entryId: 11,
        expectedVersion: 2,
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).called(1);
    verify(() => repo.recomputeTravel(tripId: 't1')).called(1);
  });

  testWidgets('編輯模式：起訖時間在描述欄上方', (tester) async {
    final repo = _MockTripRepository();
    await _open(tester, repo, const EntryEditExisting(_entry));

    final startTop = tester
        .getTopLeft(find.byKey(const ValueKey('entry-edit-start')))
        .dy;
    final endTop = tester
        .getTopLeft(find.byKey(const ValueKey('entry-edit-end')))
        .dy;
    final descTop = tester
        .getTopLeft(find.byKey(const ValueKey('entry-edit-desc')))
        .dy;

    expect(startTop, lessThan(descTop));
    expect(endTop, lessThan(descTop));
    expect(
      tester.widget(find.byKey(const ValueKey('entry-edit-start'))),
      isA<InputChip>(),
    );
    expect(
      tester.widget(find.byKey(const ValueKey('entry-edit-end'))),
      isA<InputChip>(),
    );
  });

  testWidgets('備註使用可捲動的多行文字視圖與換行鍵盤', (tester) async {
    final repo = _MockTripRepository();
    await _open(tester, repo, const EntryEditExisting(_entry));

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('entry-edit-desc')),
    );
    expect(field.decoration?.labelText, '行程備註（選填）');
    expect(field.minLines, greaterThanOrEqualTo(4));
    expect(field.maxLines, greaterThan(field.minLines!));
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.textInputAction, TextInputAction.newline);
    expect(field.scrollPadding.bottom, greaterThan(TpSpacing.s6));
  });

  testWidgets('超過八行的 Unicode 備註可在輸入框內捲動且文字不遺失', (tester) async {
    final repo = _MockTripRepository();
    await _open(tester, repo, const EntryEditExisting(_entry));

    final fieldFinder = find.byKey(const ValueKey('entry-edit-desc'));
    final longNote = List.generate(
      12,
      (index) => '第 ${index + 1} 行：沖繩提醒 👨‍👩‍👧‍👦 café',
    ).join('\n');
    await tester.tap(fieldFinder);
    await tester.enterText(fieldFinder, longNote);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    final field = tester.widget<TextField>(fieldFinder);
    field.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpAndSettle();
    final editableFinder = find.byElementPredicate(
      (element) => element.renderObject is RenderEditable,
      description: 'RenderEditable inside the itinerary note field',
    );
    expect(editableFinder, findsOneWidget);
    final renderEditable = tester.renderObject<RenderEditable>(editableFinder);
    final initialOffset = renderEditable.offset.pixels;

    await tester.drag(fieldFinder, const Offset(0, -160));
    await tester.pumpAndSettle();

    expect(renderEditable.offset.pixels, greaterThan(initialOffset));
    expect(field.controller!.text, longNote);
    expect(field.controller!.text.split('\n'), hasLength(12));
  });

  testWidgets('行程備註編輯 description，不覆蓋唯讀的地點 POI note', (tester) async {
    final repo = _MockTripRepository();
    const entry = TimelineEntry(
      id: 11,
      sortOrder: 0,
      title: '首里城',
      description: '使用者行程備註',
      note: '地點資料備註',
      version: 2,
    );
    await _open(tester, repo, const EntryEditExisting(entry));

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('entry-edit-desc')),
    );
    expect(field.controller!.text, '使用者行程備註');
    expect(field.controller!.text, isNot(contains('地點資料備註')));
  });

  testWidgets('iOS compact time chip 開啟 Cupertino time picker', (tester) async {
    final repo = _MockTripRepository();
    await _open(
      tester,
      repo,
      const EntryEditExisting(_entry),
      platform: TargetPlatform.iOS,
    );

    await tester.tap(find.byKey(const ValueKey('entry-edit-start')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.text('取消'), findsWidgets);
    expect(find.text('完成'), findsOneWidget);
  });

  testWidgets('新增模式：送出呼叫 addEntryToDay(source custom)', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.addEntryToDay(
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
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});

    await _open(tester, repo, const EntryEditNew(2));
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '自由活動',
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-lat')),
      '26.21',
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-lng')),
      '127.68',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 't1',
        dayNum: 2,
        title: '自由活動',
        description: any(named: 'description'),
        poiType: 'attraction',
        lat: 26.21,
        lng: 127.68,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'custom',
      ),
    ).called(1);
  });

  testWidgets('新增模式：未填座標不能送出自訂停留點', (tester) async {
    final repo = _MockTripRepository();

    await _open(tester, repo, const EntryEditNew(2));
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '自由活動',
    );
    await tester.pump();

    expect(find.text('請填入緯度與經度'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('entry-edit-submit')),
        matching: find.byType(TextButton),
      ),
    );
    expect(button.onPressed, isNull);
    verifyNever(
      () => repo.addEntryToDay(
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
      ),
    );
  });

  testWidgets('新增模式：可帶 POI 分類與座標建立自訂停留點', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.addEntryToDay(
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
      ),
    ).thenAnswer((_) async {});

    await _open(tester, repo, const EntryEditNew(2));
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '日落觀景點',
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-lat')),
      '26.21',
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-lng')),
      '127.68',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-poi-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('活動').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 't1',
        dayNum: 2,
        title: '日落觀景點',
        description: any(named: 'description'),
        poiType: 'activity',
        lat: 26.21,
        lng: 127.68,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'custom',
      ),
    ).called(1);
    verify(() => repo.recomputeTravel(tripId: 't1', day: '2')).called(1);
  });

  testWidgets('新增模式：可切換加入日期', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.addEntryToDay(
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
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});

    await _open(
      tester,
      repo,
      EntryEditNew(1, days: [_day(1, '2026-07-01'), _day(3, '2026-07-03')]),
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-title')),
      '自由活動',
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-lat')),
      '26.21',
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-lng')),
      '127.68',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAY 3 · 2026-07-03').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 't1',
        dayNum: 3,
        title: '自由活動',
        description: any(named: 'description'),
        poiType: 'attraction',
        lat: 26.21,
        lng: 127.68,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'custom',
      ),
    ).called(1);
    verify(() => repo.recomputeTravel(tripId: 't1', day: '3')).called(1);
  });

  testWidgets('標題清空 → 送出鈕 disabled', (tester) async {
    final repo = _MockTripRepository();
    await _open(tester, repo, const EntryEditNew(1));
    final button = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('entry-edit-submit')),
        matching: find.byType(TextButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('bottom sheet 遇到 409 後保留草稿並用最新 version 重試', (tester) async {
    final repo = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    addTearDown(entries.close);
    final submittedVersions = <int>[];
    when(
      () => repo.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((invocation) async {
      final version = invocation.namedArguments[#expectedVersion]! as int;
      submittedVersions.add(version);
      if (submittedVersions.length == 1) {
        throw const ApiError(
          status: 409,
          code: 'STALE_ENTRY',
          message: 'stale',
        );
      }
    });
    when(() => repo.recomputeTravel(tripId: 't1')).thenAnswer((_) async {});

    await _open(
      tester,
      repo,
      const EntryEditExisting(_entry),
      entryStream: entries.stream,
    );
    entries.add(_entry);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '保留在 bottom sheet 的草稿',
    );

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    expect(submittedVersions, [2]);

    entries.add(
      const TimelineEntry(
        id: 11,
        sortOrder: 0,
        startTime: '09:00',
        endTime: '10:00',
        title: '首里城',
        description: '協作者的新備註',
        version: 3,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, '保留在 bottom sheet 的草稿'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('保留你的版本？'), findsOneWidget);
    await tester.tap(find.text('保留我的版本'));
    await tester.pumpAndSettle();

    expect(submittedVersions, [2, 3]);
  });

  testWidgets('bottom sheet 接受新版後不會被較舊的 SWR detail 倒退 OCC version', (
    tester,
  ) async {
    final repo = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    addTearDown(entries.close);
    const initialEntry = TimelineEntry(
      id: 11,
      sortOrder: 0,
      startTime: '09:00',
      endTime: '10:00',
      title: '首里城',
      description: '時間軸原始版本',
      version: 2,
    );
    when(
      () => repo.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.recomputeTravel(tripId: 't1')).thenAnswer((_) async {});

    await _open(
      tester,
      repo,
      const EntryEditExisting(initialEntry),
      entryStream: entries.stream,
    );
    entries.add(
      const TimelineEntry(
        id: 11,
        sortOrder: 0,
        startTime: '09:00',
        endTime: '10:00',
        title: '首里城',
        description: '時間軸剛載入的新版',
        version: 5,
      ),
    );
    await tester.pumpAndSettle();
    entries.add(
      const TimelineEntry(
        id: 11,
        sortOrder: 0,
        startTime: '08:00',
        endTime: '09:00',
        title: '首里城',
        description: '裝置裡較舊的快取',
        version: 4,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '時間軸剛載入的新版'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    verify(
      () => repo.updateEntry(
        tripId: 't1',
        entryId: 11,
        expectedVersion: 5,
        description: '時間軸剛載入的新版',
        startTime: '09:00',
        endTime: '10:00',
      ),
    ).called(1);
  });

  testWidgets('新版在 STALE 回應前先到達時，可直接用最新 version 重試', (tester) async {
    final repo = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    final firstSave = Completer<void>();
    final submittedVersions = <int>[];
    addTearDown(entries.close);
    when(
      () => repo.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((invocation) {
      final version = invocation.namedArguments[#expectedVersion]! as int;
      submittedVersions.add(version);
      return submittedVersions.length == 1
          ? firstSave.future
          : Future<void>.value();
    });
    when(() => repo.recomputeTravel(tripId: 't1')).thenAnswer((_) async {});

    await _open(
      tester,
      repo,
      const EntryEditExisting(_entry),
      entryStream: entries.stream,
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '我的草稿',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pump();

    entries.add(
      const TimelineEntry(
        id: 11,
        sortOrder: 0,
        startTime: '09:00',
        endTime: '10:00',
        title: '首里城',
        description: '世界遺產',
        version: 3,
      ),
    );
    await tester.pump();
    firstSave.completeError(
      const ApiError(status: 409, code: 'STALE_ENTRY', message: 'stale'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    expect(submittedVersions, [2, 3]);
  });

  testWidgets('STALE 後重新載入會維持鎖定，直到取得更高 version', (tester) async {
    final repo = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    final submittedVersions = <int>[];
    addTearDown(entries.close);
    when(
      () => repo.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((invocation) async {
      final version = invocation.namedArguments[#expectedVersion]! as int;
      submittedVersions.add(version);
      if (submittedVersions.length == 1) {
        throw const ApiError(
          status: 409,
          code: 'STALE_ENTRY',
          message: 'stale',
        );
      }
    });
    when(() => repo.recomputeTravel(tripId: 't1')).thenAnswer((_) async {});

    await _open(
      tester,
      repo,
      const EntryEditExisting(_entry),
      entryStream: entries.stream,
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '網路不穩時仍保留的草稿',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('entry-edit-stale-retry')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-stale-retry')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '網路不穩時仍保留的草稿'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('entry-edit-stale-retry')),
      findsOneWidget,
      reason: '重新觸發載入不代表已取得可安全重送的新版',
    );
    final blockedSubmit = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('entry-edit-submit')),
        matching: find.byType(TextButton),
      ),
    );
    expect(blockedSubmit.onPressed, isNull);

    entries.add(
      const TimelineEntry(
        id: 11,
        sortOrder: 0,
        startTime: '09:00',
        endTime: '10:00',
        title: '首里城',
        description: '協作者的新備註',
        version: 3,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-edit-stale-retry')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('保留你的版本？'), findsOneWidget);
    await tester.tap(find.text('保留我的版本'));
    await tester.pumpAndSettle();

    expect(submittedVersions, [2, 3]);
  });

  testWidgets('STALE 重新載入失敗會持續顯示錯誤並保留草稿', (tester) async {
    final repo = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    addTearDown(entries.close);
    when(
      () => repo.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenThrow(
      const ApiError(status: 409, code: 'STALE_ENTRY', message: 'stale'),
    );

    await _open(
      tester,
      repo,
      const EntryEditExisting(_entry),
      entryStream: entries.stream,
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '重新載入失敗也不能消失的草稿',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    entries.addError(
      const ApiError(status: 503, code: 'SYS_TEMPORARY', message: 'offline'),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('entry-edit-refresh-error')),
      findsOneWidget,
    );
    expect(find.text('無法載入最新版本；你的草稿仍保留。'), findsOneWidget);
    expect(find.widgetWithText(TextField, '重新載入失敗也不能消失的草稿'), findsOneWidget);
    expect(find.text('重試載入'), findsOneWidget);
  });

  testWidgets('STALE 重新載入得知停留點已刪除時顯示不同結果', (tester) async {
    final repo = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    addTearDown(entries.close);
    when(
      () => repo.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenThrow(
      const ApiError(status: 409, code: 'STALE_ENTRY', message: 'stale'),
    );

    await _open(
      tester,
      repo,
      const EntryEditExisting(_entry),
      entryStream: entries.stream,
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '停留點刪除後仍可複製的草稿',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    entries.addError(
      const ApiError(status: 404, code: 'ENTRY_NOT_FOUND', message: 'missing'),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('entry-edit-refresh-error')),
      findsOneWidget,
    );
    expect(find.text('此停留點已被刪除，無法再儲存；你的草稿仍保留。'), findsOneWidget);
    expect(find.text('重試載入'), findsNothing);
    expect(find.widgetWithText(TextField, '停留點刪除後仍可複製的草稿'), findsOneWidget);
    final submitButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('entry-edit-submit')),
        matching: find.byType(TextButton),
      ),
    );
    expect(submitButton.onPressed, isNull);
  });

  testWidgets('bottom sheet 直接收到 404 refresh 時停用儲存', (tester) async {
    final repo = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    addTearDown(entries.close);

    await _open(
      tester,
      repo,
      const EntryEditExisting(_entry),
      entryStream: entries.stream,
    );
    entries.addError(
      const ApiError(status: 404, code: 'ENTRY_NOT_FOUND', message: 'missing'),
    );
    await tester.pumpAndSettle();

    expect(find.text('此停留點已被刪除，無法再儲存；你的草稿仍保留。'), findsOneWidget);
    final submitButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('entry-edit-submit')),
        matching: find.byType(TextButton),
      ),
    );
    expect(submitButton.onPressed, isNull);
  });

  testWidgets('非 STALE_ENTRY 的 409 不會卡在等待 fresh version', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenThrow(
      const ApiError(status: 409, code: 'OTHER_CONFLICT', message: 'conflict'),
    );

    await _open(tester, repo, const EntryEditExisting(_entry));
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '仍可重試的草稿',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('儲存失敗，請稍後再試'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    verify(
      () => repo.updateEntry(
        tripId: 't1',
        entryId: 11,
        expectedVersion: 2,
        description: '仍可重試的草稿',
        startTime: '09:00',
        endTime: '10:00',
      ),
    ).called(2);
  });

  testWidgets('空值與等價時間格式不會誤判成協作者衝突', (tester) async {
    final repo = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    addTearDown(entries.close);
    when(
      () => repo.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.recomputeTravel(tripId: 't1')).thenAnswer((_) async {});
    const initial = TimelineEntry(
      id: 11,
      sortOrder: 0,
      startTime: '9:00',
      endTime: '10:00',
      title: '首里城',
      version: 2,
    );
    await _open(
      tester,
      repo,
      const EntryEditExisting(initial),
      entryStream: entries.stream,
    );
    entries.add(initial);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '我的草稿',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-start-clear')));
    await tester.pumpAndSettle();

    entries.add(
      const TimelineEntry(
        id: 11,
        sortOrder: 0,
        startTime: '09:00',
        endTime: '10:00',
        title: '首里城',
        description: '',
        version: 3,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    expect(find.text('保留你的版本？'), findsNothing);
    verify(
      () => repo.updateEntry(
        tripId: 't1',
        entryId: 11,
        expectedVersion: 3,
        description: '我的草稿',
        startTime: null,
        endTime: '10:00',
      ),
    ).called(1);
  });

  testWidgets('協作者同時修改起訖時間時可取消覆蓋並保留本機草稿', (tester) async {
    final repo = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    addTearDown(entries.close);
    await _open(
      tester,
      repo,
      const EntryEditExisting(_entry),
      entryStream: entries.stream,
    );
    entries.add(_entry);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-edit-start-clear')));
    await tester.tap(find.byKey(const ValueKey('entry-edit-end-clear')));
    await tester.pumpAndSettle();
    expect(find.text('開始 未設定'), findsOneWidget);
    expect(find.text('結束 未設定'), findsOneWidget);

    entries.add(
      const TimelineEntry(
        id: 11,
        sortOrder: 0,
        startTime: '11:00',
        endTime: '12:00',
        title: '首里城',
        description: '世界遺產',
        version: 3,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('保留你的版本？'), findsOneWidget);
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();

    expect(find.text('開始 未設定'), findsOneWidget);
    expect(find.text('結束 未設定'), findsOneWidget);
    verifyNever(
      () => repo.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    );
  });
}
