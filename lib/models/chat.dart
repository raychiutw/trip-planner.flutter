/// AI request queue models（wire format 為 camelCase）。
library;

class TripRequest {
  const TripRequest({
    required this.id,
    required this.tripId,
    required this.message,
    this.reply,
    this.status = 'open',
    this.submittedBy,
    this.submittedByDisplayName,
    this.processedBy,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String tripId;
  final String message;
  final String? reply;
  final String status;
  final String? submittedBy;
  final String? submittedByDisplayName;
  final String? processedBy;
  final String? createdAt;
  final String? updatedAt;

  bool get isInflight => status == 'open' || status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  String? get displayReply {
    final trimmed = reply?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  factory TripRequest.fromJson(Map<String, dynamic> json) {
    return TripRequest(
      id: (json['id'] as num).toInt(),
      tripId: json['tripId'] as String,
      message: json['message'] as String? ?? '',
      reply: json['reply'] as String?,
      status: json['status'] as String? ?? 'open',
      submittedBy: json['submittedBy'] as String?,
      submittedByDisplayName: json['submittedByDisplayName'] as String?,
      processedBy: json['processedBy'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class TripRequestPage {
  const TripRequestPage({required this.items, required this.hasMore});

  final List<TripRequest> items;
  final bool hasMore;

  factory TripRequestPage.fromJson(Map<String, dynamic> json) {
    return TripRequestPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (itemJson) =>
                TripRequest.fromJson(itemJson as Map<String, dynamic>),
          )
          .toList(),
      hasMore: json['hasMore'] == true,
    );
  }
}
