import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/trip_notes_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/note_section.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

TripNotes _sampleNotes() {
  return const TripNotes(
    flights: [
      TripFlight(
        id: 1,
        sortOrder: 0,
        version: 1,
        airline: '長榮航空',
        flightNo: 'BR112',
        departAirport: 'TPE',
        arriveAirport: 'OKA',
        departAt: '2026-04-01 08:30',
      ),
    ],
    lodgings: [
      TripLodging(
        id: 2,
        sortOrder: 0,
        version: 1,
        name: '那霸海濱飯店',
        address: '沖繩縣那霸市西1-2-1',
        checkInAt: '2026-04-01 15:00',
        checkOutAt: '2026-04-03 10:00',
      ),
    ],
    reservations: [
      TripReservation(
        id: 3,
        sortOrder: 0,
        version: 1,
        kind: 'restaurant',
        title: '燒肉乃我那霸 新館',
        reservedAt: '2026-04-01 19:00',
      ),
    ],
    pretripNotes: [],
    emergencyContacts: [
      TripEmergencyContact(
        id: 4,
        sortOrder: 0,
        version: 1,
        name: '台北駐日經濟文化代表處那霸分處',
        kind: 'embassy',
        phone: '+81-98-862-7008',
      ),
      TripEmergencyContact(
        id: 5,
        sortOrder: 1,
        version: 1,
        name: '沖繩縣警',
        kind: 'police',
        phone: '110',
      ),
    ],
  );
}

Widget _buildScreen(TripNotes notes, {_MockTripRepository? repo}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const TripNotesScreen(tripId: 'trip-1'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      tripNotesProvider.overrideWith((ref, tripId) => Stream.value(notes)),
      if (repo != null) tripRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(NoteSection.flights);
    registerFallbackValue(<String, dynamic>{});
  });

  testWidgets('渲染 AppBar 標題、5 個 section header 與 count badge', (tester) async {
    await tester.pumpWidget(_buildScreen(_sampleNotes()));
    await tester.pumpAndSettle();

    expect(find.text('行程筆記'), findsOneWidget);
    expect(find.text('航班'), findsOneWidget);
    expect(find.text('住宿'), findsOneWidget);
    expect(find.text('預訂'), findsOneWidget);
    expect(find.text('行前須知'), findsOneWidget);
    expect(find.text('緊急聯絡'), findsOneWidget);

    const expectedCounts = {
      'flights': '1',
      'lodgings': '1',
      'reservations': '1',
      'pretrip': '0',
      'emergency': '2',
    };
    expectedCounts.forEach((sectionSuffix, count) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('notes-count-$sectionSuffix')),
          matching: find.text(count),
        ),
        findsOneWidget,
        reason: 'section $sectionSuffix 的 count badge 應為 $count',
      );
    });
  });

  testWidgets('航班預設展開顯示 row；展開住宿、預訂顯示各自欄位', (tester) async {
    await tester.pumpWidget(_buildScreen(_sampleNotes()));
    await tester.pumpAndSettle();

    // 航班預設展開（mobile 行為）
    expect(find.text('長榮航空 BR112'), findsOneWidget);
    expect(find.text('TPE → OKA'), findsOneWidget);
    expect(find.text('2026-04-01 08:30'), findsOneWidget);

    // 展開住宿：name、checkInAt~checkOutAt、address
    await tester.tap(find.text('住宿'));
    await tester.pumpAndSettle();
    expect(find.text('那霸海濱飯店'), findsOneWidget);
    expect(find.text('2026-04-01 15:00 ~ 2026-04-03 10:00'), findsOneWidget);
    expect(find.text('沖繩縣那霸市西1-2-1'), findsOneWidget);

    // 展開預訂：kind chip + title + reservedAt
    await tester.tap(find.text('預訂'));
    await tester.pumpAndSettle();
    expect(find.text('餐廳'), findsOneWidget);
    expect(find.text('燒肉乃我那霸 新館'), findsOneWidget);
    expect(find.text('2026-04-01 19:00'), findsOneWidget);
  });

  testWidgets('展開緊急聯絡：name + kind + phone', (tester) async {
    await tester.pumpWidget(_buildScreen(_sampleNotes()));
    await tester.pumpAndSettle();

    // 先收合預設展開的航班，確保緊急聯絡內容在視窗內
    await tester.tap(find.text('航班'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('緊急聯絡'));
    await tester.pumpAndSettle();

    expect(find.text('台北駐日經濟文化代表處那霸分處'), findsOneWidget);
    expect(find.text('大使館'), findsOneWidget);
    expect(find.text('+81-98-862-7008'), findsOneWidget);
    expect(find.text('沖繩縣警'), findsOneWidget);
    expect(find.text('110'), findsOneWidget);
  });

  testWidgets('空 section：展開行前須知顯示「尚無資料」', (tester) async {
    await tester.pumpWidget(_buildScreen(_sampleNotes()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('行前須知'));
    await tester.pumpAndSettle();

    expect(find.text('尚無資料'), findsOneWidget);
  });

  testWidgets('全空 notes：5 個 count 皆 0，預設展開的航班顯示「尚無資料」', (tester) async {
    await tester.pumpWidget(_buildScreen(const TripNotes()));
    await tester.pumpAndSettle();

    for (final sectionSuffix in [
      'flights',
      'lodgings',
      'reservations',
      'pretrip',
      'emergency',
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('notes-count-$sectionSuffix')),
          matching: find.text('0'),
        ),
        findsOneWidget,
        reason: 'section $sectionSuffix 的 count badge 應為 0',
      );
    }
    expect(find.text('尚無資料'), findsOneWidget);
  });

  testWidgets('點 flight row → 開編輯 sheet（預填）', (tester) async {
    await tester.pumpWidget(_buildScreen(_sampleNotes()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('長榮航空 BR112'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-edit-submit')), findsOneWidget);
    expect(find.widgetWithText(TextField, '長榮航空'), findsOneWidget);
  });

  testWidgets('左滑 flight row → 確認 → deleteNote', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.deleteNote(
        any(),
        tripId: any(named: 'tripId'),
        rowId: any(named: 'rowId'),
      ),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(_buildScreen(_sampleNotes(), repo: repo));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('note-dismiss-flights-1')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();

    verify(
      () => repo.deleteNote(NoteSection.flights, tripId: 'trip-1', rowId: 1),
    ).called(1);
  });

  testWidgets('點「新增航班」→ 開 create sheet', (tester) async {
    await tester.pumpWidget(_buildScreen(_sampleNotes()));
    await tester.pumpAndSettle();

    final addBtn = find.byKey(const ValueKey('note-add-flights'));
    await tester.ensureVisible(addBtn);
    await tester.pumpAndSettle();
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-edit-submit')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '新增'), findsOneWidget);
  });

  testWidgets('flight row 有 drag handle', (tester) async {
    await tester.pumpWidget(_buildScreen(_sampleNotes()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-drag-flights-1')), findsOneWidget);
  });
}
