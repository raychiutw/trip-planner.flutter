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
  });

  final int id;
  final String tripId;
  final String message;

  /// AI 回覆（markdown）;未完成為 null。
  final String? reply;
  final RequestStatus status;

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
  );
}
