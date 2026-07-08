# 啟用 OAuth PKCE 登入(取代 session cookie + 偽造 Origin)

native app 的 OAuth 2.1 authorization-code + PKCE 用戶端**已實作完成**,但預設**未啟用** —
app 仍走既有的 session cookie 登入。production backend 已 provision official public client
`tripline-mobile`;要啟用時用 `--dart-define` 把 client 設定餵進 build。

## 為什麼預設關閉

`lib/api/providers.dart` 的 `apiClientProvider` 只有在 `OAuthConfig.isConfigured`(即有設
`TRIPLINE_OAUTH_CLIENT_ID`)時才接上 Bearer 來源;否則完全走 cookie。所以沒設定就是現況,零影響。

## Production client

後端的 OAuth 引擎已齊備(`/api/oauth/authorize`、`/api/oauth/token`、PKCE-S256、refresh、JWKS),
且 API 接受 `Authorization: Bearer`。目前 production 已由 backend migration provision:

- `client_id = tripline-mobile`
- `client_type = public`(無 client_secret;強制 PKCE)
- `redirect_uris = ["http://127.0.0.1:8765"]`(loopback 固定埠;**custom scheme 會被後端拒**)
- `allowed_scopes = openid profile email offline_access`
- `status = active`

> redirect 採 RFC 8252 loopback(`http://127.0.0.1:<port>`)。port 預設 8765,可用
> `TRIPLINE_OAUTH_REDIRECT_PORT` 覆寫,但**必須與註冊的 redirect_uri 完全一致**(後端 exact-match)。

## build/run 時注入

```bash
flutter run \
  --dart-define=TRIPLINE_OAUTH_CLIENT_ID=tripline-mobile \
  --dart-define=TRIPLINE_OAUTH_REDIRECT_PORT=8765
```

設定後:
- `apiClientProvider` 會在「有 OAuth token」時自動帶 `Authorization: Bearer`(且**不送 Origin** →
  後端對 no-Origin Bearer 跳過 CSRF,等於擺脫偽造 Origin 的過渡 hack);access token 過期會用
  refresh token 自動換新(`StoredBearerTokenSource`);沒 token 時仍回退 cookie。
- 觸發登入:呼叫 `ref.read(oauthLoginServiceProvider).login()` — 會起 loopback server、開系統瀏覽器
  授權、收 code、換 token、存進 secure storage。(把它接到登入頁的「用 OAuth 登入」按鈕即可。)

## 已知限制 / 待辦

- **實機 e2e 未自動化**:client 端核心(PKCE、token 交換/刷新、Bearer ApiClient)皆有單元測試,
  但瀏覽器/loopback 編排(`OAuthLoginService`)device 相依，需依本文件手動跑。
- **mobile loopback UX**:iOS 上 loopback redirect 後使用者會看到「可關閉此頁」再手動切回 App(不像
  custom scheme 自動返回)。若要更順,需後端放寬 redirect 政策(custom scheme)或設 https App Link
  關聯檔 — 兩者皆後端網域層級,超出本 repo。
- `/oauth/userinfo` 不收 Bearer(後端僅 cookie)→ 已改成**讀 `id_token` claims** 當身分(`AuthNotifier.build` 在 `isConfigured` 且有 token 時走此路;refresh 沿用舊 id_token)。
- 登入頁的「用 OAuth 登入」按鈕**已接好**(`login-oauth-button`,gated by `oauthEnabledProvider`/`OAuthConfig.isConfigured`);成功後 invalidate authState → router 跳轉。

## 本機 e2e（後端在 ~/Projects/trip-planner)

backend migration 0082 會 provision 一個可用的 public client；若重建本機 DB 後缺資料，可用以下 SQL 補回:
- `client_id = tripline-mobile`、`client_type = public`、`redirect_uris = ["http://127.0.0.1:8765"]`、scopes `openid profile email offline_access`、`status = active`。
  ```bash
  cd ~/Projects/trip-planner
  node_modules/.bin/wrangler d1 execute trip-planner-db --local --env production --command \
    "INSERT INTO client_apps (client_id,client_type,app_name,redirect_uris,allowed_scopes,status) \
     VALUES ('tripline-mobile','public','Tripline Mobile','[\"http://127.0.0.1:8765\"]','[\"openid\",\"profile\",\"email\",\"offline_access\"]','active')"
  ```

跑 e2e:
1. 起**真**後端(functions,非 mock):`cd ~/Projects/trip-planner && npm run dev`(:8788)。
2. 跑 app 指向本機 + 帶 client:
   ```bash
   flutter run \
     --dart-define=TRIPLINE_API_ORIGIN=http://localhost:8788 \
     --dart-define=TRIPLINE_OAUTH_CLIENT_ID=tripline-mobile \
     --dart-define=TRIPLINE_OAUTH_REDIRECT_PORT=8765
   ```
   (Android emulator 用 `http://10.0.2.2:8788`。)
3. 登入頁點「用 OAuth 登入」→ 系統瀏覽器開 authorize → 用本機帳號登入(seed user 如 `lean.lean@gmail.com`;若卡 email 未驗證,於本機 DB 補 `email_verified_at`)→ consent → 自動回 `127.0.0.1:8765` → 換 token → 進 app。之後所有 API 走 Bearer(不再偽造 Origin)。
