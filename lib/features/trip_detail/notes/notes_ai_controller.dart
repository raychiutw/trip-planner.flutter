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

/// 每種筆記生成的使用者可觀察階段。
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

/// 一種 docType 的完整狀態；所有轉移由 controller 集中維護。
@immutable
class NotesAiJobState {
  const NotesAiJobState({
    this.phase = NotesAiPhase.idle,
    this.stage = NotesAiStage.queued,
    this.requestId,
    this.generation = 0,
    this.exclusionCount = 0,
    this.failureMessage,
    this.summary,
  });

  final NotesAiPhase phase;
  final NotesAiStage stage;

  /// 停止等待要打的就是它;接上既有 job 而沒有 requestId 時為 null。
  final int? requestId;
  final int generation;
  final int exclusionCount;
  final String? failureMessage;

  /// 最近一次完成的摘要(終態後重讀狀態才拿得到)。
  final TripNoteAiJob? summary;

  /// 此生成類型正在送出或等待結果，不影響其他生成類型的忙碌狀態。
  bool get isBusy =>
      phase == NotesAiPhase.submitting || phase == NotesAiPhase.pending;

  /// 建立更新後的工作快照；可清除欄位以回呼明確表達 null。
  NotesAiJobState copyWith({
    NotesAiPhase? phase,
    NotesAiStage? stage,
    int? Function()? requestId,
    int? generation,
    int? exclusionCount,
    String? Function()? failureMessage,
    TripNoteAiJob? Function()? summary,
  }) => NotesAiJobState(
    phase: phase ?? this.phase,
    stage: stage ?? this.stage,
    requestId: requestId == null ? this.requestId : requestId(),
    generation: generation ?? this.generation,
    exclusionCount: exclusionCount ?? this.exclusionCount,
    failureMessage: failureMessage == null
        ? this.failureMessage
        : failureMessage(),
    summary: summary == null ? this.summary : summary(),
  );
}

/// 單一行程的各類生成工作與持久狀態讀取錯誤。
@immutable
class NotesAiState {
  const NotesAiState({this.jobs = const {}, this.stateError});

  final Map<NoteGenerationType, NotesAiJobState> jobs;

  /// 讀持久狀態失敗只影響 AI 區塊,筆記本體照常。
  final String? stateError;

  /// 讀取指定類型；未生成過時回傳閒置快照。
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

/// 協調單一行程的生成、恢復與停止等待；工單 transport 由既有 lifecycle 承接。
class NotesAiController extends Notifier<NotesAiState> {
  NotesAiController(this.tripId);

  final String tripId;

  bool _disposed = false;
  int _run = 0;
  int _loadSequence = 0;
  AppLifecycleListener? _lifecycle;

  /// 每種類型只保留目前工單的訂閱，替換時讓舊 lifecycle 自動釋放。
  final _subscriptions =
      <
        NoteGenerationType,
        ({
          int requestId,
          ProviderSubscription<RequestLifecycleState> subscription,
        })
      >{};

  /// 建立目前生命週期，進頁及回前景時讀取持久工作。
  @override
  NotesAiState build() {
    final run = ++_run;
    _disposed = false;
    _subscriptions.clear();
    ref.onDispose(() {
      if (_run == run) _run++;
      _disposed = true;
      _lifecycle?.dispose();
    });
    // 回到前景重讀一次 —— 使用者可能在別的裝置按了生成,或這支 app 被系統回收過。
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(load()));
    unawaited(
      Future<void>.microtask(() {
        if (!_disposed && run == _run) return load();
      }),
    );
    return const NotesAiState();
  }

  void _set(
    NoteGenerationType type,
    NotesAiJobState Function(NotesAiJobState) f,
  ) {
    if (_disposed) return;
    _publish(state._with(type, f));
  }

  // 完成來源可以是串流、前景恢復或摘要確認，首次完成都要更新筆記。
  void _publish(NotesAiState next) {
    final refreshNotes = next.jobs.entries.any((entry) {
      final previous = state.of(entry.key);
      final current = entry.value;
      return current.phase == NotesAiPhase.completed &&
          (previous.phase != NotesAiPhase.completed ||
              previous.requestId != current.requestId ||
              previous.generation != current.generation);
    });
    state = next;
    if (refreshNotes) ref.invalidate(tripNotesProvider(tripId));
  }

