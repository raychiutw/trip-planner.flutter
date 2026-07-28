import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/trip_notes_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/note_section.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/trip_request.dart';
import 'package:tripline/theme/app_theme.dart';

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

const _sortableFlightNotes = TripNotes(
  flights: [
    TripFlight(
      id: 1,
      sortOrder: 0,
      version: 1,
      airline: '長榮航空',
      flightNo: 'BR112',
    ),
    TripFlight(
      id: 6,
      sortOrder: 1,
      version: 1,
      airline: '中華航空',
      flightNo: 'CI120',
    ),
  ],
);

/// 現行 repository 解生成回應用的是非 null cast:`(map['jobId'] as num).toInt()`。
/// 後端回一個缺 `jobId` 的 body 時,這一行丟的是 `TypeError` —— `Error` 不是
/// `Exception`,畫面層的 `on Exception` 攔不到。helper 在 mock 裡跑同一段 cast,
/// 讓 mock 的失敗方式跟真的 repository 一模一樣,而不是憑空 throw 一個假錯誤。
Never _decodeGenerateBodyMissingJobId() {
  const body = <String, dynamic>{
    'requestId': 99,
    'status': 'pending',
    'tripId': 'trip-1',
    'docType': 'tips',
  };
  (body['jobId'] as num).toInt();
  throw StateError('缺 jobId 的 body 應該在上一行就丟出 TypeError');
}

