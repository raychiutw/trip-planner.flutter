/// AI 行程健檢 models（wire format 為 camelCase）。
library;

const List<String> kTripHealthSeverityOrder = ['high', 'medium', 'low'];

class TripHealthActionTarget {
  const TripHealthActionTarget({this.day, this.entryId});

  final int? day;
  final int? entryId;

  factory TripHealthActionTarget.fromJson(Map<String, dynamic> json) {
    return TripHealthActionTarget(
      day: (json['day'] as num?)?.toInt(),
      entryId:
          (json['entryId'] as num?)?.toInt() ??
          (json['entry_id'] as num?)?.toInt(),
    );
  }
}

class TripHealthFinding {
  const TripHealthFinding({
    required this.severity,
    required this.title,
    required this.description,
    this.dimension,
    this.suggestion,
    this.actionTarget,
  });

  final String severity;
  final String title;
  final String description;
  final String? dimension;
  final String? suggestion;
  final TripHealthActionTarget? actionTarget;

  String get severityLabel => switch (severity) {
    'high' => '高',
    'medium' => '中',
    'low' => '低',
    _ => severity,
  };

  String get severityHeading => switch (severity) {
    'high' => '高優先',
    'medium' => '中等',
    'low' => '低',
    _ => severity,
  };

  String get dimensionLabel => switch (dimension) {
    'timing' => '時間',
    'distance' => '移動',
    'meals' => '餐飲',
    'sights' => '景點',
    'hotel' => '住宿',
    _ => dimension ?? '',
  };

  factory TripHealthFinding.fromJson(Map<String, dynamic> json) {
    final actionTargetJson = json['actionTarget'] ?? json['action_target'];
    return TripHealthFinding(
      severity: json['severity'] as String? ?? 'low',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dimension: json['dimension'] as String?,
      suggestion: json['suggestion'] as String?,
      actionTarget: actionTargetJson is Map<String, dynamic>
          ? TripHealthActionTarget.fromJson(actionTargetJson)
          : null,
    );
  }
}

class TripHealthReport {
  const TripHealthReport({
    required this.tripId,
    required this.userId,
    required this.status,
    required this.requestId,
    required this.findings,
    required this.createdAt,
    this.errorMessage,
    this.completedAt,
  });

  final String tripId;
  final String userId;
  final String status;
  final int? requestId;
  final List<TripHealthFinding> findings;
  final String? errorMessage;
  final String createdAt;
  final String? completedAt;

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  int severityCount(String severity) {
    return findings.where((finding) => finding.severity == severity).length;
  }

  List<TripHealthFinding> findingsForSeverity(String severity) {
    return findings
        .where((finding) => finding.severity == severity)
        .toList(growable: false);
  }

  factory TripHealthReport.fromJson(Map<String, dynamic> json) {
    return TripHealthReport(
      tripId: json['tripId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      requestId: (json['requestId'] as num?)?.toInt(),
      findings: (json['findings'] as List<dynamic>? ?? const [])
          .map(
            (findingJson) =>
                TripHealthFinding.fromJson(findingJson as Map<String, dynamic>),
          )
          .toList(),
      errorMessage: json['errorMessage'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      completedAt: json['completedAt'] as String?,
    );
  }
}
