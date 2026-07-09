/// Public runtime feature flags exposed before authentication.
library;

class PublicConfig {
  const PublicConfig({required this.providers, required this.features});

  final PublicAuthProviders providers;
  final PublicFeatures features;

  bool get googleProviderEnabled => providers.google;
  bool get passwordSignupEnabled => features.passwordSignup;
  bool get emailVerificationEnabled => features.emailVerification;

  factory PublicConfig.fromJson(Map<String, dynamic> json) => PublicConfig(
    providers: PublicAuthProviders.fromJson(_mapValue(json['providers'])),
    features: PublicFeatures.fromJson(_mapValue(json['features'])),
  );
}

class PublicAuthProviders {
  const PublicAuthProviders({required this.google});

  final bool google;

  factory PublicAuthProviders.fromJson(Map<String, dynamic> json) =>
      PublicAuthProviders(google: json['google'] == true);
}

class PublicFeatures {
  const PublicFeatures({
    required this.passwordSignup,
    required this.emailVerification,
  });

  final bool passwordSignup;
  final bool emailVerification;

  factory PublicFeatures.fromJson(Map<String, dynamic> json) => PublicFeatures(
    passwordSignup: json['passwordSignup'] == true,
    emailVerification: json['emailVerification'] == true,
  );
}

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}
