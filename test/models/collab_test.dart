import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/collab.dart';

void main() {
  test('TripPermission.fromJson 解析 member 權限與 displayName', () {
    final permission = TripPermission.fromJson({
      'id': 7,
      'email': 'friend@example.com',
      'displayName': '旅伴',
      'tripId': 'okinawa-trip-2026',
      'role': 'member',
    });

    expect(permission.id, 7);
    expect(permission.displayName, '旅伴');
    expect(permission.isOwner, isFalse);
    expect(permission.roleLabel, '共編成員');
  });

  test('PendingInvitationPage.fromJson 解析 pending invitations wrapper', () {
    final page = PendingInvitationPage.fromJson({
      'items': [
        {
          'id': 'hash-1',
          'invitedEmail': 'pending@example.com',
          'createdAt': '2026-07-01T00:00:00Z',
          'expiresAt': '2026-07-08T00:00:00Z',
          'daysRemaining': 3,
          'isExpired': false,
        },
      ],
    });

    expect(page.items.single.invitedEmail, 'pending@example.com');
    expect(page.items.single.daysRemaining, 3);
    expect(page.items.single.isExpired, isFalse);
  });

  test('InvitationPreview.fromJson 解析邀請預覽', () {
    final preview = InvitationPreview.fromJson({
      'tripId': 'okinawa-trip-2026',
      'tripTitle': '沖繩家族旅行',
      'invitedEmail': 'friend@example.com',
      'inviterDisplayName': 'Ray',
      'inviterEmail': 'ray@example.com',
      'expiresAt': '2026-07-15T00:00:00Z',
    });

    expect(preview.tripTitle, '沖繩家族旅行');
    expect(preview.inviterLabel, 'Ray');
  });

  test('InvitationAcceptResult.fromJson 解析接受結果', () {
    final result = InvitationAcceptResult.fromJson({
      'ok': true,
      'tripId': 'okinawa-trip-2026',
      'tripTitle': '沖繩家族旅行',
    });

    expect(result.ok, isTrue);
    expect(result.tripId, 'okinawa-trip-2026');
  });

  test('PermissionRoleUpdateResult.fromJson 解析 role update 結果', () {
    final changed = PermissionRoleUpdateResult.fromJson({
      'ok': true,
      'role': 'viewer',
    });
    final unchanged = PermissionRoleUpdateResult.fromJson({
      'ok': true,
      'unchanged': true,
    });

    expect(changed.ok, isTrue);
    expect(changed.role, 'viewer');
    expect(changed.unchanged, isFalse);
    expect(unchanged.unchanged, isTrue);
  });
}
