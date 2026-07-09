import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/trip_member.dart';

void main() {
  test('InvitationDetails.fromJson 解析 camelCase 欄位', () {
    final invitation = InvitationDetails.fromJson({
      'tripId': 'trip-1',
      'tripTitle': '沖繩家庭旅行',
      'invitedEmail': 'traveler@example.com',
      'inviterDisplayName': 'Ray',
      'inviterEmail': 'ray@example.com',
      'expiresAt': '2026-07-16T00:00:00.000Z',
    });

    expect(invitation.tripId, 'trip-1');
    expect(invitation.tripTitle, '沖繩家庭旅行');
    expect(invitation.invitedEmail, 'traveler@example.com');
    expect(invitation.inviterDisplayName, 'Ray');
    expect(invitation.inviterEmail, 'ray@example.com');
    expect(invitation.expiresAt, '2026-07-16T00:00:00.000Z');
  });

  test('InvitationDetails.fromJson 支援 snake_case fallback', () {
    final invitation = InvitationDetails.fromJson({
      'trip_id': 'trip-1',
      'trip_title': '沖繩家庭旅行',
      'invited_email': 'traveler@example.com',
      'inviter_display_name': null,
      'inviter_email': 'ray@example.com',
      'expires_at': '2026-07-16T00:00:00.000Z',
    });

    expect(invitation.tripId, 'trip-1');
    expect(invitation.tripTitle, '沖繩家庭旅行');
    expect(invitation.invitedEmail, 'traveler@example.com');
    expect(invitation.inviterDisplayName, isNull);
    expect(invitation.inviterEmail, 'ray@example.com');
    expect(invitation.expiresAt, '2026-07-16T00:00:00.000Z');
  });

  test('InvitationAcceptResult.fromJson 解析接受結果', () {
    final result = InvitationAcceptResult.fromJson({
      'ok': true,
      'tripId': 'trip-1',
      'tripTitle': '沖繩家庭旅行',
    });

    expect(result.tripId, 'trip-1');
    expect(result.tripTitle, '沖繩家庭旅行');
  });
}
