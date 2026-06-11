/// 把 OAuthTokenStore + OAuthRepository 接成 ApiClient 用的 BearerTokenSource:
/// 提供當前 access token,過期時用 refresh token 換新並寫回。
/// 安全要點:只有「真的失效(token 端 400/401)」才清空登入;暫時性(網路/寫入)
/// 保留 token 稍後再試,避免 rotating refresh token 因一次失敗就鎖死。並發 refresh
/// single-flight,避免同一輪過期觸發多次 refresh 把 rotating token 燒掉。
library;

import '../../models/oauth_tokens.dart';
import '../api_client.dart' show BearerTokenSource;
import '../api_error.dart';
import 'oauth_repository.dart';
import 'oauth_token_store.dart';

class StoredBearerTokenSource implements BearerTokenSource {
  StoredBearerTokenSource({
    required OAuthTokenStore store,
    required OAuthRepository repository,
    required String clientId,
  }) : _store = store,
       _repo = repository,
       _clientId = clientId;

  final OAuthTokenStore _store;
  final OAuthRepository _repo;
  final String _clientId;

  Future<OAuthTokens?>? _inFlight;

  @override
  Future<String?> accessToken() async {
    final tokens = await _store.read();
    if (tokens == null) return null;
    if (!tokens.isExpired()) return tokens.accessToken;
    return (await _refreshShared())?.accessToken;
  }

  @override
  Future<bool> refresh() async => (await _refreshShared()) != null;

  /// single-flight:同一時間只跑一次 refresh,並發呼叫共用同一個 Future。
  Future<OAuthTokens?> _refreshShared() =>
      _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);

  Future<OAuthTokens?> _doRefresh() async {
    final rt = (await _store.read())?.refreshToken;
    if (rt == null || rt.isEmpty) return null;

    final OAuthTokens fresh;
    try {
      fresh = await _repo.refresh(refreshToken: rt, clientId: _clientId);
    } on ApiError catch (e) {
      // 400/401 = refresh token 真的失效(撤銷/過期)→ 視為登出。
      if (e.status == 400 || e.status == 401) await _store.clear();
      return null;
    } on Exception {
      // 網路等暫時性錯誤 → 保留 token,稍後再試(不清空)。
      return null;
    }

    try {
      await _store.write(fresh);
    } on Exception {
      // 寫入失敗:仍回傳 fresh(本輪可用),不清空(下次再試寫)。
    }
    return fresh;
  }
}
