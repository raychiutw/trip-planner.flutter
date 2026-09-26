import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
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
  TripNotes notes = const TripNotes(),
  Size size = const Size(1200, 3200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        tripNotesProvider('t1').overrideWith((ref) => Stream.value(notes)),
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

  for (final (section, requiredKey, lastKey, latestNotes)
      in <(NoteSection, String, String, TripNotes)>[
        (
          NoteSection.flights,
          'airline',
          'note-field-note',
          const TripNotes(
            flights: [
              TripFlight(id: 5, sortOrder: 0, version: 4, airline: '原值'),
            ],
          ),
        ),
        (
          NoteSection.lodgings,
          'name',
          'note-field-note',
          const TripNotes(
            lodgings: [
              TripLodging(id: 5, sortOrder: 0, version: 4, name: '原值'),
            ],
          ),
        ),
        (
          NoteSection.reservations,
          'title',
          'note-field-note',
          const TripNotes(
            reservations: [
              TripReservation(id: 5, sortOrder: 0, version: 4, title: '原值'),
            ],
          ),
        ),
        (
          NoteSection.pretrip,
          'title',
          'note-field-content',
          const TripNotes(
            pretripNotes: [
              TripPretripNote(id: 5, sortOrder: 0, version: 4, title: '原值'),
            ],
          ),
        ),
        (
          NoteSection.emergency,
          'name',
          'note-enum-kind-other',
          const TripNotes(
            emergencyContacts: [
              TripEmergencyContact(id: 5, sortOrder: 0, version: 4, name: '原值'),
            ],
          ),
        ),
      ]) {
    testWidgets('${section.name} 的失敗與 409 均保留草稿，重試可儲存', (tester) async {
      final repo = _MockTripRepository();
      var attempts = 0;
      when(
        () => repo.fetchFreshNotes('t1'),
      ).thenAnswer((_) async => latestNotes);
      when(
        () => repo.updateNote(
          any(),
          tripId: any(named: 'tripId'),
          rowId: any(named: 'rowId'),
          fields: any(named: 'fields'),
          expectedVersion: any(named: 'expectedVersion'),
        ),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          throw const ApiError(status: 500, code: 'HTTP_500', message: '暫時失敗');
        }
        if (attempts == 2) {
          throw const ApiError(
            status: 409,
            code: 'STALE_ENTRY',
            message: '版本已更新',
          );
        }
      });
      await _open(
        tester,
        repo,
        section: section,
        initialFields: {requiredKey: '原值'},
        rowId: 5,
        version: 3,
        size: const Size(390, 844),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
      await tester.pumpAndSettle();

      final lastField = find.byKey(ValueKey(lastKey));
      await tester.ensureVisible(lastField);
      await tester.pumpAndSettle();
      expect(lastField.hitTestable(), findsOneWidget);
      await tester.enterText(
        find.byKey(ValueKey('note-field-$requiredKey')),
        '我的草稿',
      );
      for (final message in ['儲存失敗，請稍後再試', '已載入最新版本。你的草稿已保留，請再次儲存。']) {
        await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
        await tester.pumpAndSettle();
        final banner = find.byKey(const ValueKey('note-edit-error'));
        await tester.ensureVisible(banner);
        await tester.pumpAndSettle();
        expect(banner.hitTestable(), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(find.text('我的草稿'), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
      await tester.pumpAndSettle();
      expect(attempts, 3);
      verify(
        () => repo.updateNote(
          section,
          tripId: 't1',
          rowId: 5,
          fields: {requiredKey: '我的草稿'},
          expectedVersion: 4,
        ),
      ).called(1);
      expect(find.byKey(const ValueKey('note-edit-submit')), findsNothing);
      expect(find.text('open').hitTestable(), findsOneWidget);
    });
  }

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
    final button = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('note-edit-submit')),
        matching: find.byType(TextButton),
      ),
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

  testWidgets('409 後保留草稿並以最新版本再次儲存', (tester) async {
    final repo = _MockTripRepository();
    const latestNotes = TripNotes(
      reservations: [
        TripReservation(
          id: 5,
          sortOrder: 0,
          version: 4,
          title: '原標題',
          phone: '02-2345-6789',
        ),
      ],
    );
    when(() => repo.fetchFreshNotes('t1')).thenAnswer((_) async => latestNotes);
    when(
      () => repo.updateNote(
        any(),
        tripId: any(named: 'tripId'),
        rowId: any(named: 'rowId'),
        fields: any(named: 'fields'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    ).thenAnswer((invocation) async {
      if (invocation.namedArguments[#expectedVersion] != 4) {
        throw const ApiError(
          status: 409,
          code: 'STALE_ENTRY',
          message: '版本已更新',
        );
      }
    });

    await _open(
      tester,
      repo,
      section: NoteSection.reservations,
      initialFields: const {'title': '原標題'},
      rowId: 5,
      version: 3,
      notes: latestNotes,
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-field-title')),
      '我的草稿',
    );
    await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('我的草稿'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
    await tester.pumpAndSettle();
    verify(
      () => repo.updateNote(
        NoteSection.reservations,
        tripId: 't1',
        rowId: 5,
        fields: any(named: 'fields'),
        expectedVersion: 3,
      ),
    ).called(1);
    final retriedFields =
        verify(
              () => repo.updateNote(
                NoteSection.reservations,
                tripId: 't1',
                rowId: 5,
                fields: captureAny(named: 'fields'),
                expectedVersion: 4,
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(retriedFields, {'title': '我的草稿'});
    expect(find.text('編輯預訂'), findsNothing);
  });

  testWidgets('同欄位衝突須確認覆蓋，取消時保留草稿', (tester) async {
    final repo = _MockTripRepository();
    when(() => repo.fetchFreshNotes('t1')).thenAnswer(
      (_) async => const TripNotes(
        reservations: [
          TripReservation(id: 5, sortOrder: 0, version: 4, title: '協作者標題'),
        ],
      ),
    );
    when(
      () => repo.updateNote(
        any(),
        tripId: any(named: 'tripId'),
        rowId: any(named: 'rowId'),
        fields: any(named: 'fields'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    ).thenAnswer((invocation) async {
      if (invocation.namedArguments[#expectedVersion] == 3) {
        throw const ApiError(
          status: 409,
          code: 'STALE_ENTRY',
          message: '版本已更新',
        );
      }
    });

    await _open(
      tester,
      repo,
      section: NoteSection.reservations,
      initialFields: const {'title': '原標題'},
      rowId: 5,
      version: 3,
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-field-title')),
      '我的草稿',
    );
    await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('協作者也修改了相同欄位。繼續會以你的草稿覆蓋那些欄位。'), findsOneWidget);
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(find.text('我的草稿'), findsOneWidget);
    verifyNever(
      () => repo.updateNote(
        NoteSection.reservations,
        tripId: 't1',
        rowId: 5,
        fields: any(named: 'fields'),
        expectedVersion: 4,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留我的修改'));
    await tester.pumpAndSettle();
    verify(
      () => repo.updateNote(
        NoteSection.reservations,
        tripId: 't1',
        rowId: 5,
        fields: {'title': '我的草稿'},
        expectedVersion: 4,
      ),
    ).called(1);
    expect(find.text('編輯預訂'), findsNothing);
  });

  testWidgets('409 後最新版本讀取失敗可重試且不丟草稿', (tester) async {
    final repo = _MockTripRepository();
    var fetchCount = 0;
    when(() => repo.fetchFreshNotes('t1')).thenAnswer((_) async {
      fetchCount++;
      if (fetchCount == 1) {
        throw const ApiError(status: 500, code: 'HTTP_500', message: '暫時失敗');
      }
      return const TripNotes(
        reservations: [
          TripReservation(id: 5, sortOrder: 0, version: 4, title: '原標題'),
        ],
      );
    });
    when(
      () => repo.updateNote(
        any(),
        tripId: any(named: 'tripId'),
        rowId: any(named: 'rowId'),
        fields: any(named: 'fields'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    ).thenAnswer((invocation) async {
      if (invocation.namedArguments[#expectedVersion] == 3) {
        throw const ApiError(
          status: 409,
          code: 'STALE_ENTRY',
          message: '版本已更新',
        );
      }
    });

    await _open(
      tester,
      repo,
      section: NoteSection.reservations,
      initialFields: const {'title': '原標題'},
      rowId: 5,
      version: 3,
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-field-title')),
      '我的草稿',
    );
    await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('無法載入最新版本。你的草稿已保留，請重試。'), findsOneWidget);
    expect(find.text('我的草稿'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('note-edit-error')))
          .properties
          .liveRegion,
      isTrue,
    );

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('編輯預訂'), findsNothing);
    expect(fetchCount, 2);
  });

  testWidgets('409 後原筆記已刪除可明確另存草稿為新筆記', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.fetchFreshNotes('t1'),
    ).thenAnswer((_) async => const TripNotes());
    when(
      () => repo.updateNote(
        any(),
        tripId: any(named: 'tripId'),
        rowId: any(named: 'rowId'),
        fields: any(named: 'fields'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    ).thenThrow(
      const ApiError(status: 409, code: 'STALE_ENTRY', message: '版本已更新'),
    );
    when(
      () => repo.createNote(
        any(),
        tripId: any(named: 'tripId'),
        fields: any(named: 'fields'),
      ),
    ).thenAnswer((_) async {});

    await _open(
      tester,
      repo,
      section: NoteSection.reservations,
      initialFields: const {'title': '原標題'},
      rowId: 5,
      version: 3,
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-field-title')),
      '我的草稿',
    );
    await tester.tap(find.byKey(const ValueKey('note-edit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('這筆筆記已被刪除。你的草稿仍在表單中。'), findsOneWidget);
    expect(find.text('我的草稿'), findsOneWidget);
    await tester.tap(find.text('另存為新筆記'));
    await tester.pumpAndSettle();
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
    expect(fields['title'], '我的草稿');
    expect(find.text('編輯預訂'), findsNothing);
  });
}
