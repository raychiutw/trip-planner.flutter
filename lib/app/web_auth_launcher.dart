/// 授權啟動器的平台實作：iOS ASWebAuthenticationSession、Android Auth Tab。
/// device 相依，不做單元測試（轉換邏輯很薄，真機驗證見 #490）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../api/oauth/oauth_login_service.dart';

class WebAuthLauncher implements AuthorizationLauncher {
  const WebAuthLauncher();

  @override
  Future<Uri> authorize(
    Uri authorizeUrl, {
    required String callbackHost,
    required String callbackPath,
  }) async {
    final startedAt = DateTime.now();
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authorizeUrl.toString(),
        callbackUrlScheme: 'https',
        options: webAuthOptions(host: callbackHost, path: callbackPath),
      );
      return Uri.parse(result);
    } on PlatformException catch (e) {
      throw authorizeException(e, DateTime.now().difference(startedAt));
    }
  }
}

/// 授權視窗選項。iOS 用 ephemeral session：非 ephemeral 的 session 與 Safari 共用網站資料，
/// 系統會先跳「想要使用…登入」讓使用者再按一次；代價是不沿用 Safari 的登入狀態。
/// Android 維持原行為（外掛在 Android 也吃這個選項，所以要明確限定平台）。
@visibleForTesting
FlutterWebAuth2Options webAuthOptions({
  required String host,
  required String path,
  TargetPlatform? platform,
}) => FlutterWebAuth2Options(
  httpsHost: host,
  httpsPath: path,
  preferEphemeral: (platform ?? defaultTargetPlatform) == TargetPlatform.iOS,
);

/// 視窗開啟後這麼快就被「取消」，不可能是人按的，而是系統根本沒把視窗顯示出來。
const _instantCancel = Duration(seconds: 1);

/// 授權視窗的平台錯誤轉成登入例外。
///
/// 真機曾出現按了登入卻沒有任何視窗也沒有錯誤；系統把「沒能顯示」回報成
/// CANCELED。這種情況要讓使用者看到原因（錯誤碼），不能靜默吞掉。
OAuthLoginException authorizeException(PlatformException e, Duration elapsed) {
  if (e.code == 'CANCELED' && elapsed >= _instantCancel) {
    return OAuthLoginException(
      '使用者取消登入',
      userMessage: '已取消登入',
      cancelled: true,
    );
  }
  final detail = e.details is Map
      ? ' ${(e.details as Map)['domain']}/${(e.details as Map)['code']}'
      : '';
  final reason = e.code == 'CANCELED' ? '授權視窗沒有開啟' : '無法開啟授權視窗';
  return OAuthLoginException(
    '$reason:${e.code}$detail',
    userMessage: '$reason（${e.code}$detail），請稍後再試',
  );
}
