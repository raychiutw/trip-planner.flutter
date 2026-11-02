/// 授權啟動器的平台實作：iOS ASWebAuthenticationSession、Android Auth Tab。
/// device 相依，不做單元測試（轉換邏輯很薄，真機驗證見 #490）。
library;

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
        options: FlutterWebAuth2Options(
          httpsHost: callbackHost,
          httpsPath: callbackPath,
        ),
      );
      return Uri.parse(result);
    } on PlatformException catch (e) {
      throw authorizeException(e, DateTime.now().difference(startedAt));
    }
  }
}

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
