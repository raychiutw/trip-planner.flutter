import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  var notesInvalidated = 0;

  setUp(() {
    repo = _MockTripRepo();
    requestsRepo = _MockRequestsRepo();
    tipsEvents = StreamController<TripRequestEvent>();
    emergencyEvents = StreamController<TripRequestEvent>();
    notesInvalidated = 0;
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
        requestPollWaitProvider.overrideWithValue(
          () => Completer<void>().future,
        ),
        tripNotesProvider.overrideWith((ref, tripId) {
          notesInvalidated++;
          return Stream.value(const TripNotes());
        }),
      ],
    );
    addTearDown(c.dispose);
    // 讓 tripNotesProvider 活著,才數得到 invalidate 後的重建。
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
    final before = notesInvalidated;
    await ctrl.generate(NoteGenerationType.tips);
    await _flush();

    tipsEvents.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();

    final tips = job(c, NoteGenerationType.tips);
    expect(tips.phase, NotesAiPhase.completed);
    expect(tips.summary?.insertedCount, 3);
    expect(notesInvalidated, greaterThan(before), reason: '完成後筆記要重抓');
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
}
