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

/// 讓 mock 丟出一個**真的** `TypeError`,而不是憑空 throw 一個假錯誤。
///
/// `TripNoteAiJob.fromJson` 現在全欄位都有預設值,repository 已經不會因為 body 缺
/// `jobId` 而丟 `TypeError` 了。但畫面層的守門不是「repository 保證不丟 Error」,
/// 而是「任何 `Error` 逃出來畫面都得撐住」—— `Error` 不是 `Exception`,`on Exception`
/// 攔不到,而 catch 漏接的後果是三顆 AI 按鈕永久 disabled 且畫面上什麼都不顯示。
/// 這個 helper 跑一段跟舊解析同形的非 null cast,產生跟當初一模一樣的 `TypeError`,
/// 把那條守門釘在原地,不隨 repository 的解析寫法而失效。
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

/// 兩種生成各自的 mock:tips → requestId 99、emergency → requestId 100,
/// 每種各有一條**獨立可控**的進度通道,用來驗證兩個 job 互不干擾。
({
  _MockTripRepository repo,
  _MockRequestsRepository requestsRepo,
  StreamController<TripRequestEvent> tipsEvents,
  StreamController<TripRequestEvent> emergencyEvents,
})
_parallelAiMocks() {
  final repo = _MockTripRepository();
  final requestsRepo = _MockRequestsRepository();
  // ai-state 預設成功回空 —— 只有專門測隔離的那條會覆寫成 throw。
  when(
    () => repo.fetchNotesAiState(any()),
  ).thenAnswer((_) async => const TripNoteAiState());
  final tipsEvents = StreamController<TripRequestEvent>(sync: true);
  final emergencyEvents = StreamController<TripRequestEvent>(sync: true);
  // 刻意不 await:沒有 listener 的 controller,`close()` 的 future 永遠不會完成
  //（done event 沒有人收），teardown 一 await 就整條測試卡到 10 分鐘 timeout。
  addTearDown(() {
    tipsEvents.close();
    emergencyEvents.close();
  });
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
    () => requestsRepo.watchRequestEvents(99),
  ).thenAnswer((_) => tipsEvents.stream);
  when(
    () => requestsRepo.watchRequestEvents(100),
  ).thenAnswer((_) => emergencyEvents.stream);
  return (
    repo: repo,
    requestsRepo: requestsRepo,
    tipsEvents: tipsEvents,
    emergencyEvents: emergencyEvents,
  );
}

/// 先按「一般」(行前須知)再按「AI」(緊急聯絡),兩個生成同時進行中。
Future<void> _startTipsThenEmergency(WidgetTester tester) async {
  await _expandAiSections(tester);
  await tester.tap(find.byKey(const ValueKey('note-ai-tips')));
  await tester.pump();
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('note-ai-emergency')));
  await tester.pump();
  await tester.pump();
}

/// 只按「一般」(行前須知),用來單獨觀察一條通道的進度文案。
Future<void> _startTips(WidgetTester tester) async {
  await _expandAiSections(tester);
  await tester.tap(find.byKey(const ValueKey('note-ai-tips')));
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpAiScreen(
  WidgetTester tester,
  ({
    _MockTripRepository repo,
    _MockRequestsRepository requestsRepo,
    StreamController<TripRequestEvent> tipsEvents,
    StreamController<TripRequestEvent> emergencyEvents,
  })
  mocks, {
  bool stubAiState = true,
}) async {
  await tester.pumpWidget(
    _buildScreen(
      _sampleNotes(),
      repo: mocks.repo,
      requestsRepo: mocks.requestsRepo,
      stubAiState: stubAiState,
    ),
  );
  await tester.pumpAndSettle();
}

/// 行前須知那條進度面板上實際顯示的字。
String _pendingText(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('notes-ai-pending-tips')),
        matching: find.byType(Text),
      ),
    )
    .data!;

