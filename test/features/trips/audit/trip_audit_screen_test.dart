import 'dart:async';

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

  Future<void> pumpScreen(
    WidgetTester tester, {
    String tripId = 'trip-1',
    ThemeData? theme,
    TextScaler textScaler = TextScaler.noScaling,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [tripRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: TripAuditScreen(
            key: const ValueKey('trip-audit-screen'),
            tripId: tripId,
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
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

  testWidgets('回滾失敗保留專屬 wording 並可重試', (tester) async {
    var attempts = 0;
    when(
      () => repository.rollbackAudit(
        tripId: any(named: 'tripId'),
        auditId: any(named: 'auditId'),
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw Exception('offline');
      return const TripAuditRollbackResult(
        ok: true,
        rolledBack: 'update->revert',
      );
    });
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('trip-audit-rollback-8')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '回滾'));
    await tester.pumpAndSettle();

    expect(find.text('回滾異動失敗，請稍後再試'), findsOneWidget);
    expect(find.textContaining('刪除失敗'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('trip-audit-error-retry')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '回滾'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
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

  testWidgets('載入錯誤持續顯示、live region 且可重試', (tester) async {
    var shouldFail = true;
    when(
      () => repository.fetchAuditLog(
        'trip-1',
        limit: any(named: 'limit'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async {
      if (shouldFail) throw Exception('offline');
      return rows;
    });

    await pumpScreen(tester);

    final error = tester.widget<Semantics>(
      find.byKey(const ValueKey('trip-audit-error')),
    );
    expect(error.properties.liveRegion, isTrue);
    expect(find.text('重試'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-audit-row-8')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-audit-error')), findsNothing);
  });

  testWidgets('regular dark 與最大文字仍限制內容寬度並保留 Header actions', (tester) async {
    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpScreen(
      tester,
      theme: AppTheme.dark(),
      textScaler: const TextScaler.linear(3),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('trip-audit-content'))).width,
      lessThanOrEqualTo(720),
    );
    expect(find.byKey(const ValueKey('trip-audit-refresh-button')), findsOne);
    expect(find.byKey(const ValueKey('account-avatar-button')), findsOne);
    expect(find.text('回滾'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切換 tripId 後忽略前一個行程較晚完成的載入', (tester) async {
    final oldTrip = Completer<Trip>();
    when(
      () => repository.fetchTrip('trip-1'),
    ).thenAnswer((_) => oldTrip.future);
    when(() => repository.fetchTrip('trip-2')).thenAnswer(
      (_) async => const Trip(id: 'trip-2', name: 'tokyo-trip', title: '東京旅行'),
    );
    when(
      () => repository.fetchAuditLog(
        'trip-2',
        limit: any(named: 'limit'),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => const []);

    await pumpScreen(tester, settle: false);
    await tester.pump();
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('trip-audit-loading-live')),
          )
          .properties
          .liveRegion,
      isTrue,
    );
    await pumpScreen(tester, tripId: 'trip-2');
    expect(find.text('東京旅行'), findsOneWidget);

    oldTrip.complete(trip);
    await tester.pumpAndSettle();

    expect(find.text('東京旅行'), findsOneWidget);
    expect(find.text('沖繩家庭旅行'), findsNothing);
  });
}
