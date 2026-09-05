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

/// SSE 收不到時的輪詢間隔。
const kRequestPollInterval = Duration(seconds: 4);

/// 輪詢用的等待;測試 override 成可手動放行的 Completer。
final requestPollWaitProvider = Provider<Future<void> Function()>(
  (_) =>
      () => Future<void>.delayed(kRequestPollInterval),
);

class RequestLifecycle extends Notifier<RequestLifecycleState> {
  RequestLifecycle(this.requestId);

  final int requestId;

  StreamSubscription<TripRequestEvent>? _events;
  AppLifecycleListener? _lifecycle;
  bool _disposed = false;
  bool _polling = false;

  @override
  RequestLifecycleState build() {
    // riverpod 3 重建(invalidate)時沿用同一個 Notifier 實例,旗標要歸零。
    _disposed = false;
    _polling = false;
    _events = null;
    ref.onDispose(() {
      _disposed = true;
      _events?.cancel();
      _lifecycle?.dispose();
    });
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_refetch()));
    // build 回傳前不能碰 state,所以排到下一個 microtask 再起跑。
    unawaited(Future<void>.microtask(_start));
    return const RequestInFlight();
  }

  Future<void> _start() async {
    if (await _refetch()) return;
    _watchEvents();
  }

  /// 讀一次 row;回 true = 已終結(state 已更新)。
  Future<bool> _refetch() async {
    if (_disposed || state is RequestTerminal) return true;
    try {
      final row = await ref
          .read(requestsRepositoryProvider)
          .fetchRequest(requestId);
      if (_disposed || state is RequestTerminal) return true;
      if (row.status.isTerminal) {
        _terminate(row.status, row.terminalReason, request: row);
        return true;
      }
      state = RequestInFlight(request: row);
      return false;
    } on Object {
      return _disposed; // 暫時性錯誤:當作還在跑
    }
  }

  void _watchEvents() {
    if (_disposed || state is RequestTerminal) return;
    final Stream<TripRequestEvent> stream;
    try {
      stream = ref
          .read(requestsRepositoryProvider)
          .watchRequestEvents(requestId);
    } on Object {
      // SSE 開不起來不是失敗:改輪詢。
      unawaited(_fallbackToPolling());
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
      onError: (Object _) => _fallbackToPolling(),
      onDone: _fallbackToPolling,
      cancelOnError: true,
    );
  }

  /// SSE 收不到終結就改輪詢;等待由 [requestPollWaitProvider] 決定。
  Future<void> _fallbackToPolling() async {
    if (_polling || _disposed || state is RequestTerminal) return;
    _polling = true;
    final wait = ref.read(requestPollWaitProvider);
    try {
      while (!_disposed && state is! RequestTerminal) {
        await wait();
        if (await _refetch()) break;
      }
    } finally {
      _polling = false;
    }
  }

  void _terminate(
    RequestStatus status,
    TerminalReason? reason, {
    bool serverConfirmed = true,
    TripRequest? request,
  }) {
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
    var confirmed = true;
    try {
      await ref.read(requestsRepositoryProvider).stopWaiting(requestId);
    } on Object {
      confirmed = false;
    }
    // 等 PATCH 的期間伺服器可能已經先終結:保留伺服器那一份。
    if (_disposed || state is RequestTerminal) return true;
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
