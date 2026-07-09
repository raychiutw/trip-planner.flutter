import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/trip_audit.dart';

void main() {
  group('TripAuditRow.fromJson', () {
    test('解析 audit_log snake_case row 與 JSON 字串欄位', () {
      final row = TripAuditRow.fromJson({
        'id': 12,
        'trip_id': 'okinawa',
        'table_name': 'trip_days',
        'record_id': 34,
        'action': 'update',
        'changed_by': 'ray@example.com',
        'request_id': 56,
        'diff_json': '{"title":{"old":"A","new":"B"}}',
        'snapshot': '{"id":34,"title":"A"}',
        'companion_failure_reason': null,
        'created_at': '2026-07-09T10:00:00Z',
      });

      expect(row.id, 12);
      expect(row.tripId, 'okinawa');
      expect(row.tableName, 'trip_days');
      expect(row.recordId, 34);
      expect(row.action, TripAuditAction.update);
      expect(row.changedBy, 'ray@example.com');
      expect(row.requestId, 56);
      expect(row.diff?['title'], {'old': 'A', 'new': 'B'});
      expect(row.snapshotRow?['id'], 34);
      expect(row.createdAt, '2026-07-09T10:00:00Z');
    });

    test('接受 camelCase 欄位並保留 unknown action', () {
      final row = TripAuditRow.fromJson({
        'id': '13',
        'tripId': 'tokyo',
        'tableName': 'trip_entries',
        'recordId': null,
        'action': 'archive',
        'changedBy': '',
        'requestId': '57',
        'diffJson': null,
        'createdAt': '2026-07-09T11:00:00Z',
      });

      expect(row.id, 13);
      expect(row.action, TripAuditAction.unknown);
      expect(row.action.apiValue, 'unknown');
      expect(row.changedBy, isNull);
      expect(row.requestId, 57);
      expect(row.diff, isNull);
    });
  });

  group('TripAuditRollbackResult.fromJson', () {
    test('解析 rollback result snake_case', () {
      final result = TripAuditRollbackResult.fromJson({
        'ok': true,
        'rolled_back': 'update->revert',
      });

      expect(result.ok, isTrue);
      expect(result.rolledBack, 'update->revert');
    });
  });

  group('parseTripAuditAction', () {
    test('支援 known actions 與 fallback', () {
      expect(parseTripAuditAction('insert'), TripAuditAction.insert);
      expect(parseTripAuditAction('UPDATE'), TripAuditAction.update);
      expect(parseTripAuditAction('delete'), TripAuditAction.delete);
      expect(parseTripAuditAction('error'), TripAuditAction.error);
      expect(parseTripAuditAction('other'), TripAuditAction.unknown);
    });
  });
}
