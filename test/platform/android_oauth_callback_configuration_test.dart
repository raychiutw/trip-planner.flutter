import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_config.dart';

/// 守門：Android 的 OAuth callback（https App Link）。manifest 的 intent-filter
/// 與 build.gradle.kts 的預設值要和 [OAuthConfig] 一致，搬 callback 網域時最容易漏。
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  // 取出 flutter_web_auth_2 CallbackActivity 那個 intent-filter。
  final activity = RegExp(
    r'<activity[^>]*CallbackActivity[\s\S]*?</activity>',
  ).firstMatch(manifest)?.group(0);

  test('manifest 有 CallbackActivity 且 exported', () {
    expect(activity, isNotNull);
    expect(activity, contains('android:exported="true"'));
  });

  test('callback intent-filter 開 autoVerify、https、host/path 走 placeholder', () {
    expect(
      activity,
      contains(
        '<intent-filter android:label="flutter_web_auth_2" android:autoVerify="true">',
      ),
    );
    expect(activity, contains('android:name="android.intent.action.VIEW"'));
    expect(activity, contains('android.intent.category.BROWSABLE'));
    expect(activity, contains('android:scheme="https"'));
    expect(activity, contains('android:host="\${oauthCallbackHost}"'));
    expect(activity, contains('android:path="\${oauthCallbackPath}"'));
  });

  String? gradleDefault(String key) => RegExp(
    'manifestPlaceholders\\["$key"\\]\\s*=\\s*\\(project\\.findProperty\\("$key"\\) as String\\?\\)\\s*\\?:\\s*"([^"]*)"',
  ).firstMatch(gradle)?.group(1);

  test('build.gradle.kts 的預設 host 與 OAuthConfig 一致', () {
    expect(gradleDefault('oauthCallbackHost'), OAuthConfig.callbackHost);
  });

  test('build.gradle.kts 的預設 path 與 OAuthConfig 一致', () {
    expect(gradleDefault('oauthCallbackPath'), OAuthConfig.callbackPath);
  });

  test('過渡期另有舊 callback 的 intent-filter（host/path 走 placeholder）', () {
    expect(activity, contains('android:host="\${oauthLegacyCallbackHost}"'));
    expect(activity, contains('android:path="\${oauthLegacyCallbackPath}"'));
  });

  test('預設 callback 是主站路徑，舊 callback 只在 legacy placeholder', () {
    expect(gradleDefault('oauthCallbackHost'), 'trip-planner-dby.pages.dev');
    expect(gradleDefault('oauthCallbackPath'), '/mobile/oauth/callback');
    expect(
      gradleDefault('oauthLegacyCallbackHost'),
      'mobile-callback.trip-planner-dby.pages.dev',
    );
    expect(gradleDefault('oauthLegacyCallbackPath'), '/oauth/callback');
  });
}
