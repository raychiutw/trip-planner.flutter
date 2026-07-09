import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/oauth.dart';

void main() {
  test('ConnectedApp.fromJson 支援 snake_case 與授權 scope', () {
    final app = ConnectedApp.fromJson({
      'client_id': 'tp_alpha',
      'app_name': 'Alpha App',
      'app_logo_url': 'https://example.com/logo.png',
      'app_description': '行程同步工具',
      'homepage_url': 'https://example.com',
      'status': 'active',
      'scopes': ['openid', 'email'],
      'granted_at': 1783500000000,
    });

    expect(app.clientId, 'tp_alpha');
    expect(app.appName, 'Alpha App');
    expect(app.statusLabel, '已啟用');
    expect(app.scopes, ['openid', 'email']);
    expect(app.grantedAt, 1783500000000);
  });

  test('DeveloperApp.fromJson 支援 JSON string/list 欄位與狀態 label', () {
    final app = DeveloperApp.fromJson({
      'client_id': 'tp_dev',
      'client_type': 'confidential',
      'app_name': 'Dev App',
      'app_description': null,
      'app_logo_url': 'https://dev.example.com/logo.png',
      'homepage_url': 'https://dev.example.com',
      'redirect_uris': '["https://dev.example.com/callback"]',
      'allowed_scopes': ['openid', 'profile', 'offline_access'],
      'status': 'suspended',
      'created_at': '2026-07-08T10:00:00Z',
      'updated_at': '2026-07-08T10:00:00Z',
    });

    expect(app.clientId, 'tp_dev');
    expect(app.clientType, 'confidential');
    expect(app.appLogoUrl, 'https://dev.example.com/logo.png');
    expect(app.redirectUris, ['https://dev.example.com/callback']);
    expect(app.allowedScopes, ['openid', 'profile', 'offline_access']);
    expect(app.statusLabel, '已停用');
  });

  test('CreatedDeveloperApp.fromJson 保存一次性 client_secret', () {
    final app = CreatedDeveloperApp.fromJson({
      'client_id': 'tp_new',
      'client_secret': 'tps_secret',
      'app_name': 'New App',
      'client_type': 'confidential',
      'status': 'pending_review',
      'redirect_uris': ['https://new.example.com/callback'],
      'allowed_scopes': ['openid', 'email'],
    });

    expect(app.clientId, 'tp_new');
    expect(app.clientSecret, 'tps_secret');
    expect(app.statusLabel, '待審核');
  });

  test('OAuthConsentRequest 從 URI query 還原並產生 submit body', () {
    final request = OAuthConsentRequest.fromUri(
      Uri.parse(
        'https://trip.example/oauth/consent?client_id=tp_alpha'
        '&redirect_uri=https%3A%2F%2Fapp.example.com%2Fcallback'
        '&scope=openid%20email'
        '&state=abc123'
        '&response_type=code'
        '&code_challenge=challenge'
        '&code_challenge_method=S256',
      ),
    );

    expect(request.clientId, 'tp_alpha');
    expect(request.requestedScopes, ['openid', 'email']);
    expect(request.hasPlausibleRedirectUri, isTrue);
    expect(oauthScopeLabel('email'), '您的電子郵件地址');
    expect(oauthScopeLabel('unknown'), 'unknown');

    expect(request.toBody('allow'), {
      'client_id': 'tp_alpha',
      'redirect_uri': 'https://app.example.com/callback',
      'scope': 'openid email',
      'state': 'abc123',
      'response_type': 'code',
      'code_challenge': 'challenge',
      'code_challenge_method': 'S256',
      'decision': 'allow',
    });
  });
}
