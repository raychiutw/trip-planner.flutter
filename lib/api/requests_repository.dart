/// AI 聊天工單 repository（`/api/requests*`）。獨立於 TripRepository。
library;

import 'dart:convert';

import '../models/trip_request.dart';
import 'api_client.dart';

class RequestsRepository {
  RequestsRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /requests（永遠帶 limit → 後端回 `{items,hasMore}` 物件形,避開裸陣列）。
  /// cursor 往更舊:before=<最舊 createdAt> + beforeId=<最舊 id>。
  Future<({List<TripRequest> items, bool hasMore})> fetchRequests({
    required String tripId,
    int limit = 20,
    String sort = 'desc',
    String? before,
    int? beforeId,
  }) async {
    final body = await _client.get(
      '/requests',
      query: {
        'tripId': tripId,
        'limit': '$limit',
        'sort': sort,
        'before': ?before,
        'beforeId': ?beforeId?.toString(),
      },
    );
    final map = body as Map<String, dynamic>;
    final items = (map['items'] as List<dynamic>? ?? [])
        .map((e) => TripRequest.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, hasMore: map['hasMore'] == true);
  }

  /// POST /requests（body camelCase）→ 201 新 row（或 30s 去重回 200 既有 row）。
  Future<TripRequest> sendRequest({
    required String tripId,
    required String message,
  }) async {
    final body = await _client.post(
      '/requests',
      body: {'tripId': tripId, 'message': message},
    );
    return TripRequest.fromJson(body as Map<String, dynamic>);
  }

  /// GET /requests/:id（polling 用）。
  Future<TripRequest> fetchRequest(int id) async {
    final body = await _client.get('/requests/$id');
    return TripRequest.fromJson(body as Map<String, dynamic>);
  }

  /// PATCH /requests/:id —— 停止等待(後端 ADR-0007)。
  ///
  /// **這不會中止 AI。** 只把 request 標成終結、讓使用者脫身;mac mini 上的
  /// worker 照跑,完成後的回報還是會寫進 `reply`,行程也可能已被更動。UI 文案
  /// 必須誠實反映這件事,不能講成「已中止」。
  Future<void> stopWaiting(int id) async {
    await _client.patch(
      '/requests/$id',
      body: {'status': 'failed', 'terminalReason': 'cancelled'},
    );
  }

  /// GET /requests/:id/events（SSE）→ status/progress events.
  Stream<TripRequestEvent> watchRequestEvents(int id) =>
      parseTripRequestEventStream(
        _client.getTextStream('/requests/$id/events'),
      );
}

Stream<TripRequestEvent> parseTripRequestEventStream(
  Stream<String> chunks,
) async* {
  var buffer = '';
  await for (final chunk in chunks) {
    buffer = (buffer + chunk).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    while (true) {
      final boundary = buffer.indexOf('\n\n');
      if (boundary == -1) break;
      final frame = buffer.substring(0, boundary);
      buffer = buffer.substring(boundary + 2);
      final event = _parseTripRequestEventFrame(frame);
      if (event != null) yield event;
    }
  }

  final trailing = buffer.trim();
  if (trailing.isNotEmpty) {
    final event = _parseTripRequestEventFrame(trailing);
    if (event != null) yield event;
  }
}

TripRequestEvent? _parseTripRequestEventFrame(String frame) {
  final dataLines = <String>[];
  for (final rawLine in frame.split('\n')) {
    final line = rawLine.trimRight();
    if (line.isEmpty || line.startsWith(':')) continue;
    if (!line.startsWith('data:')) continue;
    var data = line.substring(5);
    if (data.startsWith(' ')) data = data.substring(1);
    dataLines.add(data);
  }

  if (dataLines.isEmpty) return null;
  final payload = dataLines.join('\n').trim();
  if (payload.isEmpty) return null;
  final decoded = jsonDecode(payload);
  return TripRequestEvent.fromJson((decoded as Map).cast<String, dynamic>());
}
