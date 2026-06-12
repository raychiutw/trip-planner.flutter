import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/notes/note_edit_sheet.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/note_section.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

Future<void> _open(
  WidgetTester tester,
  _MockTripRepository repo, {
  required NoteSection section,
  Map<String, dynamic>? initialFields,
  int? rowId,
  int? version,
}) async {
  // 加高測試視窗,讓多欄位表單 + 送出鈕都在畫面內（免捲動）。
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        tripNotesProvider(
          't1',
        ).overrideWith((ref) => Stream.value(const TripNotes())),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showNoteEditSheet(
                context,
                tripId: 't1',
                section: section,
                initialFields: initialFields,
                rowId: rowId,
                version: version,
              ),
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
  setUpAll(() {
    registerFallbackValue(NoteSection.flights);
    registerFallbackValue(<String, dynamic>{});
  });

  testWidgets('create reservations：填欄位 + 選 enum → createNote', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.createNote(
        any(),
        tripId: any(named: 'tripId'),
        fields: any(named: 'fields'),
      ),
    ).thenAnswer((_) async {});
    await _open(tester, repo, section: NoteSection.reservations);

    await tester.enterText(
      find.byKey(const ValueKey('note-field-title')),
      '晚餐',
    );
    await tester.tap(find.byKey(const ValueKey('note-enum-kind-experience')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
    await tester.pumpAndSettle();

    final fields =
        verify(
              () => repo.createNote(
                NoteSection.reservations,
                tripId: 't1',
                fields: captureAny(named: 'fields'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(fields['title'], '晚餐');
    expect(fields['kind'], 'experience');
  });

  testWidgets('create reservations：未動 kind → 預設 restaurant', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.createNote(
        any(),
        tripId: any(named: 'tripId'),
        fields: any(named: 'fields'),
      ),
    ).thenAnswer((_) async {});
    await _open(tester, repo, section: NoteSection.reservations);

    await tester.enterText(
      find.byKey(const ValueKey('note-field-title')),
      '午餐',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
    await tester.pumpAndSettle();

    final fields =
        verify(
              () => repo.createNote(
                any(),
                tripId: any(named: 'tripId'),
                fields: captureAny(named: 'fields'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(fields['kind'], 'restaurant');
  });

  testWidgets('integer party_size 轉 int', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.createNote(
        any(),
        tripId: any(named: 'tripId'),
        fields: any(named: 'fields'),
      ),
    ).thenAnswer((_) async {});
    await _open(tester, repo, section: NoteSection.reservations);

    await tester.enterText(
      find.byKey(const ValueKey('note-field-title')),
      '午餐',
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-field-party_size')),
      '4',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
    await tester.pumpAndSettle();

    final fields =
        verify(
              () => repo.createNote(
                any(),
                tripId: any(named: 'tripId'),
                fields: captureAny(named: 'fields'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(fields['party_size'], 4);
    expect(fields['party_size'], isA<int>());
  });

  testWidgets('必填（reservations title）空 → 送出鈕 disabled', (tester) async {
    await _open(
      tester,
      _MockTripRepository(),
      section: NoteSection.reservations,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('note-edit-submit')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'edit reservations：預填 + 改 title → updateNote(rowId, expectedVersion)',
    (tester) async {
      final repo = _MockTripRepository();
      when(
        () => repo.updateNote(
          any(),
          tripId: any(named: 'tripId'),
          rowId: any(named: 'rowId'),
          fields: any(named: 'fields'),
          expectedVersion: any(named: 'expectedVersion'),
        ),
      ).thenAnswer((_) async {});
      await _open(
        tester,
        repo,
        section: NoteSection.reservations,
        initialFields: const {
          'kind': 'restaurant',
          'title': '舊',
          'reserved_at': '',
          'party_size': 2,
          'reservation_no': '',
          'phone': '',
          'note': '',
        },
        rowId: 5,
        version: 3,
      );

      expect(find.widgetWithText(TextField, '舊'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('note-field-title')),
        '新',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
      await tester.pumpAndSettle();

      final fields =
          verify(
                () => repo.updateNote(
                  NoteSection.reservations,
                  tripId: 't1',
                  rowId: 5,
                  fields: captureAny(named: 'fields'),
                  expectedVersion: 3,
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(fields['title'], '新');
    },
  );
}