VoidCallback? _aiButtonAction(WidgetTester tester, String key) =>
    tester.widget<OutlinedButton>(find.byKey(ValueKey(key))).onPressed;

Widget _buildScreen(
  TripNotes notes, {
  _MockTripRepository? repo,
  _MockRequestsRepository? requestsRepo,
  Stream<TripNotes> Function(Ref ref, String tripId)? notesBuilder,
  ThemeData? theme,
  TextScaler? textScaler,
  bool stubAiState = true,
}) {
  // ai-state 對絕大多數測試是背景雜訊:預設成功回空,只有專門測隔離的那條
  // 傳 `stubAiState: false` 自己 stub 成 throw。放這裡而不是每條測試各補一次。
  if (repo != null && stubAiState) {
    when(
      () => repo.fetchNotesAiState(any()),
    ).thenAnswer((_) async => const TripNoteAiState());
  }
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
    expect(find.textContaining('行前須知'), findsWidgets);
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

  // 生成期真正算「失敗」的 error code。維護權的 NOTES_AI_NOT_REASSIGNABLE /
  // NOTES_AI_JOB_STALE 不在這裡 —— 它們要到維護權 PATCH（#209）才有呼叫端;
  // NOTES_AI_JOB_ACTIVE 也不在這裡 —— 它代表「同一份文件已經有 job 在跑」,
  // 現在走「接上既有 job」而不是錯誤面板（見本檔最後一條測試）。
  for (final c in const [
    (code: 'NOTES_AI_INVALID_OUTPUT', message: 'AI 這次產生的內容格式不正確'),
    (code: 'NOTES_AI_NO_VALID_ITEMS', message: 'AI 這次沒有產生可用的項目'),
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

  testWidgets('server 已經回繁中訊息時直接用它,不降級成 code 對照表或通用句', (tester) async {
    _useTallViewport(tester);
    final repo = _MockTripRepository();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).thenThrow(
      const ApiError(
        status: 429,
        code: 'SYS_RATE_LIMIT',
        message: '請求過於頻繁，請於 60 秒後再試',
      ),
    );

    await tester.pumpWidget(_buildScreen(_sampleNotes(), repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('行前須知'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note-ai-tips')));
    await tester.pump();
    await tester.pump();

    // 三層 fallback 的第一層:code 對照表沒有 SYS_RATE_LIMIT,但後端已經給了
    // 比對照表更精準的繁中說明(帶秒數),吞掉它等於讓使用者拿到比修復前更少的資訊。
    expect(find.byKey(const ValueKey('notes-ai-error')), findsOneWidget);
    expect(find.textContaining('請求過於頻繁，請於 60 秒後再試'), findsOneWidget);
    expect(find.textContaining('目前無法完成 AI 生成'), findsNothing);
  });

  testWidgets('SSE 終止事件帶的 error code 一樣翻成中文,不把 code 貼上面板', (tester) async {
    _useTallViewport(tester);
    final repo = _MockTripRepository();
    final requestsRepo = _MockRequestsRepository();
    final controller = StreamController<TripRequestEvent>(sync: true);
    addTearDown(controller.close);
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
    ).thenAnswer((_) => controller.stream);

    await tester.pumpWidget(
      _buildScreen(_sampleNotes(), repo: repo, requestsRepo: requestsRepo),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('行前須知'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note-ai-tips')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('notes-ai-pending')), findsOneWidget);

    // AI job 非同步失敗才是這張票的主場景:失敗從 SSE 的終止事件回來,
    // 而 `TripRequestEvent.error` 就是後端原字串,沒有任何保證是繁中或不是 code。
    controller.add(
      const TripRequestEvent(
        status: RequestStatus.failed,
        error: 'NOTES_AI_INVALID_OUTPUT',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('notes-ai-pending')), findsNothing);
    expect(find.byKey(const ValueKey('notes-ai-error')), findsOneWidget);
    expect(find.textContaining('AI 這次產生的內容格式不正確'), findsOneWidget);
    expect(find.textContaining('NOTES_AI_INVALID_OUTPUT'), findsNothing);
  });

  testWidgets('SSE 終止事件帶的繁中訊息直接顯示', (tester) async {
    _useTallViewport(tester);
    final repo = _MockTripRepository();
    final requestsRepo = _MockRequestsRepository();
    final controller = StreamController<TripRequestEvent>(sync: true);
    addTearDown(controller.close);
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).thenAnswer((_) async => const TripNoteAiJob(jobId: 7, requestId: 99));
    when(
      () => requestsRepo.watchRequestEvents(99),
    ).thenAnswer((_) => controller.stream);

    await tester.pumpWidget(
      _buildScreen(_sampleNotes(), repo: repo, requestsRepo: requestsRepo),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('行前須知'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-ai-tips')));
    await tester.pump();
    await tester.pump();

    controller.add(
      const TripRequestEvent(
        status: RequestStatus.failed,
        error: '模型逾時，請稍後再試一次',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('模型逾時，請稍後再試一次'), findsOneWidget);
  });

  testWidgets('訂閱 SSE 就丟例外時錯誤面板單獨出現,重試真的會再送一次', (tester) async {
    _useTallViewport(tester);
    final repo = _MockTripRepository();
    final requestsRepo = _MockRequestsRepository();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).thenAnswer((_) async => const TripNoteAiJob(jobId: 7, requestId: 99));
    // 失敗發生在 `_aiJob` 已經設值之後。若 catch 只設錯誤不清 `_aiJob`,
    // 進行中面板與錯誤面板會同時在、三顆按鈕仍卡死,連重試都被開頭的守衛擋掉。
    when(() => requestsRepo.watchRequestEvents(99)).thenThrow(
      const ApiError(status: 500, code: 'SSE_OPEN_FAILED', message: 'boom'),
    );

    await tester.pumpWidget(
      _buildScreen(_sampleNotes(), repo: repo, requestsRepo: requestsRepo),
    );
    await tester.pumpAndSettle();
    await _expandAiSections(tester);

    await tester.tap(find.byKey(const ValueKey('note-ai-tips')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('notes-ai-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-ai-pending')), findsNothing);
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

    await tester.tap(find.byKey(const ValueKey('notes-ai-retry')));
    await tester.pump();
    await tester.pump();

    verify(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).called(2);
  });

  testWidgets('AI 錯誤面板出現時,展開中的筆記區不被收合', (tester) async {
    _useTallViewport(tester);
    final repo = _MockTripRepository();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).thenThrow(
      const ApiError(
        status: 422,
        code: 'NOTES_AI_INVALID_OUTPUT',
        message: 'ai generation rejected by upstream',
      ),
    );

    await tester.pumpWidget(_buildScreen(_sampleNotes(), repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('行前須知'));
    await tester.pumpAndSettle();

    // 展開後 section 的 children 才在樹上（ExpansionTile 收合時整組 offstage）。
    expect(find.byKey(const ValueKey('note-add-pretrip')), findsOneWidget);
    expect(find.text('尚無資料'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note-ai-tips')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('notes-ai-error')), findsOneWidget);
    // 狀態面板若是 ListView 的條件式 children,它一出現後面每個 slot 都會換位重建,
    // ExpansionTile 拿到全新的 State、退回 initiallyExpanded=false —— 使用者剛剛
    // 親手展開的區在他眼前收起來。面板必須固定佔一個 slot。
    expect(
      find.byKey(const ValueKey('note-add-pretrip')),
      findsOneWidget,
      reason: '錯誤面板出現後「行前須知」應維持展開',
    );
    expect(find.text('尚無資料'), findsOneWidget);
  });

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

  testWidgets('進頁面時若後端有進行中的 job,直接接上進度通道顯示生成中', (tester) async {
    _useTallViewport(tester);
    final mocks = _parallelAiMocks();
    // 使用者上次按了生成就離開;server 上那個 job 還在跑。
    when(() => mocks.repo.fetchNotesAiState('trip-1')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            jobId: 7,
            requestId: 99,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.processing,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      _buildScreen(
        _sampleNotes(),
        repo: mocks.repo,
        requestsRepo: mocks.requestsRepo,
        stubAiState: false,
      ),
    );
    // 進行中面板有一顆永遠在轉的 spinner,pumpAndSettle 會 timeout。
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('notes-ai-pending-tips')),
      findsOneWidget,
      reason: '進頁面就看得到它還在跑,不是「什麼都沒發生」',
    );
    // 接的是既有的進度通道,不是新開輪詢。
    expect(mocks.tipsEvents.hasListener, isTrue);
    // 只訂閱一次 —— 恢復不得重複接上同一個 job。
    verify(() => mocks.requestsRepo.watchRequestEvents(99)).called(1);
    // 沒有進行中的那兩種不該被訂閱。
    verifyNever(() => mocks.requestsRepo.watchRequestEvents(100));
    // 恢復不是重新送一次生成。
    verifyNever(
      () => mocks.repo.generateNotes(
        NoteGenerationType.tips,
        tripId: any(named: 'tripId'),
      ),
    );
  });

  testWidgets('app 回到前景會重讀一次 AI 狀態並接上進行中的 job', (tester) async {
    _useTallViewport(tester);
    final mocks = _parallelAiMocks();
    // 第一次進頁面時什麼都沒在跑;使用者切走、在別的裝置按了生成,再切回來。
    var call = 0;
    when(() => mocks.repo.fetchNotesAiState('trip-1')).thenAnswer((_) async {
      call++;
      return call == 1
          ? const TripNoteAiState()
          : const TripNoteAiState(
              jobs: [
                TripNoteAiJob(
                  jobId: 7,
                  requestId: 99,
                  docType: NoteGenerationType.tips,
                  status: TripNoteAiJobStatus.processing,
                ),
              ],
            );
    });
    await tester.pumpWidget(
      _buildScreen(
        _sampleNotes(),
        repo: mocks.repo,
        requestsRepo: mocks.requestsRepo,
        stubAiState: false,
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('notes-ai-pending-tips')), findsNothing);

    // 回到前景 —— 沿用本專案既有的 WidgetsBindingObserver 手法。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(call, 2, reason: 'resume 要重讀一次,不是只讀進頁面那一次');
    expect(
      find.byKey(const ValueKey('notes-ai-pending-tips')),
      findsOneWidget,
      reason: '重讀後要接上進行中的 job',
    );
    verify(() => mocks.requestsRepo.watchRequestEvents(99)).called(1);
  });

  testWidgets('生成完成後重讀狀態,把摘要用中文句子講出來', (tester) async {
    _useTallViewport(tester);
    final mocks = _parallelAiMocks();
    var call = 0;
    when(() => mocks.repo.fetchNotesAiState('trip-1')).thenAnswer((_) async {
      call++;
      // 第一次(進頁面)什麼都沒有;完成事件之後才有摘要。
      return call == 1
          ? const TripNoteAiState()
          : const TripNoteAiState(
              jobs: [
                TripNoteAiJob(
                  jobId: 7,
                  requestId: 99,
                  docType: NoteGenerationType.tips,
                  status: TripNoteAiJobStatus.completed,
                  insertedCount: 2,
                  replacedCount: 5,
                  preservedManualCount: 3,
                  duplicateExcludedCount: 1,
                  suppressedCount: 0,
                ),
              ],
            );
    });
    await tester.pumpWidget(
      _buildScreen(
        _sampleNotes(),
        repo: mocks.repo,
        requestsRepo: mocks.requestsRepo,
        stubAiState: false,
      ),
    );
    await tester.pump();
    await _startTips(tester);

    mocks.tipsEvents.add(
      const TripRequestEvent(status: RequestStatus.completed),
    );
    await tester.pump();
    await tester.pump();

    expect(call, 2, reason: '摘要只能從終態後重讀 ai-state 拿到,SSE 事件不帶 payload');
    final summary = tester
        .widget<Text>(
          find
              .descendant(
                of: find.byKey(const ValueKey('notes-ai-summary')),
                matching: find.byType(Text),
              )
              .first,
        )
        .data!;
    expect(summary, contains('2'), reason: '新增 2 則');
    expect(summary, contains('5'), reason: '替換 5 則');
    expect(summary, contains('3'), reason: '保留 3 則人工');
    expect(summary, isNot(contains('抑制 0')), reason: '缺漏或為零的 count 要略過');
  });

  testWidgets('逾時走既有進度通道抵達,有自己的面板與重試', (tester) async {
    _useTallViewport(tester);
    final mocks = _parallelAiMocks();
    var call = 0;
    when(() => mocks.repo.fetchNotesAiState('trip-1')).thenAnswer((_) async {
      call++;
      return call == 1
          ? const TripNoteAiState()
          : const TripNoteAiState(
              jobs: [
                TripNoteAiJob(
                  jobId: 7,
                  requestId: 99,
                  docType: NoteGenerationType.tips,
                  status: TripNoteAiJobStatus.timedOut,
                  errorCode: 'NOTES_AI_JOB_STALE',
                  errorMessage: 'AI 生成超過 10 分鐘',
                ),
              ],
            );
    });
    await tester.pumpWidget(
      _buildScreen(
        _sampleNotes(),
        repo: mocks.repo,
        requestsRepo: mocks.requestsRepo,
        stubAiState: false,
      ),
    );
    await tester.pump();
    await _startTips(tester);

    // 後端 #1217:job 逾時時對應的 request 也被標成 failed,所以逾時透過
    // 既有的進度通道抵達,client 不必新增輪詢也不自己倒數。
    mocks.tipsEvents.add(
      const TripRequestEvent(status: RequestStatus.failed, error: '逾時'),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('notes-ai-timeout')),
      findsOneWidget,
      reason: '逾時要有自己的面板,不能跟一般失敗混為一談',
    );
    expect(
      find.byKey(const ValueKey('notes-ai-timeout-retry')),
      findsOneWidget,
    );
  });

  testWidgets('AI 狀態讀取失敗只壞 AI 區塊,五區筆記照常增刪改與排序', (tester) async {
    _useTallViewport(tester);
    final mocks = _parallelAiMocks();
    // 後端 ai-state 還沒上線 / 暫時掛掉。
    when(
      () => mocks.repo.fetchNotesAiState('trip-1'),
    ).thenThrow(ApiError(status: 404, code: 'NOT_FOUND', message: 'not found'));
    await _pumpAiScreen(tester, mocks, stubAiState: false);

    // AI 區塊內看得到失敗與重試。
    expect(find.byKey(const ValueKey('notes-ai-state-error')), findsOneWidget);

    // 而筆記本體完全不受影響 —— 這裡要斷言**實際操作**,不能只斷言沒 crash。
    expect(
      find.byKey(const ValueKey('notes-section-flights')),
      findsOneWidget,
      reason: '五區照常載入',
    );
    expect(
      find.byKey(const ValueKey('note-drag-flights-1')),
      findsOneWidget,
      reason: '拖曳把手仍在,排序照常',
    );
    await tester.tap(find.byKey(const ValueKey('note-add-flights')));
    await tester.pumpAndSettle();
    expect(
      find.text('新增航班'),
      findsNWidgets(2),
      reason: '照常開新增表單(按鈕 + sheet 標題)',
    );
  });

  testWidgets('進度事件會換掉文案:送出→讀行程→整理內容,不是從頭到尾一句話', (tester) async {
    _useTallViewport(tester);
    final mocks = _parallelAiMocks();
    await _pumpAiScreen(tester, mocks);
    await _startTips(tester);

    // 剛送出:還沒有任何進度事件。
    final submitted = _pendingText(tester);
    expect(submitted, isNot(contains('處理中')), reason: '不得用無資訊量的字眼');

    // 後端回報開始處理 —— 現況 listener 第一行就 `if (!event.isTerminal) return;`,
    // 所有中間事件被丟掉,文案不會變。
    mocks.tipsEvents.add(
      const TripRequestEvent(status: RequestStatus.processing),
    );
    await tester.pump();
    final processing = _pendingText(tester);
    expect(
      processing,
      isNot(submitted),
      reason: '收到 processing 事件後文案必須改變,不能從頭到尾同一句',
    );
    expect(processing, isNot(contains('處理中')));
  });

  testWidgets('行前須知生成中時緊急聯絡仍可按,而且第二個生成真的送出;兩個 job 各走各的通道', (tester) async {
    _useTallViewport(tester);
    final mocks = _parallelAiMocks();

    await tester.pumpWidget(
      _buildScreen(
        _sampleNotes(),
        repo: mocks.repo,
        requestsRepo: mocks.requestsRepo,
      ),
    );
    await tester.pumpAndSettle();
    await _expandAiSections(tester);

    await tester.tap(find.byKey(const ValueKey('note-ai-tips')));
    await tester.pump();
    await tester.pump();

    // 進行中的是「行前須知(一般)」,毫不相干的緊急聯絡不該被連坐 disable。
    expect(
      _aiButtonAction(tester, 'note-ai-emergency'),
      isNotNull,
      reason: 'tips 生成中時 emergency 按鈕仍應可按',
    );

    await tester.tap(find.byKey(const ValueKey('note-ai-emergency')));
    await tester.pump();
    await tester.pump();

    // 按得下去不等於送得出去:啟動流程開頭的守衛若還是全域的,這裡會 called(0)。
    verify(
      () => mocks.repo.generateNotes(
        NoteGenerationType.emergency,
        tripId: 'trip-1',
      ),
    ).called(1);

    // 兩個進行中同時顯示,而且看得出是哪一種。
    expect(find.byKey(const ValueKey('notes-ai-pending-tips')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notes-ai-pending-emergency')),
      findsOneWidget,
    );
    expect(find.textContaining('已送出行前須知（一般）的生成'), findsOneWidget);
    expect(find.textContaining('已送出緊急聯絡的生成'), findsOneWidget);

    // 第三道陷阱:啟動第二個生成不得把第一個的進度通道殺掉。訂閱若共用單一
    // subscription,畫面上兩個進行中都在(前面的斷言全綠),但 tips 的完成事件
    // 永遠不會到達 —— 進行中狀態從此清不掉。
    expect(
      mocks.tipsEvents.hasListener,
      isTrue,
      reason: '第一個生成的進度通道不該被第二個生成取消',
    );
    mocks.tipsEvents.add(
      const TripRequestEvent(status: RequestStatus.completed),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('notes-ai-pending-tips')),
      findsNothing,
      reason: '第一個 job 的終態抵達後要清掉它自己的進行中狀態',
    );
    expect(
      find.byKey(const ValueKey('notes-ai-pending-emergency')),
      findsOneWidget,
      reason: 'emergency 還在跑,不該被 tips 的完成一起清掉',
    );
    expect(_aiButtonAction(tester, 'note-ai-tips'), isNotNull);
    expect(_aiButtonAction(tester, 'note-ai-emergency'), isNull);
  });

  testWidgets('畫面銷毀時兩條進度通道一併取消,且不再 setState', (tester) async {
    _useTallViewport(tester);
    final mocks = _parallelAiMocks();

    await tester.pumpWidget(
      _buildScreen(
        _sampleNotes(),
        repo: mocks.repo,
        requestsRepo: mocks.requestsRepo,
      ),
    );
    await tester.pumpAndSettle();
    await _startTipsThenEmergency(tester);

    expect(mocks.tipsEvents.hasListener, isTrue);
    expect(mocks.emergencyEvents.hasListener, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(
      mocks.tipsEvents.hasListener,
      isFalse,
      reason: 'tips 訂閱應在 dispose 取消',
    );
    expect(
      mocks.emergencyEvents.hasListener,
      isFalse,
      reason: 'emergency 訂閱應在 dispose 一併取消',
    );

    // 通道都斷了,遲到的終止事件不會再打到已 dispose 的 State。
    mocks.tipsEvents.add(
      const TripRequestEvent(status: RequestStatus.completed),
    );
    mocks.emergencyEvents.add(
      const TripRequestEvent(status: RequestStatus.failed, error: 'boom'),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('兩個 job 幾乎同時完成:只出一則完成提示,而且兩種都提到', (tester) async {
    _useTallViewport(tester);
    final mocks = _parallelAiMocks();

    await tester.pumpWidget(
      _buildScreen(
        _sampleNotes(),
        repo: mocks.repo,
        requestsRepo: mocks.requestsRepo,
      ),
    );
    await tester.pumpAndSettle();
    await _startTipsThenEmergency(tester);

    mocks.tipsEvents.add(
      const TripRequestEvent(status: RequestStatus.completed),
    );
    mocks.emergencyEvents.add(
      const TripRequestEvent(status: RequestStatus.completed),
    );
    await tester.pump();
    await tester.pump();

    // 提示是浮在 overlay 的橫幅,兩則會疊在同一個位置互相蓋掉;
    // `tester.widget` 找到兩個以上就直接失敗 —— 這一行同時守住「不連發兩則」。
    final notice = tester.widget<Text>(find.textContaining('AI 生成完成'));
    expect(notice.data, contains('行前須知（一般）'));
    expect(notice.data, contains('緊急聯絡'));
    expect(find.byKey(const ValueKey('notes-ai-pending-tips')), findsNothing);
    expect(
      find.byKey(const ValueKey('notes-ai-pending-emergency')),
      findsNothing,
    );
  });

  testWidgets('同一顆生成按鈕連按兩下只送出一次', (tester) async {
    _useTallViewport(tester);
    final mocks = _parallelAiMocks();

    await tester.pumpWidget(
      _buildScreen(
        _sampleNotes(),
        repo: mocks.repo,
        requestsRepo: mocks.requestsRepo,
      ),
    );
    await tester.pumpAndSettle();
    await _expandAiSections(tester);

    final button = find.byKey(const ValueKey('note-ai-tips'));
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump();

    verify(
      () => mocks.repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).called(1);
    expect(find.byKey(const ValueKey('notes-ai-pending-tips')), findsOneWidget);
  });

  testWidgets('server 回 NOTES_AI_JOB_ACTIVE 時視為接上既有 job,不呈現為錯誤', (
    tester,
  ) async {
    _useTallViewport(tester);
    final repo = _MockTripRepository();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'trip-1'),
    ).thenThrow(
      const ApiError(
        status: 409,
        code: 'NOTES_AI_JOB_ACTIVE',
        message: 'a generation job is already running',
      ),
    );

    await tester.pumpWidget(_buildScreen(_sampleNotes(), repo: repo));
    await tester.pumpAndSettle();
    await _expandAiSections(tester);

    await tester.tap(find.byKey(const ValueKey('note-ai-tips')));
    await tester.pump();
    await tester.pump();

    // 後端說「同一份文件已經有一個 job 在跑」——那正是使用者要的結果,
    // 呈現成紅色錯誤面板等於把成功講成失敗。
    expect(find.byKey(const ValueKey('notes-ai-error')), findsNothing);
    expect(find.byKey(const ValueKey('notes-ai-pending-tips')), findsOneWidget);
    expect(_aiButtonAction(tester, 'note-ai-tips'), isNull);
    expect(_aiButtonAction(tester, 'note-ai-emergency'), isNotNull);
  });
}
