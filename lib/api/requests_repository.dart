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

  /// PATCH /requests/:id —— 停止等待(後端 `raychiutw/trip-planner` 的 `docs/adr/0007-request-termination-cancel-and-reap.md`)。
  ///
  /// **這不會中止 AI。** 只把 request 標成終結、讓使用者脫身;處理端不受影響,
  /// 完成後的回報還是會寫進 `reply`,行程也可能已被更動。UI 文案必須誠實反映
  /// 這件事,不能講成「已中止」。
  Future<void> stopWaiting(int id) async {
    await _client.patch(
      '/requests/$id',
      body: {'status': 'failed', 'terminalReason': 'cancelled'},
    );
  }

  /// GET /requests/:id/events（SSE）→ status/progress events.
  ///
  /// 串流中途憑證到期、被撤銷或達 30 分鐘上限時，伺服器送 `event: reconnect`
  /// 後關閉；這裡帶 `Last-Event-ID` 與重簽的 proof 自動重連並接續，呼叫端看到的
  /// 仍是同一條連續的事件流。原生 EventSource 自動重連會重送舊的 proof，不可依賴。
  /// 連續 [_maxIdleReconnects] 次重連都沒有新事件就丟 [StateError]，不無限重連。
  Stream<TripRequestEvent> watchRequestEvents(int id) async* {
    String? lastEventId;
    var idleReconnects = 0;
    while (true) {
      var reconnect = false;
      var progressed = false;
      final frames = _parseSseFrames(
        _client.getTextStream(
          '/requests/$id/events',
          headers: {'Last-Event-ID': ?lastEventId},
        ),
      );
      await for (final frame in frames) {
        if (frame.id != null) lastEventId = frame.id;
        if (frame.event == _reconnectEvent) {
          reconnect = true;
          break;
        }
        final event = _tripRequestEventOf(frame);
        if (event == null) continue;
        progressed = true;
        yield event;
      }
      if (!reconnect) return;
      idleReconnects = progressed ? 0 : idleReconnects + 1;
      if (idleReconnects > _maxIdleReconnects) {
        throw StateError('SSE 重連後仍沒有新事件');
      }
    }
  }
}

const _reconnectEvent = 'reconnect';
const _maxIdleReconnects = 3;

class _SseFrame {
  const _SseFrame({this.id, this.event, required this.data});
  final String? id;
  final String? event;
  final String data;
}

Stream<TripRequestEvent> parseTripRequestEventStream(
  Stream<String> chunks,
) async* {
  await for (final frame in _parseSseFrames(chunks)) {
    if (frame.event == _reconnectEvent) continue;
    final event = _tripRequestEventOf(frame);
    if (event != null) yield event;
  }
}

Stream<_SseFrame> _parseSseFrames(Stream<String> chunks) async* {
  var buffer = '';
  await for (final chunk in chunks) {
    buffer = (buffer + chunk).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    while (true) {
      final boundary = buffer.indexOf('\n\n');
      if (boundary == -1) break;
      final frame = buffer.substring(0, boundary);
      buffer = buffer.substring(boundary + 2);
      final parsed = _parseSseFrame(frame);
      if (parsed != null) yield parsed;
    }
  }

  final trailing = buffer.trim();
  if (trailing.isNotEmpty) {
    final parsed = _parseSseFrame(trailing);
    if (parsed != null) yield parsed;
  }
}

_SseFrame? _parseSseFrame(String frame) {
  String? id;
  String? event;
  final dataLines = <String>[];
  for (final rawLine in frame.split('\n')) {
    final line = rawLine.trimRight();
    if (line.isEmpty || line.startsWith(':')) continue;
    final colon = line.indexOf(':');
    final field = colon == -1 ? line : line.substring(0, colon);
    var value = colon == -1 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'id':
        id = value;
      case 'event':
        event = value;
      case 'data':
        dataLines.add(value);
    }
  }
  if (dataLines.isEmpty && event == null) return null;
  return _SseFrame(id: id, event: event, data: dataLines.join('\n').trim());
}

TripRequestEvent? _tripRequestEventOf(_SseFrame frame) {
  if (frame.data.isEmpty) return null;
  final decoded = jsonDecode(frame.data);
  return TripRequestEvent.fromJson((decoded as Map).cast<String, dynamic>());
}
