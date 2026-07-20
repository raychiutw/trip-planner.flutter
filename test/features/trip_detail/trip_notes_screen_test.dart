import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/trip_notes_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/note_section.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/trip_request.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_glass_expansion_section.dart';

class _MockTripRepository extends Mock implements TripRepository {}

class _MockRequestsRepository extends Mock implements RequestsRepository {}

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

Widget _buildScreen(
  TripNotes notes, {
  _MockTripRepository? repo,
  _MockRequestsRepository? requestsRepo,
  Stream<TripNotes> Function(Ref ref, String tripId)? notesBuilder,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const TripNotesScreen(tripId: 'trip-1'),
      ),
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) => const Scaffold(body: Text('trip-page')),
      ),
      GoRoute(
        path: '/trips/:tripId/map',
        builder: (context, state) => const Scaffold(body: Text('map-page')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      tripNotesProvider.overrideWith(
        notesBuilder ?? (ref, tripId) => Stream.value(notes),
      ),
      if (repo != null) tripRepositoryProvider.overrideWithValue(repo),
      if (requestsRepo != null)
        requestsRepositoryProvider.overrideWithValue(requestsRepo),
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
    expect(find.byKey(const ValueKey('trip-section-scope')), findsOneWidget);
    expect(find.text('筆記'), findsOneWidget);
    expect(find.text('航班'), findsOneWidget);
    expect(find.text('住宿'), findsOneWidget);
    expect(find.text('預訂'), findsOneWidget);
    expect(find.text('行前須知'), findsOneWidget);
    expect(find.text('緊急聯絡'), findsOneWidget);
    expect(find.byType(TpGlassExpansionSection), findsNWidgets(5));

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

  testWidgets('從筆記 scope 可回到行程', (tester) async {
    await tester.pumpWidget(_buildScreen(_sampleNotes()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-section-scope')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-section-itinerary')));
    await tester.pumpAndSettle();

    expect(find.text('trip-page'), findsOneWidget);
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
    await tester.drag(
      find.byKey(const ValueKey('trip-notes-list')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
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

    await tester.drag(find.byType(ListView), const Offset(0, -120));
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
    await tester.tap(
      find.byKey(
        const ValueKey<Object>((
          'swipe-delete-action',
          ValueKey('note-dismiss-flights-1'),
        )),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('刪除')),
    );
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
    expect(find.widgetWithText(TextButton, '新增'), findsOneWidget);
  });

  testWidgets('flight row 有 drag handle', (tester) async {
    await tester.pumpWidget(_buildScreen(_sampleNotes()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-drag-flights-1')), findsOneWidget);
  });

  testWidgets('展開行前須知後可觸發一般 AI 生成並顯示 pending 狀態', (tester) async {
    final repo = _MockTripRepository();
    final requestsRepo = _MockRequestsRepository();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).thenAnswer(
      (_) async => (
        jobId: 7,
        requestId: 99,
        status: 'pending',
        tripId: 'trip-1',
        docType: 'tips',
      ),
    );
    when(
      () => requestsRepo.watchRequestEvents(99),
    ).thenAnswer((_) => const Stream<TripRequestEvent>.empty());

    await tester.pumpWidget(
      _buildScreen(_sampleNotes(), repo: repo, requestsRepo: requestsRepo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('行前須知'));
    await tester.pumpAndSettle();

    final aiButton = find.byKey(const ValueKey('note-ai-tips'));
    expect(aiButton, findsOneWidget);

    await tester.ensureVisible(aiButton);
    await tester.tap(aiButton);
    await tester.pump();
    await tester.pump();

    verify(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).called(1);
    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pump();
    expect(find.byKey(const ValueKey('notes-ai-pending')), findsOneWidget);
    expect(find.textContaining('AI 正在生成行前須知'), findsOneWidget);
  });

  testWidgets('沒有住宿時住宿 AI 生成保持 disabled 並說明原因', (tester) async {
    await tester.pumpWidget(_buildScreen(const TripNotes()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('行前須知'));
    await tester.pumpAndSettle();

    final lodgingAiButton = find.byKey(const ValueKey('note-ai-lodging-tips'));
    expect(lodgingAiButton, findsOneWidget);
    expect(tester.widget<OutlinedButton>(lodgingAiButton).onPressed, isNull);
    expect(find.text('需先新增住宿'), findsOneWidget);
  });

  testWidgets('緊急聯絡 AI 生成完成後清掉 pending 並重新載入筆記', (tester) async {
    final repo = _MockTripRepository();
    final requestsRepo = _MockRequestsRepository();
    final controller = StreamController<TripRequestEvent>(sync: true);
    addTearDown(() {
      controller.close();
    });
    var loadCount = 0;
    when(
      () => repo.generateNotes(NoteGenerationType.emergency, tripId: 'trip-1'),
    ).thenAnswer(
      (_) async => (
        jobId: 8,
        requestId: 100,
        status: 'pending',
        tripId: 'trip-1',
        docType: 'emergency',
      ),
    );
    when(
      () => requestsRepo.watchRequestEvents(100),
    ).thenAnswer((_) => controller.stream);

    await tester.pumpWidget(
      _buildScreen(
        _sampleNotes(),
        repo: repo,
        requestsRepo: requestsRepo,
        notesBuilder: (ref, tripId) {
          loadCount += 1;
          return Stream.value(_sampleNotes());
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('緊急聯絡'));
    await tester.pumpAndSettle();
    final aiButton = find.byKey(const ValueKey('note-ai-emergency'));
    await tester.ensureVisible(aiButton);
    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pump();
    await tester.tap(aiButton);
    await tester.pump();
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pump();
    expect(find.byKey(const ValueKey('notes-ai-pending')), findsOneWidget);
    controller.add(const TripRequestEvent(status: RequestStatus.completed));
    await tester.pump();
    await tester.pump();

    verify(
      () => repo.generateNotes(NoteGenerationType.emergency, tripId: 'trip-1'),
    ).called(1);
    expect(find.byKey(const ValueKey('notes-ai-pending')), findsNothing);
    expect(loadCount, greaterThan(1));
  });
}
