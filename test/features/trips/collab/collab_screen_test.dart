import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/collab_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/trips/collab/collab_screen.dart';
import 'package:tripline/models/trip_member.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockCollabRepo extends Mock implements CollabRepository {}

const _members = [
  TripMember(id: 1, email: 'owner@x.com', role: 'owner', userId: 'u1'),
  TripMember(id: 2, email: 'v@x.com', role: 'viewer', userId: 'u2'),
];

void main() {
  late _MockCollabRepo repo;

  setUp(() {
    repo = _MockCollabRepo();
    when(() => repo.fetchMembers(any())).thenAnswer((_) async => _members);
    when(() => repo.fetchInvites(any())).thenAnswer((_) async => const []);
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [collabRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CollabScreen(tripId: 'okinawa'),
      ),
    );
  }

  testWidgets('owner → 顯示成員清單', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('owner@x.com'), findsOneWidget);
    expect(find.text('v@x.com'), findsOneWidget);
  });

  testWidgets('新增成員 → 輸入 email + 點新增 → invite', (tester) async {
    when(
      () => repo.invite(
        tripId: any(named: 'tripId'),
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('collab-email')),
      'b@x.com',
    );
    await tester.tap(find.byKey(const ValueKey('collab-add')));
    await tester.pumpAndSettle();

    verify(
      () => repo.invite(tripId: 'okinawa', email: 'b@x.com', role: 'member'),
    ).called(1);
  });

  testWidgets('非 owner（403）→ 提示', (tester) async {
    when(() => repo.fetchMembers(any())).thenAnswer(
      (_) async => throw const ApiError(
        status: 403,
        code: 'PERM_ADMIN_ONLY',
        message: 'no',
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('只有行程擁有者'), findsOneWidget);
    expect(find.byKey(const ValueKey('collab-add')), findsNothing);
  });
}
