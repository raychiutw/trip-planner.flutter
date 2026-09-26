import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/requests/request_lifecycle.dart';
import 'package:tripline/features/trip_detail/notes/notes_ai_controller.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/note_section.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/trip_request.dart';

class _MockTripRepo extends Mock implements TripRepository {}

class _MockRequestsRepo extends Mock implements RequestsRepository {}

Future<void> _flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(NoteGenerationType.tips));

  late _MockTripRepo repo;
  late _MockRequestsRepo requestsRepo;
  late StreamController<TripRequestEvent> tipsEvents;
  late StreamController<TripRequestEvent> emergencyEvents;
  var notesSnapshot = const TripNotes();

  setUp(() {
    repo = _MockTripRepo();
    requestsRepo = _MockRequestsRepo();
    tipsEvents = StreamController<TripRequestEvent>();
    emergencyEvents = StreamController<TripRequestEvent>();
    notesSnapshot = const TripNotes();
    when(() => requestsRepo.fetchRequest(any())).thenAnswer(
      (invocation) async => TripRequest(
        id: invocation.positionalArguments[0] as int,
        tripId: 't',
        message: 'notes',
        status: RequestStatus.open,
      ),
    );
    when(
      () => repo.fetchNotesAiState(any()),
    ).thenAnswer((_) async => const TripNoteAiState());
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 't'),
    ).thenAnswer(
      (_) async => const TripNoteAiJob(
        jobId: 7,
        requestId: 99,
        docType: NoteGenerationType.tips,
      ),
    );
    when(
      () => repo.generateNotes(NoteGenerationType.emergency, tripId: 't'),
    ).thenAnswer(
      (_) async => const TripNoteAiJob(
        jobId: 8,
        requestId: 100,
        docType: NoteGenerationType.emergency,
      ),
    );
    when(
      () => requestsRepo.watchRequestEvents(99),
    ).thenAnswer((_) => tipsEvents.stream);
    when(
      () => requestsRepo.watchRequestEvents(100),
    ).thenAnswer((_) => emergencyEvents.stream);
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        requestsRepositoryProvider.overrideWithValue(requestsRepo),
        for (final id in [99, 100, 101, 102, 200, 201])
          requestLifecycleProvider(id).overrideWith(
            () => RequestLifecycle(id, wait: (_) => Completer<void>().future),
          ),
        tripNotesProvider.overrideWith((ref, tripId) {
          return Stream.value(notesSnapshot);
        }),
      ],
    );
    addTearDown(c.dispose);
    // 像畫面一樣持續訂閱筆記，觀察完成後真正重新發射的內容。
    c.listen(tripNotesProvider('t'), (_, _) {});
    return c;
  }

  NotesAiJobState job(ProviderContainer c, NoteGenerationType type) =>
      c.read(notesAiControllerProvider('t')).of(type);

  test('開始 → 送出中 → 排隊中;進度事件 processing → 處理中', () async {
    final c = makeContainer();
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    await _flush();

    final started = ctrl.generate(NoteGenerationType.tips);
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.submitting);
    await started;
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.pending);
    expect(job(c, NoteGenerationType.tips).stage, NotesAiStage.queued);

    tipsEvents.add(const TripRequestEvent(status: RequestStatus.processing));
    await _flush();
    expect(job(c, NoteGenerationType.tips).stage, NotesAiStage.processing);
  });

  test('完成 → 筆記重讀、phase completed,重讀狀態後拿到摘要', () async {
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            docType: NoteGenerationType.tips,
            requestId: 99,
            status: TripNoteAiJobStatus.completed,
            insertedCount: 3,
          ),
        ],
      ),
    );
    final c = makeContainer();
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    await _flush();
    expect((await c.read(tripNotesProvider('t').future)).pretripNotes, isEmpty);
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();

    notesSnapshot = const TripNotes(
      pretripNotes: [
        TripPretripNote(id: 1, sortOrder: 0, version: 1, title: '新生成的行前須知'),
      ],
    );
    tipsEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();

    final tips = job(c, NoteGenerationType.tips);
    expect(tips.phase, NotesAiPhase.completed);
    expect(tips.summary?.insertedCount, 3);
    expect(
      (await c.read(tripNotesProvider('t').future)).pretripNotes.single.title,
      '新生成的行前須知',
    );
  });

  test('失敗事件後持久狀態確認完成，刷新實際筆記內容', () async {
    final c = makeContainer();
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    await _flush();
    expect((await c.read(tripNotesProvider('t').future)).pretripNotes, isEmpty);
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            docType: NoteGenerationType.tips,
            requestId: 99,
            status: TripNoteAiJobStatus.completed,
            insertedCount: 1,
          ),
        ],
      ),
    );
    notesSnapshot = const TripNotes(
      pretripNotes: [
        TripPretripNote(id: 1, sortOrder: 0, version: 1, title: '完成後的新內容'),
      ],
    );
    tipsEvents.add(const TripRequestEvent(status: RequestStatus.failed));
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.completed);
    expect(
      (await c.read(
        tripNotesProvider('t').future,
      )).pretripNotes.map((note) => note.title),
      ['完成後的新內容'],
    );
  });

  for (final terminal in [
    TripNoteAiJobStatus.failed,
    TripNoteAiJobStatus.timedOut,
  ]) {
    test('同工單 $terminal 終態不被過期 processing 倒退，仍可重新生成', () async {
      final c = makeContainer();
      final ctrl = c.read(notesAiControllerProvider('t').notifier);
      c.listen(notesAiControllerProvider('t'), (_, _) {});
      await _flush();
      await ctrl.generate(NoteGenerationType.tips);
      await _flush();
      when(() => repo.fetchNotesAiState('t')).thenAnswer(
        (_) async => TripNoteAiState(
          jobs: [
            TripNoteAiJob(
              docType: NoteGenerationType.tips,
              requestId: 99,
              status: terminal,
            ),
          ],
        ),
      );
      tipsEvents.add(const TripRequestEvent(status: RequestStatus.failed));
      await _flush();
      final phase = terminal == TripNoteAiJobStatus.timedOut
          ? NotesAiPhase.timedOut
          : NotesAiPhase.failed;
      expect(job(c, NoteGenerationType.tips).phase, phase);
      when(() => repo.fetchNotesAiState('t')).thenAnswer(
        (_) async => const TripNoteAiState(
          jobs: [
            TripNoteAiJob(
              docType: NoteGenerationType.tips,
              requestId: 99,
              status: TripNoteAiJobStatus.processing,
            ),
          ],
        ),
      );
      await ctrl.load();
      expect(job(c, NoteGenerationType.tips).phase, phase);
      expect(job(c, NoteGenerationType.tips).isBusy, isFalse);
      when(
        () => repo.generateNotes(NoteGenerationType.tips, tripId: 't'),
      ).thenAnswer(
        (_) async => const TripNoteAiJob(
          docType: NoteGenerationType.tips,
          requestId: 101,
          generation: 1,
        ),
      );
      when(
        () => requestsRepo.watchRequestEvents(101),
      ).thenAnswer((_) => const Stream.empty());
      await ctrl.generate(NoteGenerationType.tips);
      expect(job(c, NoteGenerationType.tips).requestId, 101);
      expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.pending);
    });
  }

  test('關閉住宿生成摘要後，同工作排除數仍可增加與恢復歸零', () async {
    var exclusionCount = 0;
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            docType: NoteGenerationType.lodgingTips,
            requestId: 200,
            generation: 2,
            status: TripNoteAiJobStatus.completed,
            exclusionCount: exclusionCount,
          ),
        ],
      ),
    );
    final c = makeContainer();
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    await _flush();
    ctrl.dismiss(NoteGenerationType.lodgingTips);
    exclusionCount = 1;
    await ctrl.load();
    expect(job(c, NoteGenerationType.lodgingTips).phase, NotesAiPhase.idle);
    expect(job(c, NoteGenerationType.lodgingTips).exclusionCount, 1);
    exclusionCount = 0;
    await ctrl.load();
    expect(job(c, NoteGenerationType.lodgingTips).phase, NotesAiPhase.idle);
    expect(job(c, NoteGenerationType.lodgingTips).exclusionCount, 0);
  });

  test('完成事件立刻進 completed;重讀拿不到摘要也不退回', () async {
    final c = makeContainer();
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    await _flush();
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();

    // 預設 stub 回空狀態:沒有摘要可拿,phase 仍要是 completed(完成提示靠它)。
    tipsEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();

    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.completed);
    expect(job(c, NoteGenerationType.tips).summary, isNull);
  });

  test('失敗事件帶 code → 翻成中文;逾時由重讀狀態判定', () async {
    var calls = 0;
    when(() => repo.fetchNotesAiState('t')).thenAnswer((_) async {
      calls++;
      return TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            docType: NoteGenerationType.emergency,
            requestId: 100,
            status: calls >= 2
                ? TripNoteAiJobStatus.timedOut
                : TripNoteAiJobStatus.idle,
          ),
        ],
      );
    });
    final c = makeContainer();
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    await _flush();

    await ctrl.generate(NoteGenerationType.tips);
    await ctrl.generate(NoteGenerationType.emergency);
    await _flush();
    tipsEvents.add(
      const TripRequestEvent(
        status: RequestStatus.failed,
        error: 'NOTES_AI_NO_VALID_ITEMS',
      ),
    );
    emergencyEvents.add(const TripRequestEvent(status: RequestStatus.failed));
    await _flush();

    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.failed);
    expect(job(c, NoteGenerationType.tips).failureMessage, 'AI 這次沒有產生可用的項目');
    expect(job(c, NoteGenerationType.emergency).phase, NotesAiPhase.timedOut);
  });

  test('停止等待只停這一種,不連坐另一種;伺服器沒確認回 false', () async {
    when(() => requestsRepo.stopWaiting(99)).thenThrow(Exception('offline'));
    final c = makeContainer();
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    await _flush();
    await ctrl.generate(NoteGenerationType.tips);
    await ctrl.generate(NoteGenerationType.emergency);
    await _flush();

    final confirmed = await ctrl.stopWaiting(NoteGenerationType.tips);
    await _flush();

    expect(confirmed, isFalse);
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.idle);
    expect(job(c, NoteGenerationType.emergency).phase, NotesAiPhase.pending);
  });

  test('同一種進行中再按不送出;NOTES_AI_JOB_ACTIVE 視為接上既有 job', () async {
    when(
      () => repo.generateNotes(NoteGenerationType.emergency, tripId: 't'),
    ).thenThrow(
      const ApiError(status: 409, code: 'NOTES_AI_JOB_ACTIVE', message: 'x'),
    );
    final c = makeContainer();
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    await _flush();

    await ctrl.generate(NoteGenerationType.tips);
    await ctrl.generate(NoteGenerationType.tips);
    verify(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 't'),
    ).called(1);

    await ctrl.generate(NoteGenerationType.emergency);
    expect(job(c, NoteGenerationType.emergency).phase, NotesAiPhase.pending);
    expect(job(c, NoteGenerationType.emergency).failureMessage, isNull);
  });

  test('載入持久狀態:進行中的 job 接上通道、排除數帶入;讀失敗只記 stateError', () async {
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.processing,
            requestId: 99,
            exclusionCount: 2,
          ),
        ],
      ),
    );
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    await _flush();

    final tips = job(c, NoteGenerationType.tips);
    expect(tips.phase, NotesAiPhase.pending);
    expect(tips.stage, NotesAiStage.processing);
    expect(tips.exclusionCount, 2);
    verify(() => requestsRepo.watchRequestEvents(99)).called(1);

    when(() => repo.fetchNotesAiState('t')).thenThrow(Exception('boom'));
    await c.read(notesAiControllerProvider('t').notifier).load();
    expect(c.read(notesAiControllerProvider('t')).stateError, isNotNull);
  });
  test('舊工作的摘要晚回來不能覆蓋新生成', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();
    final oldSummary = Completer<TripNoteAiState>();
    when(
      () => repo.fetchNotesAiState('t'),
    ).thenAnswer((_) => oldSummary.future);
    tipsEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.completed);
    final nextSubmission = Completer<TripNoteAiJob>();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 't'),
    ).thenAnswer((_) => nextSubmission.future);
    final newEvents = StreamController<TripRequestEvent>();
    addTearDown(() {
      newEvents.close();
    });
    when(
      () => requestsRepo.watchRequestEvents(101),
    ).thenAnswer((_) => newEvents.stream);
    final generating = ctrl.generate(NoteGenerationType.tips);
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.submitting);
    oldSummary.complete(
      const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 99,
            generation: 0,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.completed,
            insertedCount: 8,
          ),
        ],
      ),
    );
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.submitting);
    expect(job(c, NoteGenerationType.tips).summary, isNull);
    nextSubmission.complete(
      const TripNoteAiJob(
        requestId: 101,
        generation: 2,
        docType: NoteGenerationType.tips,
      ),
    );
    await generating;
    await _flush();
    final current = job(c, NoteGenerationType.tips);
    expect(current.requestId, 101);
    expect(current.phase, NotesAiPhase.pending);
    expect(current.summary, isNull);
  });

  test('停止等待後較早的持久狀態回應不能重新接上舊工作', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();
    final oldLoad = Completer<TripNoteAiState>();
    when(() => repo.fetchNotesAiState('t')).thenAnswer((_) => oldLoad.future);
    final pendingLoad = ctrl.load();
    when(() => requestsRepo.stopWaiting(99)).thenAnswer((_) async {});
    expect(await ctrl.stopWaiting(NoteGenerationType.tips), isTrue);
    oldLoad.complete(
      const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 99,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.processing,
          ),
        ],
      ),
    );
    await pendingLoad;
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.idle);
  });

  test('停止等待尚未確認時工作完成，保留完成與筆記結果', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();
    final stop = Completer<void>();
    when(() => requestsRepo.stopWaiting(99)).thenAnswer((_) => stop.future);
    final stopping = ctrl.stopWaiting(NoteGenerationType.tips);
    tipsEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.completed);
    stop.complete();
    expect(await stopping, isTrue);
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.completed);
  });

  test('module 重建後恢復新工作，釋放前的讀取不能回寫', () async {
    final oldLoad = Completer<TripNoteAiState>();
    var reads = 0;
    when(() => repo.fetchNotesAiState('t')).thenAnswer((_) {
      return ++reads == 1
          ? oldLoad.future
          : Future.value(
              const TripNoteAiState(
                jobs: [
                  TripNoteAiJob(
                    requestId: 100,
                    docType: NoteGenerationType.emergency,
                    status: TripNoteAiJobStatus.processing,
                  ),
                ],
              ),
            );
    });
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    await _flush();
    c.invalidate(notesAiControllerProvider('t'));
    await _flush();
    expect(job(c, NoteGenerationType.emergency).phase, NotesAiPhase.pending);
    oldLoad.complete(
      const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 99,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.processing,
          ),
        ],
      ),
    );
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.idle);
    expect(job(c, NoteGenerationType.emergency).requestId, 100);
    await c.read(notesAiControllerProvider('t').notifier).load();
    verify(() => requestsRepo.watchRequestEvents(100)).called(1);
  });

  test('終態重讀只接受同一工單與 generation 的摘要', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 't'),
    ).thenAnswer(
      (_) async => const TripNoteAiJob(
        requestId: 99,
        generation: 2,
        docType: NoteGenerationType.tips,
      ),
    );
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 99,
            generation: 1,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.completed,
            insertedCount: 77,
          ),
        ],
      ),
    );
    tipsEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.completed);
    expect(job(c, NoteGenerationType.tips).summary, isNull);
  });

  test('回前景以持久終態恢復摘要，後續舊 active 不讓完成倒退', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 99,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.completed,
            insertedCount: 4,
          ),
        ],
      ),
    );
    for (final lifecycleState in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(lifecycleState);
    }
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.completed);
    expect(job(c, NoteGenerationType.tips).summary?.insertedCount, 4);
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 99,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.processing,
          ),
        ],
      ),
    );
    await ctrl.load();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.completed);
  });

  test('停止等待後同一工作不在前景復活，新的 generation 可接續', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();
    when(() => requestsRepo.stopWaiting(99)).thenThrow(Exception('offline'));
    expect(await ctrl.stopWaiting(NoteGenerationType.tips), isFalse);
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 99,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.processing,
          ),
        ],
      ),
    );
    await ctrl.load();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.idle);
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 101,
            generation: 1,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.processing,
          ),
        ],
      ),
    );
    final nextEvents = StreamController<TripRequestEvent>();
    addTearDown(() {
      nextEvents.close();
    });
    when(
      () => requestsRepo.watchRequestEvents(101),
    ).thenAnswer((_) => nextEvents.stream);
    await ctrl.load();
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.pending);
    expect(job(c, NoteGenerationType.tips).requestId, 101);
  });

  test('接續前工單已終結也能立即讀到完成，不等下一個事件', () async {
    final c = makeContainer();
    c.listen(requestLifecycleProvider(99), (_, _) {});
    await _flush();
    tipsEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 99,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.processing,
          ),
        ],
      ),
    );
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.completed);
  });

  test('後端回已有工作時重讀持久狀態接續正確工單', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 't'),
    ).thenThrow(
      const ApiError(
        status: 409,
        code: 'NOTES_AI_JOB_ACTIVE',
        message: 'active',
      ),
    );
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 99,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.processing,
          ),
        ],
      ),
    );
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();
    expect(job(c, NoteGenerationType.tips).requestId, 99);
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.pending);
    tipsEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.completed);
  });

  test('已有工作但狀態讀不到仍能停止本機等待，不能宣稱伺服器確認', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 't'),
    ).thenThrow(
      const ApiError(
        status: 409,
        code: 'NOTES_AI_JOB_ACTIVE',
        message: 'active',
      ),
    );
    when(() => repo.fetchNotesAiState('t')).thenThrow(Exception('offline'));
    await ctrl.generate(NoteGenerationType.tips);
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.pending);
    expect(c.read(notesAiControllerProvider('t')).stateError, isNotNull);
    expect(await ctrl.stopWaiting(NoteGenerationType.tips), isFalse);
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.idle);
    verifyNever(() => requestsRepo.stopWaiting(any()));
  });

  test('接續新工作時釋放舊通道，舊事件不能污染新工作', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();
    expect(tipsEvents.hasListener, isTrue);
    final nextEvents = StreamController<TripRequestEvent>();
    addTearDown(() {
      nextEvents.close();
    });
    when(
      () => requestsRepo.watchRequestEvents(101),
    ).thenAnswer((_) => nextEvents.stream);
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 101,
            generation: 1,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.processing,
          ),
        ],
      ),
    );
    await ctrl.load();
    await _flush();
    expect(nextEvents.hasListener, isTrue);
    expect(tipsEvents.hasListener, isFalse);
    tipsEvents.add(
      const TripRequestEvent(status: RequestStatus.failed, error: 'old'),
    );
    await _flush();
    expect(job(c, NoteGenerationType.tips).requestId, 101);
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.pending);
  });

  test('較新的讀取已成功，較早失敗不重新顯示狀態錯誤', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    final oldRead = Completer<TripNoteAiState>();
    when(() => repo.fetchNotesAiState('t')).thenAnswer((_) => oldRead.future);
    final loading = ctrl.load();
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 99,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.processing,
          ),
        ],
      ),
    );
    await ctrl.load();
    oldRead.completeError(Exception('old offline'));
    await loading;
    expect(c.read(notesAiControllerProvider('t')).stateError, isNull);
    expect(job(c, NoteGenerationType.tips).requestId, 99);
  });

  test('關閉完成提示後，晚回的摘要不能重新打開提示', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();
    final summary = Completer<TripNoteAiState>();
    when(() => repo.fetchNotesAiState('t')).thenAnswer((_) => summary.future);
    tipsEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();
    ctrl.dismiss(NoteGenerationType.tips);
    summary.complete(
      const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 99,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.completed,
            insertedCount: 4,
          ),
        ],
      ),
    );
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.idle);
    expect(job(c, NoteGenerationType.tips).summary, isNull);
  });
  test('切換行程與離頁隔離狀態，離頁前送出的晚回應不接上舊通道', () async {
    final c = makeContainer();
    final a = c.listen(notesAiControllerProvider('t'), (_, _) {});
    final b = c.listen(notesAiControllerProvider('other'), (_, _) {});
    await _flush();
    final delayed = Completer<TripNoteAiJob>();
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 't'),
    ).thenAnswer((_) => delayed.future);
    when(
      () => repo.generateNotes(NoteGenerationType.tips, tripId: 'other'),
    ).thenAnswer(
      (_) async => const TripNoteAiJob(
        requestId: 200,
        tripId: 'other',
        docType: NoteGenerationType.tips,
      ),
    );
    final otherEvents = StreamController<TripRequestEvent>();
    addTearDown(() {
      otherEvents.close();
    });
    when(
      () => requestsRepo.watchRequestEvents(200),
    ).thenAnswer((_) => otherEvents.stream);
    final generating = c
        .read(notesAiControllerProvider('t').notifier)
        .generate(NoteGenerationType.tips);
    await c
        .read(notesAiControllerProvider('other').notifier)
        .generate(NoteGenerationType.tips);
    await _flush();
    expect(a.read().of(NoteGenerationType.tips).phase, NotesAiPhase.submitting);
    expect(b.read().of(NoteGenerationType.tips).requestId, 200);
    a.close();
    await _flush();
    delayed.complete(
      const TripNoteAiJob(
        requestId: 99,
        tripId: 't',
        docType: NoteGenerationType.tips,
      ),
    );
    await generating;
    await _flush();
    verifyNever(() => requestsRepo.watchRequestEvents(99));
    expect(b.read().of(NoteGenerationType.tips).phase, NotesAiPhase.pending);
    when(() => repo.fetchNotesAiState('t')).thenAnswer(
      (_) async => const TripNoteAiState(
        jobs: [
          TripNoteAiJob(
            requestId: 99,
            docType: NoteGenerationType.tips,
            status: TripNoteAiJobStatus.processing,
          ),
        ],
      ),
    );
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    await _flush();
    expect(job(c, NoteGenerationType.tips).requestId, 99);
    tipsEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.completed);
    expect(b.read().of(NoteGenerationType.tips).phase, NotesAiPhase.pending);
  });

  test('完成後摘要讀取丟例外，已確認完成不退回等待', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();
    when(() => repo.fetchNotesAiState('t')).thenThrow(Exception('offline'));
    tipsEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.completed);
    expect(job(c, NoteGenerationType.tips).summary, isNull);
  });

  test('工單已確認逾時，摘要 API 失敗也保留逾時提示', () async {
    final c = makeContainer();
    c.listen(notesAiControllerProvider('t'), (_, _) {});
    final ctrl = c.read(notesAiControllerProvider('t').notifier);
    await _flush();
    when(() => requestsRepo.fetchRequest(99)).thenAnswer(
      (_) async => const TripRequest(
        id: 99,
        tripId: 't',
        message: 'notes',
        status: RequestStatus.failed,
        terminalReason: TerminalReason.timedOut,
      ),
    );
    when(() => repo.fetchNotesAiState('t')).thenThrow(Exception('offline'));
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();
    expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.timedOut);
  });

  for (final reason in [TerminalReason.timedOut, TerminalReason.cancelled]) {
    test('SSE 失敗後補回終態原因 $reason，不繼續等待也不重讀摘要', () async {
      final c = makeContainer();
      c.listen(notesAiControllerProvider('t'), (_, _) {});
      final ctrl = c.read(notesAiControllerProvider('t').notifier);
      await _flush();
      await ctrl.generate(NoteGenerationType.tips);
      await _flush();
      final terminalRead = Completer<TripRequest>();
      when(
        () => requestsRepo.fetchRequest(99),
      ).thenAnswer((_) => terminalRead.future);
      when(() => repo.fetchNotesAiState('t')).thenThrow(Exception('offline'));
      clearInteractions(repo);
      tipsEvents.add(const TripRequestEvent(status: RequestStatus.failed));
      await _flush();
      expect(job(c, NoteGenerationType.tips).phase, NotesAiPhase.failed);
      terminalRead.complete(
        TripRequest(
          id: 99,
          tripId: 't',
          message: 'notes',
          status: RequestStatus.failed,
          terminalReason: reason,
        ),
      );
      await _flush();
      expect(
        job(c, NoteGenerationType.tips).phase,
        reason == TerminalReason.timedOut
            ? NotesAiPhase.timedOut
            : NotesAiPhase.idle,
      );
      verify(() => repo.fetchNotesAiState('t')).called(1);
    });
  }
}
