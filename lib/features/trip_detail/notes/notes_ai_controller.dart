/// 筆記 AI 生成的狀態機 —— UI-free,每種 docType 一筆 [NotesAiJobState]。
///
/// 三種生成是三條獨立的線;任何一格退回單一欄位,生成行前須知時緊急聯絡就會被連坐。
/// 等待本身交給工單 lifecycle([requestLifecycleProvider]),這裡只做「事件 → 狀態」的
/// 轉移,以及完成後的一次性重讀(不是輪詢)。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/error_message.dart';
import '../../../models/note_section.dart';
import '../../../models/notes.dart';
import '../../../models/trip_request.dart';
import '../../requests/request_lifecycle.dart';
import '../trip_providers.dart';

/// 生成走到哪一階段。文案要講清楚正在做什麼 —— HIG generative-ai:
/// 「instead of "Processing…", say "Summarizing key themes from your notes."」
enum NotesAiStage {
  /// 已送出,還沒被領走。
  queued,

  /// 已被領走,正在讀行程並整理內容。
  processing,
}

enum NotesAiPhase {
  idle,

  /// POST 已送出、還沒拿到 job(同型連點的守衛)。
  submitting,

  /// job 已啟動、還在等終態。
  pending,
  failed,

  /// 逾時與一般失敗要分開呈現。
  timedOut,
  completed,
}

/// 一種 docType 的完整狀態;不變式由型別保證,不靠六個站點各自記得清哪幾個集合。
@immutable
class NotesAiJobState {
  const NotesAiJobState({
    this.phase = NotesAiPhase.idle,
    this.stage = NotesAiStage.queued,
    this.requestId,
    this.exclusionCount = 0,
    this.failureMessage,
    this.summary,
  });

  final NotesAiPhase phase;
  final NotesAiStage stage;

  /// 停止等待要打的就是它;接上既有 job 而沒有 requestId 時為 null。
  final int? requestId;
  final int exclusionCount;
  final String? failureMessage;

  /// 最近一次完成的摘要(終態後重讀狀態才拿得到)。
  final TripNoteAiJob? summary;

  bool get isBusy =>
      phase == NotesAiPhase.submitting || phase == NotesAiPhase.pending;

  NotesAiJobState copyWith({
    NotesAiPhase? phase,
    NotesAiStage? stage,
    int? Function()? requestId,
    int? exclusionCount,
    String? Function()? failureMessage,
    TripNoteAiJob? Function()? summary,
  }) => NotesAiJobState(
    phase: phase ?? this.phase,
    stage: stage ?? this.stage,
    requestId: requestId == null ? this.requestId : requestId(),
    exclusionCount: exclusionCount ?? this.exclusionCount,
    failureMessage: failureMessage == null
        ? this.failureMessage
        : failureMessage(),
    summary: summary == null ? this.summary : summary(),
  );
}

@immutable
class NotesAiState {
  const NotesAiState({this.jobs = const {}, this.stateError});

  final Map<NoteGenerationType, NotesAiJobState> jobs;

  /// 讀持久狀態失敗只影響 AI 區塊,筆記本體照常。
  final String? stateError;

  NotesAiJobState of(NoteGenerationType type) =>
      jobs[type] ?? const NotesAiJobState();

  /// 正在送出或進行中的類型;每顆按鈕只看自己那一種。
  Set<NoteGenerationType> get busyTypes => {
    for (final MapEntry(key: type, value: job) in jobs.entries)
      if (job.isBusy) type,
  };

  NotesAiState _with(
    NoteGenerationType type,
    NotesAiJobState Function(NotesAiJobState job) update,
  ) => NotesAiState(
    jobs: {...jobs, type: update(of(type))},
    stateError: stateError,
  );
}

class NotesAiController extends Notifier<NotesAiState> {
  NotesAiController(this.tripId);

  final String tripId;

  bool _disposed = false;
  AppLifecycleListener? _lifecycle;

  /// 已掛上 lifecycle 的 request;同一個 job 不重複掛(resume 與離線 flush 可能同時觸發重讀)。
  final _watched = <int>{};

