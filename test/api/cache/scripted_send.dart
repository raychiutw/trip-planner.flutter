import 'package:dio/dio.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/cache/cache_read_policy.dart';
import 'package:tripline/api/cache/offline_sync_engine.dart';

/// 引擎測試的 send:依「METHOD path」路由、同一路由可序列回放(每次呼叫吐下一筆,
/// 最後一筆 sticky)。非 2xx 丟 [ApiError](與 ApiClient 一致),離線丟 DioException。
/// 取代原本要把整個 dio 假起來的 RoutingSequencedAdapter。
class ScriptedSend {
  final Map<String, List<Scripted>> _routes = {};
  final Map<String, int> callCounts = {};
  final List<SentRequest> recorded = [];

  void on(String method, String path, List<Scripted> script) {
    _routes['$method $path'] = script;
  }

  int countOf(String method, String path) => callCounts['$method $path'] ?? 0;

  Future<Object?> send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CacheReadPolicy policy = CacheReadPolicy.cached,
    bool evictMutationCache = true,
  }) async {
    recorded.add(
      SentRequest(method: method, path: path, data: body, query: query),
    );
    final key = '$method $path';
    final n = callCounts[key] ?? 0;
    callCounts[key] = n + 1;
    final script = _routes[key];
    if (script == null || script.isEmpty) {
      throw ApiError.fromResponse(404, {
        'error': {'code': 'TEST_NO_ROUTE', 'message': 'no route for $key'},
      });
    }
    final scripted = script[n.clamp(0, script.length - 1)];
    if (scripted.throwOffline) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionError,
      );
    }
    if (scripted.status < 200 || scripted.status >= 300) {
      throw ApiError.fromResponse(scripted.status, scripted.body);
    }
    return scripted.body;
  }

  OfflineSend get asSend => send;
}

class SentRequest {
  const SentRequest({
    required this.method,
    required this.path,
    this.data,
    this.query,
  });

  final String method;
  final String path;
  final Object? data;
  final Map<String, dynamic>? query;
}

class Scripted {
  const Scripted.json(this.status, this.body) : throwOffline = false;
  const Scripted.offline() : status = 0, body = null, throwOffline = true;
  final int status;
  final Object? body;
  final bool throwOffline;
}
