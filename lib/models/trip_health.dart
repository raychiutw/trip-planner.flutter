/// AI 行程健檢 report model。
library;

enum TripHealthStatus { pending, completed, failed }

TripHealthStatus parseTripHealthStatus(String? value) =>
    switch (value?.toLowerCase()) {
      'completed' => TripHealthStatus.completed,
      'failed' => TripHealthStatus.failed,
      'pending' => TripHealthStatus.pending,
      _ => TripHealthStatus.pending,
    };

extension TripHealthStatusX on TripHealthStatus {
  bool get isTerminal =>
      this == TripHealthStatus.completed || this == TripHealthStatus.failed;
}

enum TripHealthSeverity { high, medium, low }

TripHealthSeverity parseTripHealthSeverity(String? value) =>
    switch (value?.toLowerCase()) {
      'high' => TripHealthSeverity.high,
      'low' => TripHealthSeverity.low,
      'medium' => TripHealthSeverity.medium,
      _ => TripHealthSeverity.medium,
    };

enum TripHealthDimension { timing, distance, meals, sights, hotel }

TripHealthDimension? parseTripHealthDimension(String? value) =>
    switch (value?.toLowerCase()) {
      'timing' => TripHealthDimension.timing,
      'distance' => TripHealthDimension.distance,
      'meals' => TripHealthDimension.meals,
      'sights' => TripHealthDimension.sights,
      'hotel' => TripHealthDimension.hotel,
      _ => null,
    };

class TripHealthActionTarget {
  const TripHealthActionTarget({this.day, this.entryId});

  final int? day;
  final int? entryId;

  static TripHealthActionTarget? fromJson(Object? value) {
    final map = _objectMap(value);
    if (map == null) return null;
    final day = _intOrNull(map['day']);
    final entryId = _intOrNull(map['entryId'] ?? map['entry_id']);
    if (day == null && entryId == null) return null;
    return TripHealthActionTarget(day: day, entryId: entryId);
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

  final TripHealthSeverity severity;
  final String title;
  final String description;
  final TripHealthDimension? dimension;
  final String? suggestion;
  final TripHealthActionTarget? actionTarget;

  factory TripHealthFinding.fromJson(Map<String, dynamic> json) =>
      TripHealthFinding(
        severity: parseTripHealthSeverity(json['severity']?.toString()),
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        dimension: parseTripHealthDimension(json['dimension']?.toString()),
        suggestion: _nullableString(json['suggestion']),
        actionTarget: TripHealthActionTarget.fromJson(
          json['actionTarget'] ?? json['action_target'],
        ),
      );
}

class TripHealthReport {
  const TripHealthReport({
    required this.tripId,
    required this.userId,
    required this.status,
    this.requestId,
    this.findings = const [],
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  final String tripId;
  final String userId;
  final TripHealthStatus status;
  final int? requestId;
  final List<TripHealthFinding> findings;
  final String? errorMessage;
  final String createdAt;
  final String? completedAt;

  factory TripHealthReport.fromJson(Map<String, dynamic> json) =>
      TripHealthReport(
        tripId: _stringValue(json['tripId'] ?? json['trip_id']),
        userId: _stringValue(json['userId'] ?? json['user_id']),
        status: parseTripHealthStatus(json['status']?.toString()),
        requestId: _intOrNull(json['requestId'] ?? json['request_id']),
        findings: _findings(json['findings']),
        errorMessage: _nullableString(
          json['errorMessage'] ?? json['error_message'],
        ),
        createdAt: _stringValue(json['createdAt'] ?? json['created_at']),
        completedAt: _nullableString(
          json['completedAt'] ?? json['completed_at'],
        ),
      );
}

List<TripHealthFinding> _findings(Object? value) {
  if (value is! List) return const [];
  final findings = <TripHealthFinding>[];
  for (final item in value) {
    final map = _objectMap(item);
    if (map != null) {
      findings.add(TripHealthFinding.fromJson(map));
    }
  }
  return findings;
}

Map<String, dynamic>? _objectMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _stringValue(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) {
  final stringValue = value?.toString();
  if (stringValue == null || stringValue.trim().isEmpty) return null;
  return stringValue;
}

int? _intOrNull(Object? value) => (value as num?)?.toInt();
