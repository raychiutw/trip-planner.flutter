import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/trip_notes_screen.dart';
import 'package:tripline/models/chat.dart';
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
    pretripNotes: [
      TripPretripNote(
        id: 31,
        sortOrder: 0,
        version: 2,
        title: '日幣兌換',
        content: '先在機場 ATM 領部分現金。',
      ),
    ],
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

TripNotes _sampleNotesWithoutPretrip() {
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
    pretripNotes: [],
  );
}

Widget _buildScreen(_MockTripRepository repository) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const TripNotesScreen(tripId: 'trip-1'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [tripRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  late _MockTripRepository repository;

  setUp(() {
    repository = _MockTripRepository();
    when(
      () => repository.fetchNotes('trip-1'),
    ).thenAnswer((_) async => _sampleNotes());
    when(() => repository.fetchTripRequest(any())).thenAnswer(
      (_) async => const TripRequest(
        id: 9901,
        tripId: 'trip-1',
        message: '[行程筆記-tips]',
        status: 'processing',
      ),
    );
  });

  testWidgets('渲染 AppBar 標題、5 個 section header 與 count badge', (tester) async {
    await tester.pumpWidget(_buildScreen(repository));
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
      'pretrip': '1',
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
    await tester.pumpWidget(_buildScreen(repository));
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
    await tester.pumpWidget(_buildScreen(repository));
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
    when(
      () => repository.fetchNotes('trip-1'),
    ).thenAnswer((_) async => _sampleNotesWithoutPretrip());
    await tester.pumpWidget(_buildScreen(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('行前須知'));
    await tester.pumpAndSettle();

    expect(find.text('尚無資料'), findsOneWidget);
  });

  testWidgets('全空 notes：5 個 count 皆 0，預設展開的航班顯示「尚無資料」', (tester) async {
    when(
      () => repository.fetchNotes('trip-1'),
    ).thenAnswer((_) async => const TripNotes());
    await tester.pumpWidget(_buildScreen(repository));
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

  testWidgets('可新增航班並送出 snake_case 對應欄位', (tester) async {
    when(
      () => repository.createTripFlight(
        tripId: 'trip-1',
        airline: any(named: 'airline'),
        flightNo: any(named: 'flightNo'),
        departAirport: any(named: 'departAirport'),
        arriveAirport: any(named: 'arriveAirport'),
        departAt: any(named: 'departAt'),
        arriveAt: any(named: 'arriveAt'),
        note: any(named: 'note'),
      ),
    ).thenAnswer(
      (_) async => const TripFlight(
        id: 99,
        sortOrder: 1,
        version: 1,
        airline: '星宇航空',
        flightNo: 'JX870',
        departAirport: 'TPE',
        arriveAirport: 'OKA',
      ),
    );

    await tester.pumpWidget(_buildScreen(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notes-add-flights')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('notes-flight-airline')),
      '星宇航空',
    );
    await tester.enterText(
      find.byKey(const ValueKey('notes-flight-no')),
      'JX870',
    );
    await tester.enterText(
      find.byKey(const ValueKey('notes-flight-depart-airport')),
      'TPE',
    );
    await tester.enterText(
      find.byKey(const ValueKey('notes-flight-arrive-airport')),
      'OKA',
    );
    await tester.tap(find.byKey(const ValueKey('notes-form-save')));
    await tester.pumpAndSettle();

    verify(
      () => repository.createTripFlight(
        tripId: 'trip-1',
        airline: '星宇航空',
        flightNo: 'JX870',
        departAirport: 'TPE',
        arriveAirport: 'OKA',
        departAt: '',
        arriveAt: '',
        note: '',
      ),
    ).called(1);
  });

  testWidgets('可編輯行前須知並帶 expectedVersion', (tester) async {
    when(
      () => repository.updateTripPretripNote(
        tripId: 'trip-1',
        rowId: 31,
        expectedVersion: 2,
        title: any(named: 'title'),
        content: any(named: 'content'),
      ),
    ).thenAnswer(
      (_) async => const TripPretripNote(
        id: 31,
        sortOrder: 0,
        version: 3,
        title: '日幣與現金',
        content: 'ATM 領現金，市區再補。',
      ),
    );

    await tester.pumpWidget(_buildScreen(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('行前須知'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notes-edit-pretrip-31')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('notes-pretrip-title')),
      '日幣與現金',
    );
    await tester.enterText(
      find.byKey(const ValueKey('notes-pretrip-content')),
      'ATM 領現金，市區再補。',
    );
    await tester.tap(find.byKey(const ValueKey('notes-form-save')));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateTripPretripNote(
        tripId: 'trip-1',
        rowId: 31,
        expectedVersion: 2,
        title: '日幣與現金',
        content: 'ATM 領現金，市區再補。',
      ),
    ).called(1);
  });

  testWidgets('可經確認刪除緊急聯絡人', (tester) async {
    when(
      () => repository.deleteTripNoteRow(
        tripId: 'trip-1',
        section: TripNoteSection.emergency,
        rowId: 4,
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildScreen(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('緊急聯絡'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notes-delete-emergency-4')),
      300,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notes-delete-emergency-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notes-delete-confirm')));
    await tester.pumpAndSettle();

    verify(
      () => repository.deleteTripNoteRow(
        tripId: 'trip-1',
        section: TripNoteSection.emergency,
        rowId: 4,
      ),
    ).called(1);
  });

  testWidgets('可觸發 AI 生成行前須知並顯示 pending 狀態', (tester) async {
    when(
      () => repository.generateTripNotes(tripId: 'trip-1', docType: 'tips'),
    ).thenAnswer(
      (_) async => const TripNoteAiGenerationJob(
        jobId: 77,
        requestId: 9901,
        status: 'pending',
        tripId: 'trip-1',
        docType: 'tips',
      ),
    );

    await tester.pumpWidget(_buildScreen(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('行前須知'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notes-ai-pretrip-tips')));
    await tester.pump();

    expect(find.textContaining('AI 正在生成行前須知'), findsOneWidget);
    verify(
      () => repository.generateTripNotes(tripId: 'trip-1', docType: 'tips'),
    ).called(1);
  });
}
