import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/invite/invite_screen.dart';
import 'package:tripline/models/collab.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._fixedUser);

  final UserInfo? _fixedUser;

  @override
  Future<UserInfo?> build() async => _fixedUser;
}

void main() {
  late _MockTripRepository repository;

  const preview = InvitationPreview(
    tripId: 'okinawa-trip-2026',
    tripTitle: '沖繩家族旅行',
    invitedEmail: 'friend@example.com',
    inviterDisplayName: 'Ray',
    inviterEmail: 'ray@example.com',
    expiresAt: '2026-07-15T00:00:00Z',
  );

  const invitedUser = UserInfo(
    id: 'user-1',
    email: 'friend@example.com',
    emailVerified: true,
    displayName: '旅伴',
  );

  const otherUser = UserInfo(
    id: 'user-2',
    email: 'other@example.com',
    emailVerified: true,
    displayName: '其他人',
  );

  Widget buildApp({required UserInfo? currentUser}) {
    final router = GoRouter(
      initialLocation: '/invite?token=invite-token',
      routes: [
        GoRoute(
          path: '/invite',
          builder: (context, state) =>
              InviteScreen(token: state.uri.queryParameters['token']),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Text('login-probe')),
        ),
        GoRoute(
          path: '/trips/:tripId',
          builder: (context, state) => Scaffold(
            body: Text('trip-probe-${state.pathParameters['tripId']}'),
          ),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repository),
        authStateProvider.overrideWith(() => _FakeAuthNotifier(currentUser)),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  setUp(() {
    repository = _MockTripRepository();
    when(
      () => repository.fetchInvitation('invite-token'),
    ).thenAnswer((_) async => preview);
    when(() => repository.acceptInvitation('invite-token')).thenAnswer(
      (_) async => const InvitationAcceptResult(
        ok: true,
        tripId: 'okinawa-trip-2026',
        tripTitle: '沖繩家族旅行',
      ),
    );
  });

  testWidgets('未登入可看邀請預覽並顯示登入 CTA', (tester) async {
    await tester.pumpWidget(buildApp(currentUser: null));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('invite-page')), findsOneWidget);
    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.text('friend@example.com'), findsOneWidget);
    expect(find.textContaining('Ray'), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-login-btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-accept-btn')), findsNothing);
  });

  testWidgets('登入且 email 相符時可接受邀請並進入行程', (tester) async {
    await tester.pumpWidget(buildApp(currentUser: invitedUser));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('invite-accept-btn')));
    await tester.pumpAndSettle();

    verify(() => repository.acceptInvitation('invite-token')).called(1);
    expect(find.text('trip-probe-okinawa-trip-2026'), findsOneWidget);
  });

  testWidgets('登入 email 不符時顯示明確錯誤', (tester) async {
    await tester.pumpWidget(buildApp(currentUser: otherUser));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('invite-mismatch')), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-accept-btn')), findsNothing);
  });
}
