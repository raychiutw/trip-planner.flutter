# OAuth 2.1 PKCE + Bearer 認證 設計 spec

> P2。把 native app 的認證從「session cookie + 偽造 Origin」過渡方案,改為正規 OAuth 2.1
> authorization-code + PKCE-S256 + Bearer token。後端引擎已就緒(authorize/token/refresh/JWKS,
> API 收 Bearer;Bearer + 無 Origin 可跳過 CSRF)。**後端不動**。

## 後端契約(已查證,固定)
- `GET /api/oauth/authorize?response_type=code&client_id=&redirect_uri=&scope=&state=&code_challenge=&code_challenge_method=S256` → 需 session 登入 + consent → `302 redirect_uri?code=&state=`。**PKCE 強制、僅 S256**。
- `POST /api/oauth/token`(form-urlencoded):
  - `grant_type=authorization_code&code=&redirect_uri=&client_id=&code_verifier=` → `{access_token, refresh_token, token_type:Bearer, expires_in:3600, scope, id_token?}`。
  - `grant_type=refresh_token&refresh_token=&client_id=` → 新 token pair(refresh 會輪替)。
- API 收 `Authorization: Bearer <opaque access_token>`(等同 cookie);**Bearer + 不送 Origin → 跳過 CSRF**。access TTL 1h、refresh TTL 30d。
- **`/oauth/userinfo` 不收 Bearer**(僅 cookie)→ 身分改讀 `id_token` claims 或一般端點。
- redirect_uri 政策:僅 `https://` 或 `http://127.0.0.1|localhost`(**custom scheme 被拒**);exact-string 比對。

## 已知外部相依(非本 repo 能完成,需 backend owner provision)
1. 一個 `active` 的 **public** `client_apps` 列(`client_id` + `redirect_uris`)。self-register `POST /api/dev/apps` 會落在 `pending_review`,需 ops 啟用。
2. redirect:採 **loopback 固定埠** `http://127.0.0.1:<port>`(RFC 8252;custom scheme 被拒、https App Link 需後端網域 association)。
→ client 端程式可先寫好 + 單測;e2e 待 client 註冊。client_id/redirect 用 `--dart-define` 注入。

## 範圍(client 端,可立即寫 + 單測)
- **PKCE**(`lib/api/oauth/pkce.dart`):`generateCodeVerifier()`(43+ 字,`Random.secure`)、`codeChallengeS256(verifier)`(base64url(sha256),無 padding)。純函式(challenge 部分可用 RFC 7636 測試向量驗)。
- **OAuthTokens model**(`lib/models/oauth_tokens.dart`):accessToken/refreshToken/tokenType/scope/expiresAt(由 expires_in + now 推);`isExpired`;fromJson(token 回應);toJson(存儲)。
- **OAuthRepository**(`lib/api/oauth/oauth_repository.dart`,自帶 Dio,不經 ApiClient 的 cookie/Origin):
  - `buildAuthorizeUrl({clientId, redirectUri, codeChallenge, state, scope})` → Uri(純,測試)。
  - `exchangeCode({code, codeVerifier, clientId, redirectUri})` → POST /oauth/token(form)→ OAuthTokens。
  - `refresh({refreshToken, clientId})` → POST /oauth/token(form)→ OAuthTokens。
- **OAuthTokenStore**(`lib/api/oauth/oauth_token_store.dart`):interface + `SecureOAuthTokenStore`(flutter_secure_storage,存 JSON)+ `InMemoryOAuthTokenStore`(測試)。鏡像 `session_store.dart`。
- **ApiClient Bearer 模式**:新增可選 `BearerTokenSource`(`Future<String?> accessToken()`、`Future<bool> refresh()`)。`_send`:有 token → `Authorization: Bearer` + **不送 Origin/Cookie**;401 且非 retry → `refresh()` 成功則重試一次。`BearerTokenSource==null` → 維持 cookie 模式(現況零破壞)。
- **OAuthConfig**(`lib/api/oauth/oauth_config.dart`):`clientId`/`redirectPort` 由 `--dart-define=TRIPLINE_OAUTH_CLIENT_ID=...`、`...REDIRECT_PORT=...`;`isConfigured`。
- **OAuthLoginService**(`lib/features/auth/oauth_login_service.dart`):loopback 流程編排 — 起 `HttpServer`(127.0.0.1:port)→ 開系統瀏覽器(`url_launcher`)到 authorize URL → 收 `?code&state`(驗 state)→ `exchangeCode` → 存 token。**device 相依、非單測**(網路/瀏覽器部分薄,核心委派給已測的 repository/pkce)。
- **TokenSource bridge**:`StoredBearerTokenSource`(讀 store 的 accessToken;refresh 用 repository + 寫回 store + 失敗清空)。可單測。

## 不在範圍
- 不改 app 預設登入(仍 cookie),OAuth 為「就緒待註冊」;wiring 成預設待 client 啟用後另接。
- userinfo Bearer(後端不收)。動態 client 註冊 UI。

## 測試
pkce(challenge 向量、verifier 長度/字元集)、oauth_tokens(fromJson/expiresAt/isExpired)、oauth_repository(buildAuthorizeUrl 參數、exchange/refresh form body + 解析,http_mock_adapter)、token_store(InMemory round-trip)、ApiClient Bearer(送 Bearer 無 Origin、401→refresh→retry、無 source→cookie 現況)、StoredBearerTokenSource(refresh 寫回/失敗清空)。

## 交付附帶
README/docs 記錄 backend owner 要 provision 的 client(client_id + `redirect_uris:["http://127.0.0.1:<port>"]` + `active` + scopes `openid profile email offline_access`)與 `--dart-define` 用法。
