/// 工單 lifecycle —— 「送出後等到終結」這件事的唯一擁有者。
///
/// 畫面只看 [RequestLifecycleState] 與呼叫 [RequestLifecycle.stopWaiting];
/// transport(SSE 或輪詢)、回前景重讀、本機先終結,都在這裡決定。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/providers.dart';
import '../../models/trip_request.dart';

/// 停止等待但伺服器沒有確認時的提示。畫面遷移到 lifecycle 後一律用這一份
/// (健檢已遷;聊天與筆記在 #274 / #275 遷移時把自己那份換掉)。
const kStopWaitingUnconfirmedMessage = '已停止等待，但伺服器沒有確認。它可能仍在處理。';

sealed class RequestLifecycleState {
  const RequestLifecycleState({this.request});

  /// 最近一次從伺服器讀回的 row;SSE 事件不帶完整 row,所以可能是舊的。
  final TripRequest? request;
}

/// 還在等(open / processing)。
final class RequestInFlight extends RequestLifecycleState {
  const RequestInFlight({super.request});
}

/// 已終結。[serverConfirmed] 為 false 表示是本機先終結(停止等待沒送到)。
final class RequestTerminal extends RequestLifecycleState {
  const RequestTerminal({
    required this.status,
    this.terminalReason,
    this.serverConfirmed = true,
    super.request,
  });

  final RequestStatus status;
  final TerminalReason? terminalReason;
  final bool serverConfirmed;
}

/// SSE 收不到時的輪詢起始間隔;每輪加倍到 [kRequestPollCeiling] 封頂,
/// 回前景重設。
const kRequestPollInterval = Duration(seconds: 4);
const kRequestPollCeiling = Duration(seconds: 30);

/// 輪詢用的等待;測試 override 成可手動放行的 Completer 並記下間隔。
final requestPollWaitProvider = Provider<Future<void> Function(Duration)>(
  (_) => Future<void>.delayed,
);

class RequestLifecycle extends Notifier<RequestLifecycleState> {
  RequestLifecycle(this.requestId);

  final int requestId;

  StreamSubscription<TripRequestEvent>? _events;
  AppLifecycleListener? _lifecycle;

  /// riverpod 3 重建(invalidate)時沿用同一個 Notifier 實例。每次 build 換一個
  /// run token,還在 await 的舊 continuation 醒來看 token 不同就作廢,
  /// 不會出現兩條輪詢迴圈或舊 row 蓋到新 state。dispose 也算換 token。
  int _run = 0;
  bool _polling = false;

  /// 同一時間只有一個 fetch 在飛:輪詢與回前景撞在一起就共用它。
  Future<bool>? _inflight;

  /// app 在背景:輪詢停在這個 Completer 上,回前景才放行。
  Completer<void>? _resumed;
  Duration _pollDelay = kRequestPollInterval;

  bool _stale(int run) => run != _run;

  @override
  RequestLifecycleState build() {
    final run = ++_run;
    _polling = false;
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
  Future<bool> _refetch(int run) {
    if (_stale(run) || state is RequestTerminal) return Future.value(true);
    return _inflight ??= _fetchOnce(run).whenComplete(() => _inflight = null);
  }

  Future<bool> _fetchOnce(int run) async {
    try {
      final row = await ref
          .read(requestsRepositoryProvider)
          .fetchRequest(requestId);
      if (_stale(run) || state is RequestTerminal) return true;
      if (row.status.isTerminal) {
        _terminate(row.status, row.terminalReason, request: row);
        return true;
      }
      state = RequestInFlight(request: row);
      return false;
    } on Object {
      return _stale(run); // 暫時性錯誤:當作還在跑
    }
  }

  void _watchEvents(int run) {
    if (_stale(run) || state is RequestTerminal) return;
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
        if (!event.isTerminal) return;
        _terminate(
          event.status ?? RequestStatus.failed,
          event.error != null ? TerminalReason.error : null,
        );
      },
      onError: (Object _) => _fallbackToPolling(run),
      onDone: () => _fallbackToPolling(run),
      cancelOnError: true,
    );
  }

  /// SSE 收不到終結就改輪詢;等待由 [requestPollWaitProvider] 決定。
  Future<void> _fallbackToPolling(int run) async {
    if (_polling || _stale(run) || state is RequestTerminal) return;
    _polling = true;
    final wait = ref.read(requestPollWaitProvider);
    try {
      while (!_stale(run) && state is! RequestTerminal) {
        await wait(_pollDelay);
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
    TripRequest? request,
  }) {
    if (state is RequestTerminal) return; // 終結態只寫一次,遲到的事件不覆蓋
    _events?.cancel();
    _events = null;
    state = RequestTerminal(
      status: status,
      terminalReason: reason,
      serverConfirmed: serverConfirmed,
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
