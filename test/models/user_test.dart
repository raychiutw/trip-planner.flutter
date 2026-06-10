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

  group('AccountStats.fromJson', () {
    test('解析 3 個統計欄位', () {
      final stats = AccountStats.fromJson({
        'tripCount': 2,
        'totalDays': 10,
        'collaboratorCount': 3,
      });

      expect(stats.tripCount, 2);
      expect(stats.totalDays, 10);
      expect(stats.collaboratorCount, 3);
    });

    test('欄位缺漏時預設 0', () {
      final stats = AccountStats.fromJson({});

      expect(stats.tripCount, 0);
      expect(stats.totalDays, 0);
      expect(stats.collaboratorCount, 0);
    });
  });
}
