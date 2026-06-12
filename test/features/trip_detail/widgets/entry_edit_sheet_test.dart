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

  testWidgets('編輯模式：預填標題 + 送出呼叫 updateEntry', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});

    await _open(tester, repo, const EntryEditExisting(_entry));
    expect(find.widgetWithText(TextField, '首里城'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateEntry(
        tripId: 't1',
        entryId: 11,
        expectedVersion: 2,
        title: '首里城',
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).called(1);
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
