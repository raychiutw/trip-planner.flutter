import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/collab_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/invite/invite_controller.dart';
import 'package:tripline/models/trip_member.dart';
import 'package:tripline/models/user.dart';

class _MockCollabRepo extends Mock implements CollabRepository {}

const _invitation = InvitationDetails(
  tripId: 'trip-1',
  tripTitle: '沖繩家庭旅行',
  invitedEmail: 'traveler@example.com',
  inviterDisplayName: 'Ray',
  inviterEmail: 'ray@example.com',
  expiresAt: '2026-07-16T00:00:00.000Z',
);

const _traveler = UserInfo(
  id: 'u1',
  email: 'traveler@example.com',
  emailVerified: true,
);

const _otherUser = UserInfo(
  id: 'u2',
  email: 'other@example.com',
  emailVerified: true,
);

Future<void> _flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _MockCollabRepo repo;

  setUp(() {
    repo = _MockCollabRepo();
    when(
      () => repo.fetchInvitation(any()),
    ).thenAnswer((_) async => _invitation);
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [collabRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  InviteController controllerOf(ProviderContainer c, String token) {
    c.listen(inviteControllerProvider(token), (_, _) {});
    return c.read(inviteControllerProvider(token).notifier);
  }

  test('build：token 有值時載入邀請詳情', () async {
    final c = makeContainer();
    controllerOf(c, ' raw-token ');
    await _flush();

    final state = c.read(inviteControllerProvider(' raw-token '));
    expect(state.loading, isFalse);
    expect(state.invitation?.tripId, 'trip-1');
    expect(state.error, isNull);
    verify(() => repo.fetchInvitation('raw-token')).called(1);
  });

  test('build：token 空值不打 API 並顯示缺 token', () async {
    final c = makeContainer();
    controllerOf(c, '   ');
    await _flush();

    final state = c.read(inviteControllerProvider('   '));
    expect(state.loading, isFalse);
    expect(state.error, '邀請連結無效（缺少 token）');
    verifyNever(() => repo.fetchInvitation(any()));
  });

  test('accountStatusFor：登入狀態與 email mismatch 判斷', () async {
    final state = const InviteState(loading: false, invitation: _invitation);

    expect(
      state.accountStatusFor(null, authLoading: true),
      InviteAccountStatus.checking,
    );
    expect(
      state.accountStatusFor(null, authLoading: false),
      InviteAccountStatus.anonymous,
    );
    expect(
      state.accountStatusFor(_traveler, authLoading: false),
      InviteAccountStatus.matching,
    );
    expect(
      state.accountStatusFor(_otherUser, authLoading: false),
      InviteAccountStatus.mismatch,
    );
  });

  test('accept：呼叫 acceptInvitation 並記錄接受結果', () async {
    when(() => repo.acceptInvitation(any())).thenAnswer(
      (_) async =>
          const InvitationAcceptResult(tripId: 'trip-1', tripTitle: '沖繩家庭旅行'),
    );
    final c = makeContainer();
    final ctrl = controllerOf(c, 'raw-token');
    await _flush();

    final result = await ctrl.accept();

    expect(result?.tripId, 'trip-1');
    final state = c.read(inviteControllerProvider('raw-token'));
    expect(state.accepting, isFalse);
    expect(state.acceptError, isNull);
    expect(state.acceptedTripId, 'trip-1');
    verify(() => repo.acceptInvitation('raw-token')).called(1);
  });

  test('accept：API error 轉成持續錯誤狀態', () async {
    when(() => repo.acceptInvitation(any())).thenThrow(
      const ApiError(
        status: 409,
        code: 'INVITATION_ACCEPTED',
        message: 'accepted',
      ),
    );
    final c = makeContainer();
    final ctrl = controllerOf(c, 'raw-token');
    await _flush();

    final result = await ctrl.accept();

    expect(result, isNull);
    final state = c.read(inviteControllerProvider('raw-token'));
    expect(state.accepting, isFalse);
    expect(state.acceptError, '此邀請已被接受，請回到行程清單確認。');
  });
}
