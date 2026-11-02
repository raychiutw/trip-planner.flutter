import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/web_auth_launcher.dart';

void main() {
  PlatformException canceled([Object? details]) => PlatformException(
    code: 'CANCELED',
    message: 'User canceled login',
    details: details,
  );

  test('使用者過一陣子才取消：照舊視為取消，不顯示錯誤', () {
    final e = authorizeException(canceled(), const Duration(seconds: 5));

    expect(e.cancelled, isTrue);
    expect(e.userMessage, '已取消登入');
  });

  test('視窗一出現就被取消（人來不及按）：視為失敗並把原因帶給使用者', () {
    final e = authorizeException(
      canceled({'domain': 'com.apple.AuthenticationServices', 'code': 1}),
      const Duration(milliseconds: 300),
    );

    expect(e.cancelled, isFalse);
    expect(e.userMessage, contains('授權視窗沒有開啟'));
    expect(e.userMessage, contains('CANCELED'));
    expect(e.userMessage, contains('com.apple.AuthenticationServices'));
  });

  test('其他平台錯誤：使用者訊息帶錯誤碼，方便回報', () {
    final e = authorizeException(
      PlatformException(code: 'ACQUIRE_ROOT_VIEW_CONTROLLER_FAILED'),
      const Duration(seconds: 1),
    );

    expect(e.cancelled, isFalse);
    expect(e.userMessage, contains('ACQUIRE_ROOT_VIEW_CONTROLLER_FAILED'));
  });
}
