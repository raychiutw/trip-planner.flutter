/// AI 聊天工單（trip_requests）;一筆 = 一組 user/assistant 對話交換。
/// 非同步:送出建 row(open),外部 worker 處理後回填 reply + status。
library;

enum RequestStatus { open, processing, completed, failed }

RequestStatus parseRequestStatus(String? s) => switch (s) {
  'completed' => RequestStatus.completed,
  'failed' => RequestStatus.failed,
  'open' => RequestStatus.open,
  'processing' => RequestStatus.processing,
  _ => RequestStatus.processing, // unknown 續 poll,不誤判終止
};

/// 為什麼結束 —— 後端 ADR-0007 把「結束了沒」與「為什麼結束」拆成兩個欄位。
///
/// `status` 維持既有四值(後端刻意不改它的 CHECK constraint,那條路曾造成
/// prod 資料全失),這個是獨立的新欄位。**讀取端必須同時看兩個欄位。**
enum TerminalReason { cancelled, timedOut, error, needsConsent }

/// 未知值一律 null —— 不誤判成任何已知原因,寧可退回通用文案。
TerminalReason? parseTerminalReason(String? raw) => switch (raw) {
  'cancelled' => TerminalReason.cancelled,
  'timed_out' => TerminalReason.timedOut,
  'error' => TerminalReason.error,
  'needs_consent' => TerminalReason.needsConsent,
  _ => null,
};

extension RequestStatusX on RequestStatus {
  bool get isTerminal =>
      this == RequestStatus.completed || this == RequestStatus.failed;
}

class TripRequest {
  const TripRequest({
    required this.id,
    required this.tripId,
    required this.message,
    this.reply,
    required this.status,
    this.submittedBy,
    this.submittedByDisplayName,
    this.processedBy,
    this.createdAt,
    this.updatedAt,
    this.terminalReason,
  });

  final int id;
  final String tripId;
  final String message;

  /// AI 回覆（markdown）;未完成為 null。
  final String? reply;
  final RequestStatus status;

  /// 為什麼結束;未結束或後端沒帶就是 null。與 [status] 一起讀。
  final TerminalReason? terminalReason;

  /// 送出者 email。
  final String? submittedBy;
  final String? submittedByDisplayName;
  final String? processedBy;
  final String? createdAt;
  final String? updatedAt;

  factory TripRequest.fromJson(Map<String, dynamic> json) => TripRequest(
    id: (json['id'] as num).toInt(),
    tripId: json['tripId'] as String? ?? '',
    message: json['message'] as String? ?? '',
    reply: json['reply'] as String?,
    status: parseRequestStatus(json['status'] as String?),
    submittedBy: json['submittedBy'] as String?,
    submittedByDisplayName: json['submittedByDisplayName'] as String?,
    processedBy: json['processedBy'] as String?,
    createdAt: json['createdAt'] as String?,
    updatedAt: json['updatedAt'] as String?,
    terminalReason: parseTerminalReason(json['terminalReason'] as String?),
  );
}

/// SSE event from `GET /requests/:id/events`.
class TripRequestEvent {
  const TripRequestEvent({
    this.status,
    this.processedBy,
    this.updatedAt,
    this.error,
  });

  final RequestStatus? status;
  final String? processedBy;
  final String? updatedAt;
  final String? error;

  bool get isTerminal => error != null || status?.isTerminal == true;

  factory TripRequestEvent.fromJson(Map<String, dynamic> json) =>
      TripRequestEvent(
        status: json['status'] is String
            ? parseRequestStatus(json['status'] as String)
            : null,
        processedBy: json['processedBy'] as String?,
        updatedAt: json['updatedAt'] as String?,
        error: json['error'] as String?,
      );
}
