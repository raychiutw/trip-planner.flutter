import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/user.dart';

void main() {
  group('UserInfo.fromJson', () {
    test('解析完整欄位', () {
      final userInfo = UserInfo.fromJson({
        'id': 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
        'email': 'traveler@example.com',
        'emailVerified': true,
        'displayName': 'Ray',
        'avatarUrl': 'https://example.com/avatar.png',
        'createdAt': '2026-01-01 00:00:00',
      });

      expect(userInfo.id, 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4');
      expect(userInfo.email, 'traveler@example.com');
      expect(userInfo.emailVerified, isTrue);
      expect(userInfo.displayName, 'Ray');
      expect(userInfo.avatarUrl, 'https://example.com/avatar.png');
      expect(userInfo.createdAt, '2026-01-01 00:00:00');
    });

    test('emailVerified 0/1 轉 bool', () {
      final verifiedUser = UserInfo.fromJson({
        'id': 'u1',
        'email': 'a@b.c',
        'emailVerified': 1,
      });
      final unverifiedUser = UserInfo.fromJson({
        'id': 'u2',
        'email': 'd@e.f',
        'emailVerified': 0,
      });

      expect(verifiedUser.emailVerified, isTrue);
      expect(unverifiedUser.emailVerified, isFalse);
    });

    test('nullable 欄位缺漏為 null、emailVerified 缺漏預設 false', () {
      final userInfo = UserInfo.fromJson({'id': 'u3', 'email': 'g@h.i'});

      expect(userInfo.emailVerified, isFalse);
      expect(userInfo.displayName, isNull);
      expect(userInfo.avatarUrl, isNull);
      expect(userInfo.createdAt, isNull);
    });
  });

  group('AccountNotificationPreferences.fromJson', () {
    test('解析 camelCase 欄位', () {
      final prefs = AccountNotificationPreferences.fromJson({
        'tripUpdates': true,
        'invitations': false,
        'system': true,
        'updatedAt': '2026-07-09T00:00:00Z',
      });

      expect(prefs.tripUpdates, isTrue);
      expect(prefs.invitations, isFalse);
      expect(prefs.system, isTrue);
      expect(prefs.updatedAt, '2026-07-09T00:00:00Z');
    });

    test('接受 snake_case / 0/1 flags 並在缺漏時預設開啟', () {
      final prefs = AccountNotificationPreferences.fromJson({
        'trip_updates': 0,
        'updated_at': '2026-07-09T00:00:00Z',
      });

      expect(prefs.tripUpdates, isFalse);
      expect(prefs.invitations, isTrue);
      expect(prefs.system, isTrue);
      expect(prefs.updatedAt, '2026-07-09T00:00:00Z');
    });

    test('copyWith 只覆寫指定欄位', () {
      const prefs = AccountNotificationPreferences(
        tripUpdates: true,
        invitations: true,
        system: true,
        updatedAt: '2026-07-09T00:00:00Z',
      );

      final next = prefs.copyWith(invitations: false);

      expect(next.tripUpdates, isTrue);
      expect(next.invitations, isFalse);
      expect(next.system, isTrue);
      expect(next.updatedAt, '2026-07-09T00:00:00Z');
    });
  });
}
