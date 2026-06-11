/// 把 OAuthTokenStore + OAuthRepository 接成 ApiClient 用的 BearerTokenSource:
/// 提供當前 access token,過期時用 refresh token 換新並寫回(失敗清空)。
library;

import '../api_client.dart' show BearerTokenSource;
import 'oauth_repository.dart';
import 'oauth_token_store.dart';

class StoredBearerTokenSource implements BearerTokenSource {
  StoredBearerTokenSource({
    required OAuthTokenStore store,
    required OAuthRepository repository,
    required String clientId,
  })  : _store = store,
        _repo = repository,
        _clientId = clientId;

  final OAuthTokenStore _store;
  final OAuthRepository _repo;
  final String _clientId;

  @override
  Future<String?> accessToken() async {
    final tokens = await _store.read();
    if (tokens == null) return null;
    if (!tokens.isExpired()) return tokens.accessToken;
    // 過期 → 嘗試 refresh,成功則回新的 access。
    return (await refresh()) ? (await _store.read())?.accessToken : null;
  }

  @override
  Future<bool> refresh() async {
    final rt = (await _store.read())?.refreshToken;
    if (rt == null || rt.isEmpty) return false;
    try {
      final fresh = await _repo.refresh(refreshToken: rt, clientId: _clientId);
      await _store.write(fresh);
      return true;
    } on Exception {
      await _store.clear(); // refresh 失敗(過期/撤銷)→ 視為登出
      return false;
    }
  }
}
