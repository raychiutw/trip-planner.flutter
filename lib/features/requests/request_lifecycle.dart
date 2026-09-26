/// 工單 lifecycle —— 「送出後等到終結」這件事的唯一擁有者。
///
/// 畫面只看 [RequestLifecycleState] 與呼叫 [RequestLifecycle.stopWaiting];
/// transport(SSE 或輪詢)、回前景重讀、本機先終結,都在這裡決定。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../models/trip_request.dart';

/// 停止等待但伺服器沒有確認時的提示，由共用 lifecycle 提供給畫面。
const kStopWaitingUnconfirmedMessage = '已停止等待，但伺服器沒有確認。它可能仍在處理。';

sealed class RequestLifecycleState {
  const RequestLifecycleState({this.request});

  /// 最近一次從伺服器讀回的 row;SSE 事件不帶完整 row,所以可能是舊的。
  final TripRequest? request;
}

/// 還在等(open / processing)。
final class RequestInFlight extends RequestLifecycleState {
  const RequestInFlight({
    super.request,
    this.status = RequestStatus.open,
    this.authExpired = false,
  });

  /// 種子工單與 SSE 事件共同提供的目前進度。
  final RequestStatus status;

  /// 讀取遇 401，等待已停止，畫面需要提示重新登入。
  final bool authExpired;
}

/// 已終結。[serverConfirmed] 為 false 表示是本機先終結(停止等待沒送到)。
final class RequestTerminal extends RequestLifecycleState {
  const RequestTerminal({
    required this.status,
    this.terminalReason,
    this.serverConfirmed = true,
    this.authExpired = false,
    this.errorMessage,
    super.request,
  });

  final RequestStatus status;
  final TerminalReason? terminalReason;
  final bool serverConfirmed;
  final bool authExpired;

  /// 終態事件的原始錯誤，交由各領域翻譯。
  final String? errorMessage;
}

/// SSE 收不到時的輪詢起始間隔;每輪加倍到 [kRequestPollCeiling] 封頂,
/// 回前景重設。
const kRequestPollInterval = Duration(seconds: 4);
const kRequestPollCeiling = Duration(seconds: 30);

class RequestLifecycle extends Notifier<RequestLifecycleState> {
  RequestLifecycle(
    this.requestId, {
    Future<void> Function(Duration) wait = Future<void>.delayed,
  }) : _wait = wait;

  final int requestId;
  final Future<void> Function(Duration) _wait;

  StreamSubscription<TripRequestEvent>? _events;
  AppLifecycleListener? _lifecycle;

  /// riverpod 3 重建(invalidate)時沿用同一個 Notifier 實例。每次 build 換一個
  /// run token,還在 await 的舊 continuation 醒來看 token 不同就作廢,
  /// 不會出現兩條輪詢迴圈或舊 row 蓋到新 state。dispose 也算換 token。
  int _run = 0;
  bool _polling = false;
  bool _hydratingTerminal = false;

  /// 同一時間只有一個 fetch 在飛:輪詢與回前景撞在一起就共用它。
  Future<TripRequest?>? _inflight;

  /// app 在背景:輪詢停在這個 Completer 上,回前景才放行。
  Completer<void>? _resumed;
  Duration _pollDelay = kRequestPollInterval;

  bool _stale(int run) => run != _run;
  bool get _authExpired => switch (state) {
    RequestInFlight(authExpired: true) => true,
    _ => false,
  };

