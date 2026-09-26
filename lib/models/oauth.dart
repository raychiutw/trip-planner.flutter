/// OAuth connected apps, developer apps, and consent models.
library;

import 'dart:convert';

/// User-side granted OAuth client app.
class ConnectedApp {
  const ConnectedApp({
    required this.clientId,
    required this.appName,
    this.appLogoUrl,
    this.appDescription,
    this.homepageUrl,
    required this.status,
    required this.scopes,
    required this.grantedAt,
  });

  final String clientId;
  final String appName;
  final String? appLogoUrl;
  final String? appDescription;
  final String? homepageUrl;
  final String status;
  final List<String> scopes;
  final int grantedAt;

  factory ConnectedApp.fromJson(Map<String, dynamic> json) {
    return ConnectedApp(
      clientId: _stringFromAnyKey(json, 'client_id', 'clientId') ?? '',
      appName: _stringFromAnyKey(json, 'app_name', 'appName') ?? '未知應用程式',
      appLogoUrl: _stringFromAnyKey(json, 'app_logo_url', 'appLogoUrl'),
      appDescription: _stringFromAnyKey(
        json,
        'app_description',
        'appDescription',
      ),
      homepageUrl: _stringFromAnyKey(json, 'homepage_url', 'homepageUrl'),
      status: _stringFromAnyKey(json, 'status', 'status') ?? '',
      scopes: _stringList(json['scopes']),
      grantedAt: _intFromAnyKey(json, 'granted_at', 'grantedAt') ?? 0,
    );
  }

  String get statusLabel => oauthClientStatusLabel(status);
}

/// Developer-owned OAuth client app.
class DeveloperApp {
  const DeveloperApp({
    required this.clientId,
    required this.clientType,
    required this.appName,
    this.appDescription,
    this.appLogoUrl,
    this.homepageUrl,
    required this.redirectUris,
    required this.allowedScopes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String clientId;
  final String clientType;
  final String appName;
  final String? appDescription;
  final String? appLogoUrl;
  final String? homepageUrl;
  final List<String> redirectUris;
  final List<String> allowedScopes;
  final String status;
  final String createdAt;
  final String updatedAt;

  factory DeveloperApp.fromJson(Map<String, dynamic> json) {
    return DeveloperApp(
      clientId: _stringFromAnyKey(json, 'client_id', 'clientId') ?? '',
      clientType: _stringFromAnyKey(json, 'client_type', 'clientType') ?? '',
      appName: _stringFromAnyKey(json, 'app_name', 'appName') ?? '未命名應用',
      appDescription: _stringFromAnyKey(
        json,
        'app_description',
        'appDescription',
      ),
      appLogoUrl: _stringFromAnyKey(json, 'app_logo_url', 'appLogoUrl'),
      homepageUrl: _stringFromAnyKey(json, 'homepage_url', 'homepageUrl'),
      redirectUris: _stringList(json['redirect_uris'] ?? json['redirectUris']),
      allowedScopes: _stringList(
        json['allowed_scopes'] ?? json['allowedScopes'],
      ),
      status: _stringFromAnyKey(json, 'status', 'status') ?? '',
      createdAt: _stringFromAnyKey(json, 'created_at', 'createdAt') ?? '',
      updatedAt: _stringFromAnyKey(json, 'updated_at', 'updatedAt') ?? '',
    );
  }

  String get statusLabel => oauthClientStatusLabel(status);

  String get clientTypeLabel =>
      clientType == 'confidential' ? 'Confidential' : 'Public';
}

/// Newly created developer app. `clientSecret` is one-time only.
class CreatedDeveloperApp {
  const CreatedDeveloperApp({
    required this.clientId,
    this.clientSecret,
    required this.appName,
    required this.clientType,
    required this.status,
    required this.redirectUris,
    required this.allowedScopes,
  });

  final String clientId;
  final String? clientSecret;
  final String appName;
  final String clientType;
  final String status;
  final List<String> redirectUris;
  final List<String> allowedScopes;

  factory CreatedDeveloperApp.fromJson(Map<String, dynamic> json) {
    return CreatedDeveloperApp(
      clientId: _stringFromAnyKey(json, 'client_id', 'clientId') ?? '',
      clientSecret: _nullableString(
        json['client_secret'] ?? json['clientSecret'],
      ),
      appName: _stringFromAnyKey(json, 'app_name', 'appName') ?? '未命名應用',
      clientType: _stringFromAnyKey(json, 'client_type', 'clientType') ?? '',
      status: _stringFromAnyKey(json, 'status', 'status') ?? '',
      redirectUris: _stringList(json['redirect_uris'] ?? json['redirectUris']),
      allowedScopes: _stringList(
        json['allowed_scopes'] ?? json['allowedScopes'],
      ),
    );
  }

  String get statusLabel => oauthClientStatusLabel(status);
}

/// Self-service developer apps may only request these user scopes.
const List<String> kDeveloperAllowedScopes = [
  'openid',
  'profile',
  'email',
  'offline_access',
];

String oauthScopeLabel(String scope) {
  return switch (scope) {
    'openid' => '識別您的身分（唯一 ID）',
    'profile' => '基本個人資料（名稱、頭像）',
    'email' => '您的電子郵件地址',
    'offline_access' => '即使您離線也可存取（refresh token）',
    'trips:read' => '讀取您的行程資料',
    'trips:write' => '建立 / 修改您的行程',
    _ => scope,
  };
}

String oauthClientStatusLabel(String status) {
  return switch (status) {
    'active' => '已啟用',
    'pending_review' => '待審核',
    'disabled' => '已停用',
    'suspended' => '已停用',
    'revoked' => '已撤銷',
    _ => status.isEmpty ? '未知' : status,
  };
}

String? _stringFromAnyKey(
  Map<String, dynamic> json,
  String key,
  String fallbackKey,
) {
  return _nullableString(json[key] ?? json[fallbackKey]);
}

int? _intFromAnyKey(Map<String, dynamic> json, String key, String fallbackKey) {
  final value = json[key] ?? json[fallbackKey];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<String> _stringList(Object? value) {
  final raw = switch (value) {
    String stringValue => _decodeJsonList(stringValue),
    List listValue => listValue,
    _ => const <dynamic>[],
  };
  return raw
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

List<dynamic> _decodeJsonList(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is List) return decoded;
  } on FormatException {
    return const <dynamic>[];
  }
  return const <dynamic>[];
}

String? _nullableString(Object? value) {
  final stringValue = value?.toString();
  if (stringValue == null || stringValue.trim().isEmpty) return null;
  return stringValue;
}
