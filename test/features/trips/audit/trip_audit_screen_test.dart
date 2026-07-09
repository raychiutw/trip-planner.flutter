import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trips/audit/trip_audit_screen.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/trip_audit.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

void main() {
  late _MockTripRepository repository;

  const trip = Trip(id: 'trip-1', name: 'okinawa-trip', title: '沖繩家庭旅行');
  const rows = [
    TripAuditRow(
      id: 8,
      tripId: 'trip-1',
      tableName: 'trip_entries',
      recordId: 101,
      action: TripAuditAction.update,
      changedBy: 'ray@example.com',
      requestId: 43,
      diffJson: '{"title":{"old":"首里城","new":"首里城公園"}}',
      createdAt: '2026-07-09T10:00:00Z',
    ),
  ];

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [tripRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TripAuditScreen(tripId: 'trip-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _MockTripRepository();
    when(() => repository.fetchTrip('trip-1')).thenAnswer((_) async => trip);
    when(
      () => repository.fetchAuditLog(
        'trip-1',
        limit: any(named: 'limit'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => rows);
  });

  testWidgets('顯示 audit log 摘要與 diff 欄位', (tester) async {
    await pumpScreen(tester);

    expect(find.text('異動紀錄'), findsOneWidget);
    expect(find.text('沖繩家庭旅行'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-audit-row-8')), findsOneWidget);
    expect(find.text('更新'), findsOneWidget);
    expect(find.text('停留點'), findsOneWidget);
    expect(find.text('ray@example.com'), findsOneWidget);
    expect(find.textContaining('title'), findsOneWidget);
    expect(find.textContaining('首里城 → 首里城公園'), findsOneWidget);
  });

  testWidgets('回滾 audit row 需確認並呼叫 rollbackAudit', (tester) async {
    when(
      () => repository.rollbackAudit(
        tripId: any(named: 'tripId'),
        auditId: any(named: 'auditId'),
      ),
    ).thenAnswer(
      (_) async =>
          const TripAuditRollbackResult(ok: true, rolledBack: 'update->revert'),
    );
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('trip-audit-rollback-8')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '回滾'));
    await tester.pumpAndSettle();

    verify(
      () => repository.rollbackAudit(tripId: 'trip-1', auditId: 8),
    ).called(1);
    expect(find.text('已回滾異動'), findsOneWidget);
  });

  testWidgets('無 audit log 時顯示空狀態', (tester) async {
    when(
      () => repository.fetchAuditLog(
        'trip-1',
        limit: any(named: 'limit'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => const []);

    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('trip-audit-empty')), findsOneWidget);
    expect(find.text('尚無異動紀錄'), findsOneWidget);
  });
}
