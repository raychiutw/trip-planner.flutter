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
  EntryEditArgs args,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        tripDaysProvider(
          't1',
        ).overrideWith((ref) => Stream.value(const <TripDay>[])),
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
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryToDay(
        tripId: 't1',
        dayNum: 2,
        title: '自由活動',
        description: any(named: 'description'),
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
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('entry-edit-submit')),
    );
    expect(button.onPressed, isNull);
  });
}
