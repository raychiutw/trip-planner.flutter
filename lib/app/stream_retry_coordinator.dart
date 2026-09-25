import 'dart:async';

/// 協調有限 SWR 串流讀取的重試；資料與錯誤仍由原本的串流擁有者處理。
class StreamRetryCoordinator {
  StreamRetryCoordinator(this._requestRefresh);

  final void Function() _requestRefresh;
  Completer<void>? _active;
  Completer<void>? _reserved;
  bool _disposed = false;

  /// 合併進行中的讀取，閒置時才預留下一次讀取並要求刷新。
  /// Future 在來源 error、done 或取消時完成；資料錯誤仍由原串流傳遞。
  /// 呼叫端須維持資料 consumer，讓刷新後的有限來源串流仍經 [track] 訂閱；
  /// 若沒有訂閱認領重試，Future 會等待到 [dispose]。
  Future<void> retry() {
    if (_disposed) return Future.value();
    if (_active case final active?) return active.future;
    final attempt = Completer<void>();
    _active = _reserved = attempt;
    try {
      _requestRefresh();
    } catch (_) {
      _finish(attempt);
      rethrow;
    }
    return attempt.future;
  }

  /// 每次訂閱才認領讀取；快取資料不代表背景網路請求已結束。
  Stream<T> track<T>(Stream<T> Function() createStream) =>
      Stream<T>.multi((sink) {
        if (_disposed) {
          sink.closeSync();
          return;
        }
        final attempt = _reserved ?? Completer<void>();
        _reserved = null;
        _active = attempt;
        try {
          final subscription = createStream().listen(
            sink.addSync,
            onError: (Object error, StackTrace stack) {
              _finish(attempt);
              sink.addErrorSync(error, stack);
            },
            onDone: () {
              _finish(attempt);
              sink.closeSync();
            },
          );
          sink.onPause = subscription.pause;
          sink.onResume = subscription.resume;
          sink.onCancel = () {
            _finish(attempt);
            return subscription.cancel();
          };
        } catch (error, stack) {
          _finish(attempt);
          sink.addErrorSync(error, stack);
          sink.closeSync();
        }
      });

  void _finish(Completer<void> attempt) {
    if (!attempt.isCompleted) attempt.complete();
    if (identical(_active, attempt)) _active = null;
    if (identical(_reserved, attempt)) _reserved = null;
  }

  /// 停止接受刷新並解除等待；不負責取消底層 HTTP 請求。
  void dispose() {
    _disposed = true;
    if (_active case final active?) _finish(active);
  }
}
