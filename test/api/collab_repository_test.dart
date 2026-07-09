import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/collab_repository.dart';
import 'package:tripline/api/session_store.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late CollabRepository repo;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    repo = CollabRepository(
      client: ApiClient(sessionStore: InMemorySessionStore(), dio: dio),
    );
  });

  test('fetchMembers：GET /permissions 裸陣列 → TripMember', () async {
    dioAdapter.onGet(
      '/permissions',
      (server) => server.reply(200, [
        {
          'id': 1,
          'email': 'owner@x.com',
          'displayName': 'Owner',
          'role': 'owner',
          'userId': 'u1',
        },
        {'id': 2, 'email': 'v@x.com', 'role': 'viewer', 'userId': 'u2'},
      ]),
      queryParameters: {'tripId': 'okinawa'},
    );

    final members = await repo.fetchMembers('okinawa');
    expect(members, hasLength(2));
    expect(members.first.role, 'owner');
    expect(members.first.isManageable, isFalse);
    expect(members[1].isManageable, isTrue);
  });

  test('fetchInvites：GET /invitations {items} → TripInvite', () async {
    dioAdapter.onGet(
      '/invitations',
      (server) => server.reply(200, {
        'items': [
          {
            'id': 'tok_hash',
            'invitedEmail': 'b@x.com',
            'daysRemaining': 5,
            'isExpired': false,
          },
        ],
      }),
      queryParameters: {'tripId': 'okinawa'},
    );

    final invites = await repo.fetchInvites('okinawa');
    expect(invites.single.invitedEmail, 'b@x.com');
    expect(invites.single.daysRemaining, 5);
    expect(invites.single.isExpired, isFalse);
  });

  test('fetchInvitation：GET /invitations?token= → InvitationDetails', () async {
    dioAdapter.onGet(
      '/invitations',
      (server) => server.reply(200, {
        'tripId': 'trip-1',
        'tripTitle': '沖繩家庭旅行',
        'invitedEmail': 'traveler@example.com',
        'inviterDisplayName': 'Ray',
        'inviterEmail': 'ray@example.com',
        'expiresAt': '2026-07-16T00:00:00.000Z',
      }),
      queryParameters: {'token': 'raw-token'},
    );

    final invitation = await repo.fetchInvitation('raw-token');

    expect(invitation.tripId, 'trip-1');
    expect(invitation.tripTitle, '沖繩家庭旅行');
    expect(invitation.invitedEmail, 'traveler@example.com');
    expect(invitation.inviterDisplayName, 'Ray');
    expect(invitation.inviterEmail, 'ray@example.com');
    expect(invitation.expiresAt, '2026-07-16T00:00:00.000Z');
  });

  test('fetchInvitation：不快取含 token 的公開預覽回應', () async {
    final cache = InMemoryCacheStore();
    repo = CollabRepository(
      client: ApiClient(
        sessionStore: InMemorySessionStore(),
        dio: dio,
        cacheStore: cache,
      ),
    );
    dioAdapter.onGet(
      '/invitations',
      (server) => server.reply(200, {
        'tripId': 'trip-1',
        'tripTitle': '沖繩家庭旅行',
        'invitedEmail': 'traveler@example.com',
        'inviterDisplayName': 'Ray',
        'inviterEmail': 'ray@example.com',
        'expiresAt': '2026-07-16T00:00:00.000Z',
      }),
      queryParameters: {'token': 'raw-token'},
    );

    await repo.fetchInvitation('raw-token');

    expect(
      await cache.readResponse(
        cacheKeyFor('GET', '/invitations', {'token': 'raw-token'}),
      ),
      isNull,
    );
  });

  test('invite：POST /permissions camelCase {email,tripId,role}', () async {
    dioAdapter.onPost(
      '/permissions',
      (server) => server.reply(201, {'ok': true, 'status': 'invitation_sent'}),
      data: {'email': 'b@x.com', 'tripId': 'okinawa', 'role': 'viewer'},
    );
    await expectLater(
      repo.invite(tripId: 'okinawa', email: 'b@x.com', role: 'viewer'),
      completes,
    );
  });

  test(
    'acceptInvitation：POST /invitations/accept {token} → trip summary',
    () async {
      dioAdapter.onPost(
        '/invitations/accept',
        (server) => server.reply(200, {
          'ok': true,
          'tripId': 'trip-1',
          'tripTitle': '沖繩家庭旅行',
        }),
        data: {'token': 'raw-token'},
      );

      final result = await repo.acceptInvitation('raw-token');

      expect(result.tripId, 'trip-1');
      expect(result.tripTitle, '沖繩家庭旅行');
    },
  );

  test('changeRole：PATCH /permissions/:id {role}', () async {
    dioAdapter.onPatch(
      '/permissions/12',
      (server) => server.reply(200, {'ok': true, 'role': 'viewer'}),
      data: {'role': 'viewer'},
    );
    await expectLater(repo.changeRole(12, 'viewer'), completes);
  });

  test('removeMember：DELETE /permissions/:id', () async {
    dioAdapter.onDelete(
      '/permissions/12',
      (server) => server.reply(200, {'ok': true}),
    );
    await expectLater(repo.removeMember(12), completes);
  });

  test('revokeInvite：POST /invitations/revoke {tripId,email}', () async {
    dioAdapter.onPost(
      '/invitations/revoke',
      (server) => server.reply(200, {'ok': true, 'revoked': 1}),
      data: {'tripId': 'okinawa', 'email': 'b@x.com'},
    );
    await expectLater(
      repo.revokeInvite(tripId: 'okinawa', email: 'b@x.com'),
      completes,
    );
  });
}