  @override
  RequestLifecycleState build() {
    final run = ++_run;
    _polling = false;
    _hydratingTerminal = false;
    _events = null;
    _inflight = null;
    _resumed = null;
    _pollDelay = kRequestPollInterval;
    ref.onDispose(() {
      if (_run == run) _run++;
      _events?.cancel();
      _lifecycle?.dispose();
      _resumed?.complete();
    });
    // 用 onStateChange 而不是 onHide/onResume:平台(與測試)可能直接跳到
    // paused,不經 hidden。
    _lifecycle = AppLifecycleListener(
      onStateChange: (next) {
        switch (next) {
          case AppLifecycleState.resumed:
            _pollDelay = kRequestPollInterval;
            unawaited(_refetch(run));
            _resumed?.complete();
            _resumed = null;
          case AppLifecycleState.hidden || AppLifecycleState.paused:
            _resumed ??= Completer<void>();
          case AppLifecycleState.inactive || AppLifecycleState.detached:
            break;
        }
      },
    );
    // build 回傳前不能碰 state,所以排到下一個 microtask 再起跑。
    unawaited(Future<void>.microtask(() => _start(run)));
    return const RequestInFlight();
  }

  Future<void> _start(int run) async {
    if (await _refetch(run)) return;
    _watchEvents(run);
  }

  /// 讀一次 row;回 true = 已終結或已作廢(不用再等)。
  Future<bool> _refetch(int run) async {
    if (_stale(run) || state is RequestTerminal || _authExpired) {
      return true;
    }
    await _readShared(run);
    return _stale(run) || state is RequestTerminal || _authExpired;
  }

  Future<TripRequest?> _readShared(int run) {
    return _inflight ??= _fetchOnce(run).whenComplete(() {
      // 舊讀取不能清掉重建後仍在等待的共用讀取。
      if (!_stale(run)) _inflight = null;
    });
  }

  Future<TripRequest?> _fetchOnce(int run) async {
    try {
      final row = await ref
          .read(requestsRepositoryProvider)
          .fetchRequest(requestId);
      if (_stale(run)) return null;
      final current = state;
      if (current is RequestTerminal) {
        if (current.serverConfirmed &&
            current.status == row.status &&
            row.status.isTerminal &&
            (current.request != row ||
                current.terminalReason != row.terminalReason)) {
          state = RequestTerminal(
            status: current.status,
            terminalReason: row.terminalReason ?? current.terminalReason,
            serverConfirmed: current.serverConfirmed,
            authExpired: current.authExpired,
            errorMessage: current.errorMessage,
            request: row,
          );
        }
        return row;
      }
      if (row.status.isTerminal) {
        _terminate(row.status, row.terminalReason, request: row);
        return row;
      }
      state = RequestInFlight(request: row, status: row.status);
      return row;
    } on ApiError catch (error) {
      if (error.status == 401 && !_stale(run)) {
        _events?.cancel();
        _events = null;
        switch (state) {
          case RequestInFlight current:
            state = RequestInFlight(
              request: current.request,
              status: current.status,
              authExpired: true,
            );
          case RequestTerminal current:
            state = RequestTerminal(
              status: current.status,
              terminalReason: current.terminalReason,
              serverConfirmed: current.serverConfirmed,
              authExpired: true,
              errorMessage: current.errorMessage,
              request: current.request,
            );
        }
      }
      return null;
    } on Object {
      // 補讀失敗不推翻已知終態；進行中的暫時性錯誤則繼續等待。
      return null;
    }
  }

  void _watchEvents(int run) {
    if (_stale(run) || state is RequestTerminal || _authExpired) {
      return;
    }
    final Stream<TripRequestEvent> stream;
    try {
      stream = ref
          .read(requestsRepositoryProvider)
          .watchRequestEvents(requestId);
    } on Object {
      // SSE 開不起來不是失敗:改輪詢。
      unawaited(_fallbackToPolling(run));
      return;
    }
    _events = stream.listen(
      (event) {
        if (_stale(run) || state is RequestTerminal) return;
        if (!event.isTerminal) {
          if (event.status case final status?) {
            state = RequestInFlight(request: state.request, status: status);
          }
          return;
        }
        _terminate(
          event.status ?? RequestStatus.failed,
          event.error != null ? TerminalReason.error : null,
          errorMessage: event.error,
        );
        if (event.status == RequestStatus.failed && event.error == null) {
          unawaited(_completeTerminalReason(run));
        }
      },
      onError: (Object _) => _fallbackToPolling(run),
      onDone: () => _fallbackToPolling(run),
      cancelOnError: true,
    );
  }

