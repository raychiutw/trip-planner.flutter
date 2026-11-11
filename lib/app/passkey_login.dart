/// 登出後在登入頁用 passkey（Face ID／Touch ID）直接登入（ADR-0016）。
///
/// 流程：`oauth/passkey/options` → 原生 assertion → PKCE + DPoP 金鑰 → `oauth/passkey/login` 拿 code
/// → 與瀏覽器登入共用的換票收尾（[redeemAuthorizationCode]）。
///
/// 入口顯示靠「本機提示旗標」：App 在登出狀態無從得知這支裝置有沒有此網域的 passkey，
/// 所以註冊成功或 passkey 登入成功時記一筆非機密偏好，登出**不清**（這就是恢復點），
/// 失敗與撤銷最後一把 passkey 也不清（避免誤判；真的沒有時就是失敗後留在登入頁）。
///
/// 平台前置同 [PasskeyPlatform]：iOS 的 `webcredentials` 已設；Android 要 web #1678 的 assetlinks，
/// 且 api 要先設定 `PASSKEY_EXTRA_ORIGINS` 接受 `android:apk-key-hash:` 來源，在那之前 Android 登入會被拒。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../api/dpop/jwk_thumbprint.dart';
import '../api/dpop/proof_key_store.dart';
import '../api/oauth/code_redemption.dart';
import '../api/oauth/oauth_config.dart';
import '../api/oauth/oauth_login_service.dart';
import '../api/oauth/oauth_providers.dart';
import '../api/oauth/oauth_repository.dart';
import '../api/oauth/pkce.dart';
import '../api/oauth/stored_bearer_token_source.dart';
import '../api/providers.dart' show settingsStoreProvider;
import '../api/settings_store.dart';
import '../models/oauth_tokens.dart';
import 'passkey_assertion.dart';
import 'passkey_platform.dart';

/// 本機提示旗標的鍵（非機密，存一般偏好）。
const kPasskeyLoginHintKey = 'passkey_login_hint';

/// 登出後用的 passkey 入口要不要顯示的旗標；寫入失敗不影響主流程。
Future<void> markPasskeyLoginHint(SettingsStore store) async {
  try {
    await store.write(kPasskeyLoginHintKey, '1');
  } catch (_) {}
}

/// 失敗一律是通用訊息：401 對外不分原因，不能由這裡洩漏帳號資訊。
const _genericFailure = '無法使用 passkey 登入，請再試一次，或改用瀏覽器登入';

class PasskeyLoginService {
  PasskeyLoginService({
    required OAuthRepository repository,
    required StoredBearerTokenSource source,
    required PasskeyPlatform platform,
    required SettingsStore settings,
    required String clientId,
    ProofKeyStore? proofKeys,
  }) : _repo = repository,
       _source = source,
       _platform = platform,
       _settings = settings,
       _clientId = clientId,
       _proofKeys = proofKeys;

  final OAuthRepository _repo;
  final StoredBearerTokenSource _source;
  final PasskeyPlatform _platform;
  final SettingsStore _settings;
  final String _clientId;
  final ProofKeyStore? _proofKeys;

  /// 失敗與取消都丟 [OAuthLoginException]（取消帶 `cancelled`），與瀏覽器登入同一套處理。
  Future<OAuthTokens> login() async {
    final credential = await _assert();

    final verifier = generateCodeVerifier();
    final keys = _proofKeys;
    final key = await keys?.create();
    final String code;
    try {
      code = await _repo.passkeyLogin(
        clientId: _clientId,
        credential: credential,
        codeChallenge: codeChallengeS256(verifier),
        dpopJkt: key == null ? null : jwkThumbprint(key),
      );
    } on ApiError catch (e) {
      await keys?.delete();
      throw _fromApiError(e);
    } on Exception catch (e) {
      await keys?.delete();
      throw OAuthLoginException(
        'passkey login: $e',
        userMessage: _genericFailure,
      );
    }

    final OAuthTokens tokens;
    try {
      tokens = await redeemAuthorizationCode(
        repository: _repo,
        source: _source,
        clientId: _clientId,
        code: code,
        codeVerifier: verifier,
        key: key,
        proofKeys: keys,
      );
    } on ApiError catch (e) {
      throw _fromApiError(e);
    } on Exception catch (e) {
      throw OAuthLoginException(
        'passkey token exchange: $e',
        userMessage: _genericFailure,
      );
    }
    await markPasskeyLoginHint(_settings);
    return tokens;
  }

  Future<Map<String, dynamic>> _assert() async {
    final Map<String, dynamic> options;
    try {
      options = await _repo.passkeyOptions();
    } on ApiError catch (e) {
      throw _fromApiError(e);
    } on Exception catch (e) {
      throw OAuthLoginException(
        'passkey options: $e',
        userMessage: _genericFailure,
      );
    }
    switch (await _platform.authenticate(options)) {
      case PasskeyAsserted(:final credential):
        return credential;
      case PasskeyAssertCancelled():
        throw OAuthLoginException('使用者取消 passkey 登入', cancelled: true);
      case PasskeyAssertFailed():
        throw OAuthLoginException(
          '平台無法完成 passkey assertion',
          userMessage: _genericFailure,
        );
    }
  }

  OAuthLoginException _fromApiError(ApiError e) => OAuthLoginException(
    'passkey ${e.status} ${e.code}',
    userMessage: e.status == 429 ? '嘗試次數過多，請稍後再試' : _genericFailure,
  );
}

final passkeyLoginServiceProvider = Provider<PasskeyLoginService>(
  (ref) => PasskeyLoginService(
    repository: ref.watch(oauthRepositoryProvider),
    source: ref.watch(bearerTokenSourceProvider),
    platform: ref.watch(passkeyPlatformProvider),
    settings: ref.watch(settingsStoreProvider),
    clientId: OAuthConfig.clientId,
    proofKeys: ref.watch(proofKeyStoreProvider),
  ),
);

/// 登入頁要不要顯示 passkey 入口：有本機提示旗標，且平台支援 passkey。
/// 沒旗標時不查平台。
final passkeyLoginEntryProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    final flagged =
        await ref.read(settingsStoreProvider).read(kPasskeyLoginHintKey) == '1';
    return flagged && await ref.read(passkeyPlatformProvider).isSupported();
  } catch (_) {
    return false;
  }
});
