import '../api/api_error.dart';

/// 全 App 共用的 provider 自動重試政策（`ProviderScope.retry`）。
///
/// Riverpod 3 預設重試 10 次、退避到 6.4 秒，重試期間畫面一直是載入中，
/// 失敗後約 90 秒才看得到錯誤與「重試」。這裡改成最多重試兩次（0.5 秒、1 秒），
/// 約 2 秒內就交給使用者原地重試；4xx 是確定的答案，不重試。
/// `ApiClient` 本身已有 429／edge block 的有限重送，不在這裡重複。
Duration? appProviderRetry(int retryCount, Object error) {
  if (retryCount >= 2) return null;
  if (error is ApiError && error.status >= 400 && error.status < 500) {
    return null;
  }
  return Duration(milliseconds: 500 * (1 << retryCount));
}