  /// 讀一次持久狀態。**失敗只記在 stateError**,不讓它冒泡到整頁。
  Future<void> load() async {
    final run = _run;
    final sequence = ++_loadSequence;
    final before = state;
    try {
      final persisted = await ref
          .read(tripRepositoryProvider)
          .fetchNotesAiState(tripId);
      if (_disposed || run != _run || sequence != _loadSequence) return;
      var next = NotesAiState(jobs: state.jobs);
      for (final job in persisted.jobs) {
        final type = job.docType;
        if (type == null) continue;
        final current = state.of(type);
        final previous = before.of(type);
        if (previous.requestId != current.requestId ||
            previous.generation != current.generation ||
            previous.phase != current.phase) {
          continue;
        }
        if (job.generation < current.generation ||
            current.phase == NotesAiPhase.submitting) {
          continue;
        }
        final sameJob =
            current.requestId == job.requestId &&
            current.generation == job.generation;
        next = next._with(
          type,
          (j) => j.copyWith(exclusionCount: job.exclusionCount),
        );
        if (sameJob && current.phase == NotesAiPhase.idle) continue;
        if (sameJob &&
            (current.phase == NotesAiPhase.failed ||
                current.phase == NotesAiPhase.timedOut) &&
            (job.status == TripNoteAiJobStatus.pending ||
                job.status == TripNoteAiJobStatus.processing)) {
          continue;
        }
        if (sameJob &&
            current.phase == NotesAiPhase.completed &&
            job.status != TripNoteAiJobStatus.completed) {
          continue;
        }
        if (job.requestId <= 0 || job.status == TripNoteAiJobStatus.idle) {
          continue;
        }
        final phase = switch (job.status) {
          TripNoteAiJobStatus.pending ||
          TripNoteAiJobStatus.processing => NotesAiPhase.pending,
          TripNoteAiJobStatus.completed => NotesAiPhase.completed,
          TripNoteAiJobStatus.failed => NotesAiPhase.failed,
          TripNoteAiJobStatus.timedOut => NotesAiPhase.timedOut,
          TripNoteAiJobStatus.idle => NotesAiPhase.idle,
        };
        next = next._with(
          type,
          (j) => j.copyWith(
            phase: phase,
            stage: job.status == TripNoteAiJobStatus.processing
                ? NotesAiStage.processing
                : NotesAiStage.queued,
            requestId: () => job.requestId,
            generation: job.generation,
            summary: () => phase == NotesAiPhase.completed ? job : null,
            failureMessage: () => phase == NotesAiPhase.failed
                ? notesAiErrorMessage(job.errorMessage ?? job.errorCode ?? '')
                : null,
          ),
        );
      }
      _publish(next);
      for (final job in persisted.activeJobs) {
        if (state.of(job.docType!).requestId == job.requestId &&
            state.of(job.docType!).isBusy) {
          _watch(job.requestId, job.docType!);
        }
      }
    } catch (error) {
      if (_disposed || run != _run || sequence != _loadSequence) return;
      state = NotesAiState(
        jobs: state.jobs,
        stateError: notesAiErrorMessage(error),
      );
    }
  }

