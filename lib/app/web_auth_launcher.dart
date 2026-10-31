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
      if (e.code == 'CANCELED') {
        throw OAuthLoginException(
          '使用者取消登入',
          userMessage: '已取消登入',
          cancelled: true,
        );
      }
      throw OAuthLoginException('無法開啟瀏覽器登入:${e.code}');
    }
  }
}
