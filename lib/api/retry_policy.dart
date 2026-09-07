/// 「同參數重送一次」的決策 —— 純函式,四個站點共用:
/// 一般請求、SSE 文字串流、redirect 請求、登入／註冊的 raw response。
///
/// 規則(對應 ApiClient 行為規則 2):
/// - 429 與 edge block page(2xx 但 text/html)只有 GET / HEAD 重送,等 Retry-After(cap 30s)
/// - Bearer 模式 401 → refresh 成功才重送,**不分 method**
/// - 已經是重送 → 一律不再重送
library;

import 'dart:io';

sealed class RetryDecision {
  const RetryDecision();
}

final class NoRetry extends RetryDecision {
  const NoRetry();
}

/// 等 [seconds] 秒後同參數重送。
final class RetryAfterWait extends RetryDecision {
  const RetryAfterWait(this.seconds);

  final int seconds;
}

/// 先 refresh Bearer token;成功才重送。
final class RetryAfterRefresh extends RetryDecision {
  const RetryAfterRefresh();
}

RetryDecision decideRetry({
  required int statusCode,
  required String? retryAfterHeader,
  required bool isEdgeBlockPage,
  required bool useBearer,
  required bool retryableMethod,
  required bool isRetryAttempt,
}) {
  if (isRetryAttempt) return const NoRetry();
  if ((statusCode == 429 || isEdgeBlockPage) && retryableMethod) {
    return RetryAfterWait(parseRetryAfterSeconds(retryAfterHeader));
  }
  if (statusCode == 401 && useBearer) return const RetryAfterRefresh();
  return const NoRetry();
}

/// 解析 Retry-After(delta-seconds 或 HTTP-date),cap 30 秒;無效值回 1。
int parseRetryAfterSeconds(String? headerValue) {
  const maxWaitSeconds = 30;
  const defaultWaitSeconds = 1;
  final trimmedValue = headerValue?.trim();
  if (trimmedValue == null || trimmedValue.isEmpty) {
    return defaultWaitSeconds;
  }
  final deltaSeconds = int.tryParse(trimmedValue);
  if (deltaSeconds != null) {
    return deltaSeconds.clamp(0, maxWaitSeconds).toInt();
  }
  try {
    final retryAt = HttpDate.parse(trimmedValue);
    final secondsUntilRetry = retryAt.difference(DateTime.now()).inSeconds;
    return secondsUntilRetry.clamp(0, maxWaitSeconds).toInt();
  } on Exception {
    return defaultWaitSeconds;
  }
}