  @override
  NotesAiState build() {
    ref.onDispose(() {
      _disposed = true;
      _lifecycle?.dispose();
    });
    // 回到前景重讀一次 —— 使用者可能在別的裝置按了生成,或這支 app 被系統回收過。
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(load()));
    unawaited(Future<void>.microtask(load));
    return const NotesAiState();
  }

  void _set(
    NoteGenerationType type,
    NotesAiJobState Function(NotesAiJobState) f,
  ) {
    if (_disposed) return;
    state = state._with(type, f);
  }

  /// 讀一次持久狀態。**失敗只記在 stateError**,不讓它冒泡到整頁。
  Future<void> load() async {
    try {
      final persisted = await ref
          .read(tripRepositoryProvider)
          .fetchNotesAiState(tripId);
      if (_disposed) return;
      var next = NotesAiState(jobs: state.jobs);
      for (final job in persisted.jobs) {
        final type = job.docType;
        if (type == null) continue;
        next = next._with(
          type,
          (j) => j.copyWith(exclusionCount: job.exclusionCount),
        );
      }
      for (final job in persisted.activeJobs) {
        final type = job.docType!;
        next = next._with(
          type,
          (j) => j.copyWith(
            phase: NotesAiPhase.pending,
            stage: job.status == TripNoteAiJobStatus.processing
                ? NotesAiStage.processing
                : NotesAiStage.queued,
            requestId: () => job.requestId,
          ),
        );
      }
      state = next;
      for (final job in persisted.activeJobs) {
        _watch(job.requestId, job.docType!);
      }
    } catch (error) {
      if (_disposed) return;
      state = NotesAiState(
        jobs: state.jobs,
        stateError: notesAiErrorMessage(error),
      );
    }
  }

  /// 守衛只看**這一種**:全域守衛會讓「按鈕按得下去但什麼都沒送出」。
  Future<void> generate(NoteGenerationType type) async {
    if (state.of(type).isBusy) return;
    _set(
      type,
      (j) => j.copyWith(
        phase: NotesAiPhase.submitting,
        failureMessage: () => null,
        summary: () => null,
      ),
    );
    try {
      final job = await ref
          .read(tripRepositoryProvider)
          .generateNotes(type, tripId: tripId);
      if (_disposed) return;
      _set(
        type,
        (j) => j.copyWith(
          phase: NotesAiPhase.pending,
          stage: NotesAiStage.queued,
          requestId: () => job.requestId,
        ),
      );
      _watch(job.requestId, type);
    } catch (error) {
      // 攔 Error 與 Exception 兩類:解析非預期回應丟的是 TypeError。
      if (_disposed) return;
      if (error is ApiError && error.code == notesAiJobActiveCode) {
        // 後端說同一份文件已經有 job 在跑 —— 那正是使用者要的結果,不是失敗。
        // 這次回應沒帶 requestId,所以只接上進行中狀態、沒有自己的進度通道。
        _set(type, (j) => j.copyWith(phase: NotesAiPhase.pending));
        return;
      }
      _set(
        type,
        (j) => j.copyWith(
          phase: NotesAiPhase.failed,
          failureMessage: () => notesAiErrorMessage(error),
        ),
      );
    }
  }

  void _watch(int requestId, NoteGenerationType type) {
    if (!_watched.add(requestId)) return;
    ref.listen(requestLifecycleProvider(requestId), (_, next) {
      // 只認自己這一種目前掛的 request;停止等待或重試後舊通道的事件不算數。
      if (state.of(type).requestId != requestId) return;
      switch (next) {
        case RequestInFlight(:final status):
          _set(
            type,
            (j) => j.copyWith(
              stage: status == RequestStatus.processing
                  ? NotesAiStage.processing
                  : NotesAiStage.queued,
            ),
          );
        case RequestTerminal():
          _onTerminal(type, next);
      }
    });
  }

  void _onTerminal(NoteGenerationType type, RequestTerminal terminal) {
    if (terminal.terminalReason == TerminalReason.cancelled) {
      // 停止等待:本機已在 stopWaiting 收掉,這裡不再動。
      return;
    }
    if (terminal.status == RequestStatus.completed &&
        terminal.errorMessage == null) {
      _set(type, (j) => j.copyWith(phase: NotesAiPhase.completed));
      // AI 直接改了筆記,畫面要重抓才看得到。
      ref.invalidate(tripNotesProvider(tripId));
      unawaited(_refreshOutcome(type));
      return;
    }
    final raw = terminal.errorMessage;
    _set(
      type,
      (j) => j.copyWith(
        phase: NotesAiPhase.failed,
        failureMessage: () =>
            raw == null ? notesAiFallbackMessage : notesAiErrorMessage(raw),
      ),
    );
    // 逾時與一般失敗在進度通道上長得一樣,要靠重讀狀態才分得出來。client 不自己倒數。
    unawaited(_refreshOutcome(type));
  }

  /// 終態後重讀一次狀態,拿完成摘要或確認是不是逾時。**一次性,不是輪詢。**
  Future<void> _refreshOutcome(NoteGenerationType type) async {
    try {
      final persisted = await ref
          .read(tripRepositoryProvider)
          .fetchNotesAiState(tripId);
      if (_disposed) return;
      final job = persisted.jobFor(type);
      if (job == null) return;
      if (job.status == TripNoteAiJobStatus.timedOut) {
        _set(
          type,
          (j) => j.copyWith(
            phase: NotesAiPhase.timedOut,
            failureMessage: () => null,
            summary: () => null,
          ),
        );
      } else if (job.status == TripNoteAiJobStatus.completed) {
        _set(
          type,
          (j) => j.copyWith(
            phase: NotesAiPhase.completed,
            summary: () => job,
            exclusionCount: job.exclusionCount,
          ),
        );
      }
    } on Object {
      // 摘要拿不到不影響主流程 —— 生成本身已經完成或失敗了。
    }
  }

  /// 停止等待 —— **不中止 AI**(後端 ADR-0007)。只停這一種,不連坐別的。
  /// 回傳伺服器是否確認;沒確認時畫面要誠實提示。
  Future<bool> stopWaiting(NoteGenerationType type) async {
    final requestId = state.of(type).requestId;
    if (requestId == null) return true;
    final confirmed = await ref
        .read(requestLifecycleProvider(requestId).notifier)
        .stopWaiting();
    _set(
      type,
      (j) => j.copyWith(phase: NotesAiPhase.idle, requestId: () => null),
    );
    return confirmed;
  }

  /// 關掉「AI 狀態讀取失敗」面板。
  void clearStateError() {
    if (_disposed) return;
    state = NotesAiState(jobs: state.jobs);
  }

  /// 關掉失敗 / 逾時 / 摘要面板。
  void dismiss(NoteGenerationType type) {
    _set(
      type,
      (j) => j.copyWith(
        phase: NotesAiPhase.idle,
        failureMessage: () => null,
        summary: () => null,
      ),
    );
  }
}

