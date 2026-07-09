import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/public_config.dart';

void main() {
  group('PublicConfig.fromJson', () {
    test('解析 providers/features flags', () {
      final config = PublicConfig.fromJson({
        'providers': {'google': true},
        'features': {'passwordSignup': true, 'emailVerification': false},
      });

      expect(config.googleProviderEnabled, isTrue);
      expect(config.passwordSignupEnabled, isTrue);
      expect(config.emailVerificationEnabled, isFalse);
    });

    test('缺漏區塊預設 false', () {
      final config = PublicConfig.fromJson({});

      expect(config.googleProviderEnabled, isFalse);
      expect(config.passwordSignupEnabled, isFalse);
      expect(config.emailVerificationEnabled, isFalse);
    });
  });
}
