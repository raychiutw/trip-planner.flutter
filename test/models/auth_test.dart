import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/auth.dart';

void main() {
  group('SignupResult', () {
    test('fromJson 解析註冊成功與 invitation 結果', () {
      final result = SignupResult.fromJson({
        'ok': true,
        'userId': 'user-1',
        'email': 'ray@example.com',
        'requiresVerification': true,
        'joinedTrip': {'id': 'trip-1', 'title': '沖繩家族旅行'},
        'invitationError': null,
      });

      expect(result.ok, isTrue);
      expect(result.userId, 'user-1');
      expect(result.email, 'ray@example.com');
      expect(result.requiresVerification, isTrue);
      expect(result.joinedTrip?.id, 'trip-1');
      expect(result.joinedTrip?.title, '沖繩家族旅行');
      expect(result.invitationError, isNull);
    });

    test('fromJson 缺少 optional 欄位時給安全預設值', () {
      final result = SignupResult.fromJson({
        'userId': 'user-1',
        'email': 'ray@example.com',
      });

      expect(result.ok, isFalse);
      expect(result.requiresVerification, isFalse);
      expect(result.joinedTrip, isNull);
      expect(result.invitationError, isNull);
    });
  });

  group('AuthMessageResult', () {
    test('fromJson 解析通用訊息回應', () {
      final result = AuthMessageResult.fromJson({
        'ok': true,
        'message': '若 email 已註冊，重設連結將寄至信箱',
      });

      expect(result.ok, isTrue);
      expect(result.message, '若 email 已註冊，重設連結將寄至信箱');
    });
  });
}
