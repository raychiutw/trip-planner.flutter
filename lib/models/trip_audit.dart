/// Trip audit log model.
library;

import 'dart:convert';

enum TripAuditAction { insert, update, delete, error, unknown }

TripAuditAction parseTripAuditAction(String? value) =>
    switch (value?.toLowerCase()) {
      'insert' => TripAuditAction.insert,
      'update' => TripAuditAction.update,
      'delete' => TripAuditAction.delete,
      'error' => TripAuditAction.error,
      _ => TripAuditAction.unknown,
    };

extension TripAuditActionX on TripAuditAction {
  String get apiValue => switch (this) {
    TripAuditAction.insert => 'insert',
    TripAuditAction.update => 'update',
    TripAuditAction.delete => 'delete',
    TripAuditAction.error => 'error',
    TripAuditAction.unknown => 'unknown',
  };
}

class TripAuditRow {
  const TripAuditRow({
    required this.id,
    required this.tripId,
    required this.tableName,
    required this.action,
    required this.createdAt,
    this.recordId,
    this.changedBy,
    this.requestId,
    this.diffJson,
    this.snapshot,
    this.companionFailureReason,
  });

  final int id;
  final String tripId;
  final String tableName;
  final int? recordId;
  final TripAuditAction action;
  final String? changedBy;
  final int? requestId;
  final String? diffJson;
  final String? snapshot;
  final String? companionFailureReason;
  final String createdAt;

  factory TripAuditRow.fromJson(Map<String, dynamic> json) => TripAuditRow(
    id: _intValue(json['id']),
    tripId: _stringValue(json['tripId'] ?? json['trip_id']),
    tableName: _stringValue(json['tableName'] ?? json['table_name']),
    recordId: _intOrNull(json['recordId'] ?? json['record_id']),
    action: parseTripAuditAction(json['action']?.toString()),
    changedBy: _nullableString(json['changedBy'] ?? json['changed_by']),
    requestId: _intOrNull(json['requestId'] ?? json['request_id']),
    diffJson: _nullableString(json['diffJson'] ?? json['diff_json']),
    snapshot: _nullableString(json['snapshot']),
    companionFailureReason: _nullableString(
      json['companionFailureReason'] ?? json['companion_failure_reason'],
    ),
    createdAt: _stringValue(json['createdAt'] ?? json['created_at']),
  );

  Map<String, dynamic>? get diff => _decodeObject(diffJson);

  Map<String, dynamic>? get snapshotRow => _decodeObject(snapshot);
}

Map<String, dynamic>? _decodeObject(String? jsonText) {
  if (jsonText == null) return null;
  final decoded = jsonDecode(jsonText);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return null;
}

String _stringValue(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) {
  final stringValue = value?.toString();
  if (stringValue == null || stringValue.trim().isEmpty) return null;
  return stringValue;
}

int _intValue(Object? value) => _intOrNull(value) ?? 0;

int? _intOrNull(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
