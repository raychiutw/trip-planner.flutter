import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/collab_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/trips/collab/collab_controller.dart';
import 'package:tripline/models/trip_member.dart';

class _MockCollabRepo extends Mock implements CollabRepository {}

const _members = [
  TripMember(id: 1, email: 'owner@x.com', role: 'owner', userId: 'u1'),
  TripMember(id: 2, email: 'v@x.com', role: 'viewer', userId: 'u2'),
];

Future<void> _flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _MockCollabRepo repo;

  setUp(() {
    repo = _MockCollabRepo();
    when(() => repo.fetchMembers(any())).thenAnswer((_) async => _members);
    when(() => repo.fetchInvites(any())).thenAnswer((_) async => const []);
  });

  ProviderContainer makeC() {
    final c = ProviderContainer(
      overrides: [collabRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<CollabController> loaded(ProviderContainer c) async {
    c.listen(collabControllerProvider('okinawa'), (_, _) {});
    final ctrl = c.read(collabControllerProvider('okinawa').notifier);
    await _flush();
    return ctrl;
  }

  test('載入成員 + 邀請', () async {
    final c = makeC();
    await loaded(c);
    final s = c.read(collabControllerProvider('okinawa'));
    expect(s.loading, isFalse);
    expect(s.canManage, isTrue);
    expect(s.members, hasLength(2));
  });

  test('非 owner（成員列表 403）→ canManage false', () async {
    when(() => repo.fetchMembers(any())).thenAnswer(
      (_) async => throw const ApiError(
        status: 403,
        code: 'PERM_ADMIN_ONLY',
        message: 'no',
      ),
    );
    final c = makeC();
    await loaded(c);
    final s = c.read(collabControllerProvider('okinawa'));
    expect(s.canManage, isFalse);
    expect(s.loading, isFalse);
  });

  test('invite → 呼叫 repo.invite + reload', () async {
    when(
      () => repo.invite(
        tripId: any(named: 'tripId'),
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async {});
    final c = makeC();
    final ctrl = await loaded(c);
    await ctrl.invite('b@x.com', 'viewer');
    verify(
      () => repo.invite(tripId: 'okinawa', email: 'b@x.com', role: 'viewer'),
    ).called(1);
    verify(() => repo.fetchMembers('okinawa')).called(2); // load + reload
  });

  test('invite 409 → actionError', () async {
    when(
      () => repo.invite(
        tripId: any(named: 'tripId'),
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    ).thenThrow(
      const ApiError(status: 409, code: 'DATA_CONFLICT', message: 'dup'),
    );
    final c = makeC();
    final ctrl = await loaded(c);
    await ctrl.invite('b@x.com', 'member');
    final s = c.read(collabControllerProvider('okinawa'));
    expect(s.actionError, isNotNull);
    expect(s.adding, isFalse);
  });

  test('changeRole → 呼叫 repo.changeRole', () async {
    when(() => repo.changeRole(any(), any())).thenAnswer((_) async {});
    final c = makeC();
    final ctrl = await loaded(c);
    await ctrl.changeRole(2, 'member');
    verify(() => repo.changeRole(2, 'member')).called(1);
    verify(() => repo.fetchMembers('okinawa')).called(2); // load + reload
  });

  test('removeMember → 呼叫 repo.removeMember', () async {
    when(() => repo.removeMember(any())).thenAnswer((_) async {});
    final c = makeC();
    final ctrl = await loaded(c);
    await ctrl.removeMember(2);
    verify(() => repo.removeMember(2)).called(1);
    verify(() => repo.fetchMembers('okinawa')).called(2); // load + reload
  });
}
