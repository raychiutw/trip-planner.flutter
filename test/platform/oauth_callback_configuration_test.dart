import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_config.dart';

/// iOS 17.4+ 的 ASWebAuthenticationSession 用 https callback 時，系統要確認
/// callback 網域與 App 有 webcredentials 關聯；只有 applinks 時授權視窗一開
/// 就被回報成取消（CANCELED／code 1），登入按下去什麼都沒發生。
void main() {
  // 過渡期（舊版 App 仍用舊 callback）保留的舊網域；api 同時接受新舊兩組 redirect。
  const legacyHost = 'mobile-callback.trip-planner-dby.pages.dev';

  test('預設 callback 是 web 主站路徑，不是舊 mobile-callback 主機', () {
    expect(OAuthConfig.callbackHost, 'trip-planner-dby.pages.dev');
    expect(OAuthConfig.callbackPath, '/mobile/oauth/callback');
    expect(
      OAuthConfig.redirectUri,
      'https://trip-planner-dby.pages.dev/mobile/oauth/callback',
    );
  });

  for (final file in [
    'ios/Runner/Release.entitlements',
    'ios/Runner/DebugProfile.entitlements',
  ]) {
    test('$file 宣告 callback 網域的 webcredentials 與 applinks', () {
      final text = File(file).readAsStringSync();

      expect(
        text,
        contains('<string>webcredentials:${OAuthConfig.callbackHost}</string>'),
      );
      expect(
        text,
        contains('<string>applinks:${OAuthConfig.callbackHost}</string>'),
      );
      // 過渡期舊網域先保留，等舊版 App 退場再移除。
      expect(text, contains('<string>webcredentials:$legacyHost</string>'));
      expect(text, contains('<string>applinks:$legacyHost</string>'));
    });
  }
}