  /// 守衛只看**這一種**:全域守衛會讓「按鈕按得下去但什麼都沒送出」。
  Future<void> generate(NoteGenerationType type) async {
    if (_disposed || state.of(type).isBusy) return;
    final run = _run;
    _subscriptions.remove(type)?.subscription.close();
    _set(
      type,
      (j) => j.copyWith(
        phase: NotesAiPhase.submitting,
        requestId: () => null,
        failureMessage: () => null,
        summary: () => null,
      ),
    );
    try {
      final job = await ref
          .read(tripRepositoryProvider)
          .generateNotes(type, tripId: tripId);
      if (_disposed || run != _run) return;
      _set(
        type,
        (j) => j.copyWith(
          phase: NotesAiPhase.pending,
          stage: NotesAiStage.queued,
          requestId: () => job.requestId,
          generation: job.generation,
        ),
      );
      _watch(job.requestId, type);
    } catch (error) {
      // 攔 Error 與 Exception 兩類:解析非預期回應丟的是 TypeError。
      if (_disposed || run != _run) return;
      if (error is ApiError && error.code == notesAiJobActiveCode) {
        // 後端說同一份文件已經有 job 在跑 —— 那正是使用者要的結果,不是失敗。
        // 回應沒有 requestId，讀持久狀態接續；讀失敗仍保留進行中與停止出口。
        _set(type, (j) => j.copyWith(phase: NotesAiPhase.pending));
        await load();
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
    if (_subscriptions[type]?.requestId == requestId) return;
    _subscriptions.remove(type)?.subscription.close();
    final run = _run;
    final subscription = ref.listen(requestLifecycleProvider(requestId), (
      _,
      next,
    ) {
      // 只認自己這一種目前掛的 request;停止等待或重試後舊通道的事件不算數。
      if (_disposed ||
          run != _run ||
          state.of(type).requestId != requestId ||
          (!state.of(type).isBusy &&
              !(state.of(type).phase == NotesAiPhase.failed &&
                  next is RequestTerminal &&
                  next.terminalReason != null))) {
        return;
      }
      switch (next) {
        case RequestInFlight(:final status):
          _set(
            type,
            (j) => j.copyWith(
              stage: status == RequestStatus.processing
                  ? NotesAiStage.processing
                  : j.stage,
            ),
          );
        case RequestTerminal():
          _onTerminal(type, next);
      }
    }, fireImmediately: true);
    _subscriptions[type] = (requestId: requestId, subscription: subscription);
  }

  void _onTerminal(NoteGenerationType type, RequestTerminal terminal) {
    if (terminal.terminalReason == TerminalReason.cancelled) {
      // 本機或其他裝置停止等待都不表示 AI 已中止。
      _set(type, (j) => j.copyWith(phase: NotesAiPhase.idle));
      return;
    }
    if (terminal.status == RequestStatus.completed &&
        terminal.errorMessage == null) {
      _set(type, (j) => j.copyWith(phase: NotesAiPhase.completed));
      unawaited(_refreshOutcome(type));
      return;
    }
    // lifecycle 稍後才補到原因時，只補提示，不重做終態後的摘要讀取。
    if (state.of(type).phase == NotesAiPhase.failed &&
        terminal.terminalReason == TerminalReason.timedOut) {
      _set(type, (j) => j.copyWith(phase: NotesAiPhase.timedOut));
      return;
    }
    final raw = terminal.errorMessage;
    _set(
      type,
      (j) => j.copyWith(
        phase: terminal.terminalReason == TerminalReason.timedOut
            ? NotesAiPhase.timedOut
            : NotesAiPhase.failed,
        failureMessage: () =>
            raw == null ? notesAiFallbackMessage : notesAiErrorMessage(raw),
      ),
    );
    // SSE 可能沒有逾時原因；重讀持久狀態補齊，client 不自行倒數。
    unawaited(_refreshOutcome(type));
  }

  /// 終態後重讀一次狀態,拿完成摘要或確認是不是逾時。**一次性,不是輪詢。**
  Future<void> _refreshOutcome(NoteGenerationType type) async {
    final run = _run;
    final before = state.of(type);
    final requestId = before.requestId;
    try {
      final persisted = await ref
          .read(tripRepositoryProvider)
          .fetchNotesAiState(tripId);
      if (_disposed || run != _run) return;
      final job = persisted.jobFor(type);
      if (job == null ||
          state.of(type).phase != before.phase ||
          state.of(type).requestId != requestId ||
          job.requestId != requestId ||
          job.generation != state.of(type).generation) {
        return;
      }
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

  /// 停止等待 —— **不中止 AI**。只停這一種,不連坐別的。
  /// 回傳伺服器是否確認;沒確認時畫面要誠實提示。
  Future<bool> stopWaiting(NoteGenerationType type) async {
    final run = _run;
    final requestId = state.of(type).requestId;
    if (requestId == null) {
      _set(type, (j) => j.copyWith(phase: NotesAiPhase.idle));
      return false;
    }
    final confirmed = await ref
        .read(requestLifecycleProvider(requestId).notifier)
        .stopWaiting();
    if (_disposed ||
        run != _run ||
        state.of(type).requestId != requestId ||
        !state.of(type).isBusy) {
      return confirmed;
    }
    _set(type, (j) => j.copyWith(phase: NotesAiPhase.idle));
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