final notesAiControllerProvider = NotifierProvider.autoDispose
    .family<NotesAiController, NotesAiState, String>(NotesAiController.new);

/// 「同一份文件已經有 job 在跑」。這個 code 不走錯誤翻譯,當成接上既有 job。
const notesAiJobActiveCode = 'NOTES_AI_JOB_ACTIVE';

/// 生成期的 error code → 人話。維護權相關的 code 只會在維護權 PATCH 出現,這裡不列。
const _notesAiErrorMessages = <String, String>{
  'NOTES_AI_INVALID_OUTPUT': 'AI 這次產生的內容格式不正確',
  'NOTES_AI_NO_VALID_ITEMS': 'AI 這次沒有產生可用的項目',
  'NOTES_AI_APPLY_FAILED': 'AI 內容寫回筆記時失敗',
};

const notesAiFallbackMessage = '目前無法完成 AI 生成';

/// 三條失敗路徑(POST 例外／lifecycle 終結事件／狀態讀取)共用這一條翻譯管線,
/// 走全 app 一致的三層 fallback:**server 回繁中就直接用 → 否則查 code 對照表 →
/// 再不然通用訊息**。原始 error code 與型別文字一律不外流到畫面。
String notesAiErrorMessage(Object error) {
  final (String? code, String? message) = switch (error) {
    ApiError() => (error.code, error.message),
    String() => (error, error),
    _ => (null, null),
  };
  if (message != null && hasCjk(message)) return message;
  if (code == null) return notesAiFallbackMessage;
  return _notesAiErrorMessages[code] ?? notesAiFallbackMessage;
}
