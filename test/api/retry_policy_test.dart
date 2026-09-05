import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/retry_policy.dart';

void main() {
  RetryDecision decide({
    int statusCode = 200,
    String? retryAfter,
    bool edgeBlock = false,
    bool useBearer = false,
    bool retryableMethod = true,
    bool isRetryAttempt = false,
  }) => decideRetry(
    statusCode: statusCode,
    retryAfterHeader: retryAfter,
    isEdgeBlockPage: edgeBlock,
    useBearer: useBearer,
    retryableMethod: retryableMethod,
    isRetryAttempt: isRetryAttempt,
  );

  test('429 GET → 依 Retry-After 等待後重送', () {
    final d = decide(statusCode: 429, retryAfter: '5');
    expect(d, isA<RetryAfterWait>());
    expect((d as RetryAfterWait).seconds, 5);
  });

  test('429 POST(mutation)→ 不重送', () {
    expect(decide(statusCode: 429, retryableMethod: false), isA<NoRetry>());
  });

  test('edge block page(2xx text/html)GET → 等待後重送;POST 不重送', () {
    expect(decide(edgeBlock: true), isA<RetryAfterWait>());
    expect(decide(edgeBlock: true, retryableMethod: false), isA<NoRetry>());
  });

  test('Bearer 401 → refresh 後重送,不分 method;cookie 模式 401 不重送', () {
    expect(
      decide(statusCode: 401, useBearer: true, retryableMethod: false),
      isA<RetryAfterRefresh>(),
    );
    expect(decide(statusCode: 401, useBearer: false), isA<NoRetry>());
  });

  test('已經是重送 → 一律不再重送', () {
    expect(decide(statusCode: 429, isRetryAttempt: true), isA<NoRetry>());
    expect(
      decide(statusCode: 401, useBearer: true, isRetryAttempt: true),
      isA<NoRetry>(),
    );
  });

  test('parseRetryAfterSeconds:delta、cap 30、無效值回 1', () {
    expect(parseRetryAfterSeconds('5'), 5);
    expect(parseRetryAfterSeconds('120'), 30);
    expect(parseRetryAfterSeconds('bogus'), 1);
    expect(parseRetryAfterSeconds(null), 1);
  });
}