/// 三顆 AI 按鈕分散在兩個預設收合的 section,量按鈕狀態前要先讓它們都在樹上。
/// 拉高 viewport 讓兩區展開後仍不需捲動,避免斷言被捲動時序干擾。
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _expandAiSections(WidgetTester tester) async {
  await tester.tap(find.text('行前須知'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('緊急聯絡'));
  await tester.pumpAndSettle();
}

Widget _buildScreen(
  TripNotes notes, {
  _MockTripRepository? repo,
  _MockRequestsRepository? requestsRepo,
  Stream<TripNotes> Function(Ref ref, String tripId)? notesBuilder,
  ThemeData? theme,
  TextScaler? textScaler,
}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      tripNotesProvider.overrideWith(
        notesBuilder ?? (ref, tripId) => Stream.value(notes),
      ),
      if (repo != null) tripRepositoryProvider.overrideWithValue(repo),
      if (requestsRepo != null)
        requestsRepositoryProvider.overrideWithValue(requestsRepo),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light(),
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: const TripNotesScreen(tripId: 'trip-1'),
    ),
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
    expect(find.byKey(const ValueKey('notes-section-flights')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notes-section-lodgings')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('notes-section-reservations')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('notes-section-pretrip')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notes-section-emergency')),
      findsOneWidget,
    );

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

  testWidgets('regular width 置中限制筆記內容寬度', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildScreen(_sampleNotes()));
    await tester.pumpAndSettle();

    final content = tester.getRect(
      find.byKey(const ValueKey('trip-notes-content')),
    );
    expect(content.width, 920);
    expect(content.center.dx, 600);
  });

  testWidgets('compact dark 與最大 Dynamic Type 保留內容及 44pt 返回鈕，且無帳號入口', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildScreen(
        _sampleNotes(),
        theme: AppTheme.dark(),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('notes-section-flights')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-avatar-button')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('tp-app-bar-back'))),
      const Size(44, 44),
    );
  });

  testWidgets('載入失敗持續顯示且可重試', (tester) async {
    var attempts = 0;
    final firstAttempt = StreamController<TripNotes>();
    addTearDown(firstAttempt.close);

    await tester.pumpWidget(
      _buildScreen(
        _sampleNotes(),
        notesBuilder: (ref, tripId) {
          attempts += 1;
          return attempts == 1
              ? firstAttempt.stream
              : Stream.value(_sampleNotes());
        },
      ),
    );
    await tester.pump();
    firstAttempt.addError(Exception('offline'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-notes-error')), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-notes-list')), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('筆記頁頂端第一個內容是航班區，不再有行程/地圖/筆記下拉', (tester) async {
    await tester.pumpWidget(_buildScreen(_sampleNotes()));
    await tester.pumpAndSettle();

    // 使用者一進頁面看到的第一個東西就是筆記內容：航班區緊貼列表頂端，
    // 中間只隔著 ListView 自己的 16pt padding。
    final listTop = tester
        .getRect(find.byKey(const ValueKey('trip-notes-list')))
        .top;
    final flightsTop = tester
        .getRect(find.byKey(const ValueKey('notes-section-flights')))
        .top;
    expect(flightsTop - listTop, closeTo(16, 0.01));

    // 下拉整組消失：觸發鈕與三個選項都不在樹上。切換交由 root tab 承擔，
    // 退出筆記頁走返回鍵。
    expect(find.byKey(const ValueKey('trip-section-scope')), findsNothing);
    expect(find.byKey(const ValueKey('trip-section-itinerary')), findsNothing);
    expect(find.byKey(const ValueKey('trip-section-map')), findsNothing);
    expect(find.byKey(const ValueKey('trip-section-notes')), findsNothing);
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
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('刪除'),
      ),
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

  testWidgets('VoiceOver 排序動作與拖曳共用 reorderNotes mutation', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.reorderNotes(
        any(),
        tripId: any(named: 'tripId'),
        items: any(named: 'items'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildScreen(_sortableFlightNotes, repo: repo));
    await tester.pumpAndSettle();

    final semantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('note-drag-flights-6')),
    );
    final actions = semantics.properties.customSemanticsActions!;
    expect(actions.keys.map((action) => action.label), ['上移']);
    actions.values.single();
    await tester.pumpAndSettle();

    final items =
        verify(
              () => repo.reorderNotes(
                NoteSection.flights,
                tripId: 'trip-1',
                items: captureAny(named: 'items'),
              ),
            ).captured.single
            as List<({int id, int sortOrder})>;
    expect(items, [(id: 6, sortOrder: 0), (id: 1, sortOrder: 1)]);
  });

  testWidgets('Full Keyboard Access 方向鍵與拖曳共用 reorderNotes mutation', (
    tester,
  ) async {
    final repo = _MockTripRepository();
    when(
      () => repo.reorderNotes(
        any(),
        tripId: any(named: 'tripId'),
        items: any(named: 'items'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildScreen(_sortableFlightNotes, repo: repo));
    await tester.pumpAndSettle();

    final handle = find.byKey(const ValueKey('note-drag-flights-6'));
    Focus.of(tester.element(handle)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    verify(
      () => repo.reorderNotes(
        NoteSection.flights,
        tripId: 'trip-1',
        items: any(named: 'items'),
      ),
    ).called(1);
  });

  testWidgets('展開行前須知後可觸發一般 AI 生成並顯示 pending 狀態', (tester) async {
    final repo = _MockTripRepository();
    final requestsRepo = _MockRequestsRepository();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).thenAnswer(
      (_) async => const TripNoteAiJob(
        jobId: 7,
        requestId: 99,
        tripId: 'trip-1',
        docType: NoteGenerationType.tips,
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
      (_) async => const TripNoteAiJob(
        jobId: 8,
        requestId: 100,
        tripId: 'trip-1',
        docType: NoteGenerationType.emergency,
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

  testWidgets('生成回應缺 jobId 時顯示錯誤面板與重試入口,三顆 AI 按鈕恢復可按', (tester) async {
    _useTallViewport(tester);
    final repo = _MockTripRepository();
    final requestsRepo = _MockRequestsRepository();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).thenAnswer((_) async => _decodeGenerateBodyMissingJobId());
    when(
      () => requestsRepo.watchRequestEvents(any()),
    ).thenAnswer((_) => const Stream<TripRequestEvent>.empty());

    await tester.pumpWidget(
      _buildScreen(_sampleNotes(), repo: repo, requestsRepo: requestsRepo),
    );
    await tester.pumpAndSettle();
    await _expandAiSections(tester);

    await tester.tap(find.byKey(const ValueKey('note-ai-tips')));
    await tester.pump();
    await tester.pump();

    // 使用者看得到出事了:錯誤面板在,而不是一個永遠轉不完的 pending。
    expect(find.byKey(const ValueKey('notes-ai-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-ai-pending')), findsNothing);

    // 三顆按鈕都不再卡死;lodging-tips 在 _sampleNotes() 有住宿所以本來就該可按。
    for (final buttonKey in const [
      'note-ai-tips',
      'note-ai-lodging-tips',
      'note-ai-emergency',
    ]) {
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(ValueKey(buttonKey)))
            .onPressed,
        isNotNull,
        reason: '$buttonKey 應恢復可按',
      );
    }

    // 重試入口要真的能再送一次,不是一顆裝飾用的按鈕。
    final retry = find.byKey(const ValueKey('notes-ai-retry'));
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pump();
    await tester.pump();

    verify(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).called(2);
  });

  // 生成期的四個 error code。維護權的 NOTES_AI_NOT_REASSIGNABLE /
  // NOTES_AI_JOB_STALE 不在這裡 —— 它們要到維護權 PATCH（#209）才有呼叫端。
  for (final c in const [
    (code: 'NOTES_AI_INVALID_OUTPUT', message: 'AI 這次產生的內容格式不正確'),
    (code: 'NOTES_AI_NO_VALID_ITEMS', message: 'AI 這次沒有產生可用的項目'),
    (code: 'NOTES_AI_JOB_ACTIVE', message: '這個行程已有一個生成中的工作'),
    (code: 'NOTES_AI_APPLY_FAILED', message: 'AI 內容寫回筆記時失敗'),
  ]) {
    testWidgets('生成失敗 ${c.code} 顯示對應中文訊息且不露出原始 code', (tester) async {
      _useTallViewport(tester);
      final repo = _MockTripRepository();
      when(
        () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
      ).thenThrow(
        ApiError(
          status: 422,
          code: c.code,
          message: 'ai generation rejected by upstream',
        ),
      );

      await tester.pumpWidget(_buildScreen(_sampleNotes(), repo: repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('行前須知'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('note-ai-tips')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('notes-ai-error')), findsOneWidget);
      expect(find.textContaining(c.message), findsOneWidget);
      expect(find.textContaining(c.code), findsNothing);
    });
  }

  testWidgets('未知 error code 走 fallback 訊息,不把原始 code 丟給使用者看', (tester) async {
    _useTallViewport(tester);
    final repo = _MockTripRepository();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).thenThrow(
      const ApiError(
        status: 500,
        code: 'NOTES_AI_SOMETHING_NEW',
        message: 'unmapped upstream failure',
      ),
    );

    await tester.pumpWidget(_buildScreen(_sampleNotes(), repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('行前須知'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note-ai-tips')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('notes-ai-error')), findsOneWidget);
    expect(find.textContaining('目前無法完成 AI 生成'), findsOneWidget);
    expect(find.textContaining('NOTES_AI_SOMETHING_NEW'), findsNothing);
    expect(find.textContaining('ApiError'), findsNothing);
  });
}
