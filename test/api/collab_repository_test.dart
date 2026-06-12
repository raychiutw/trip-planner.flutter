import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
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