  /// SSE 不帶原因。先共用既有讀取；若它回了終態前的舊進行中資料，
  /// 再於終態後補讀一次，不因讀取失敗或缺少原因而持續輪詢。
  Future<void> _completeTerminalReason(int run) async {
    if (_stale(run) || state is! RequestTerminal) return;
    final terminal = state;
    final hadPendingRead = _inflight != null;
    final row = await _readShared(run);
    if (_stale(run) ||
        !identical(state, terminal) ||
        !hadPendingRead ||
        row == null ||
        row.status.isTerminal) {
      return;
    }
    await _readShared(run);
  }

  /// 需要完整終態資料列的畫面可請求補讀。
  /// ponytail: 最多補讀三次，避免永久錯誤持續輪詢；若後端支援重送終態資料，再改為事件驅動補齊。
  Future<void> hydrateTerminal() async {
    if (_hydratingTerminal ||
        state is! RequestTerminal ||
        state.request?.status.isTerminal == true) {
      return;
    }
    _hydratingTerminal = true;
    final run = _run;
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        if (_stale(run) || state is! RequestTerminal) return;
        final row = await _readShared(run);
        if (_stale(run) ||
            (state as RequestTerminal).authExpired ||
            row?.status.isTerminal == true ||
            attempt == 2) {
          return;
        }
        await _wait(_pollDelay);
        if (_resumed case final paused?) await paused.future;
        _pollDelay = _pollDelay * 2 > kRequestPollCeiling
            ? kRequestPollCeiling
            : _pollDelay * 2;
      }
    } finally {
      if (!_stale(run)) _hydratingTerminal = false;
    }
  }

  /// SSE 收不到終結就改輪詢，等待由建構時注入的時鐘 adapter 決定。
  Future<void> _fallbackToPolling(int run) async {
    if (_polling || _stale(run) || state is RequestTerminal || _authExpired) {
      return;
    }
    _polling = true;
    try {
      while (!_stale(run) && state is! RequestTerminal && !_authExpired) {
        await _wait(_pollDelay);
        if (_resumed case final paused?) {
          // 回前景那一下已經補讀過,醒來直接回去等(間隔已重設)。
          await paused.future;
          continue;
        }
        if (await _refetch(run)) break;
        _pollDelay = _pollDelay * 2 > kRequestPollCeiling
            ? kRequestPollCeiling
            : _pollDelay * 2;
      }
    } finally {
      if (!_stale(run)) _polling = false;
    }
  }

  void _terminate(
    RequestStatus status,
    TerminalReason? reason, {
    bool serverConfirmed = true,
    String? errorMessage,
    TripRequest? request,
  }) {
    if (state is RequestTerminal) return; // 不改寫已確認的終態；原因另由補讀補齊。
    _events?.cancel();
    _events = null;
    state = RequestTerminal(
      status: status,
      terminalReason: reason,
      serverConfirmed: serverConfirmed,
      errorMessage: errorMessage,
      request: request ?? state.request,
    );
  }

  /// 停止等待 —— **不中止 AI**(後端 ADR-0007)。
  ///
  /// 標不掉也照樣本機終結,回傳 false 讓畫面誠實提示
  /// [kStopWaitingUnconfirmedMessage]。
  Future<bool> stopWaiting() async {
    final run = _run;
    var confirmed = true;
    try {
      await ref.read(requestsRepositoryProvider).stopWaiting(requestId);
    } on Object {
      confirmed = false;
    }
    // 等 PATCH 的期間伺服器可能已經先終結:保留伺服器那一份。
    if (_stale(run) || state is RequestTerminal) return true;
    _terminate(
      RequestStatus.failed,
      TerminalReason.cancelled,
      serverConfirmed: confirmed,
    );
    return confirmed;
  }
}

final requestLifecycleProvider = NotifierProvider.autoDispose
    .family<RequestLifecycle, RequestLifecycleState, int>(RequestLifecycle.new);
