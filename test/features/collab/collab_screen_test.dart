import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/collab/collab_screen.dart';
import 'package:tripline/models/collab.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

void main() {
  late _MockTripRepository repository;

  const trip = Trip(
    id: 'okinawa-trip-2026',
    name: 'okinawa-trip-2026',
    title: '沖繩家族旅行',
    published: true,
  );

  const permissions = [
    TripPermission(
      id: 1,
      email: 'owner@example.com',
      displayName: 'Ray',
      tripId: 'okinawa-trip-2026',
      role: 'owner',
    ),
    TripPermission(
      id: 2,
      email: 'friend@example.com',
      displayName: '旅伴',
      tripId: 'okinawa-trip-2026',
      role: 'member',
    ),
  ];

  const pending = PendingInvitationPage(
    items: [
      PendingInvitation(
        id: 'hash-1',
        invitedEmail: 'pending@example.com',
        createdAt: '2026-07-01T00:00:00Z',
        expiresAt: '2026-07-15T00:00:00Z',
        daysRemaining: 7,
        isExpired: false,
      ),
    ],
  );

  Widget buildApp() {
    return ProviderScope(
      overrides: [tripRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CollabScreen(tripId: 'okinawa-trip-2026'),
      ),
    );
  }

  setUp(() {
    repository = _MockTripRepository();
    when(
      () => repository.fetchTrip('okinawa-trip-2026'),
    ).thenAnswer((_) async => trip);
    when(
      () => repository.fetchTripPermissions('okinawa-trip-2026'),
    ).thenAnswer((_) async => permissions);
    when(
      () => repository.fetchPendingInvitations('okinawa-trip-2026'),
    ).thenAnswer((_) async => pending);
    when(
      () => repository.createTripPermissionInvite(
        tripId: any(named: 'tripId'),
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    ).thenAnswer(
      (_) async => const PermissionInviteResult(
        ok: true,
        status: 'invitation_sent',
        email: 'new@example.com',
        expiresAt: '2026-07-15T00:00:00Z',
      ),
    );
    when(
      () => repository.revokeTripInvitation(
        tripId: any(named: 'tripId'),
        email: any(named: 'email'),
      ),
    ).thenAnswer((_) async {});
  });

  testWidgets('載入成員與待邀請清單', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('共編設定'), findsOneWidget);
    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.text('Ray'), findsOneWidget);
    expect(find.text('擁有者'), findsOneWidget);
    expect(find.text('旅伴'), findsOneWidget);
    expect(find.text('共編成員'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(find.text('pending@example.com'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pending-row-pending@example.com')),
      findsOneWidget,
    );
  });

  testWidgets('新增邀請會送出 email、tripId 與角色', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('collab-add-email')),
      'new@example.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('collab-add-role-viewer')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('collab-add-submit')));
    await tester.tap(find.byKey(const ValueKey('collab-add-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repository.createTripPermissionInvite(
        tripId: 'okinawa-trip-2026',
        email: 'new@example.com',
        role: 'viewer',
      ),
    ).called(1);
    verify(
      () => repository.fetchPendingInvitations('okinawa-trip-2026'),
    ).called(greaterThanOrEqualTo(2));
  });

  testWidgets('撤回待邀請會呼叫 revoke API', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('pending-revoke-pending@example.com')),
    );
    await tester.pumpAndSettle();

    verify(
      () => repository.revokeTripInvitation(
        tripId: 'okinawa-trip-2026',
        email: 'pending@example.com',
      ),
    ).called(1);
  });
}
