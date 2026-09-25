# #334：正式 OAuth provider 與 callback 契約核對

查核日期：2026-09-26。Flutter 基線 `db7b37deb5832d3663dc4330aa5b280d3da7d489`；後端 [PR #1351](https://github.com/raychiutw/trip-planner/pull/1351) head `576f594f041d4ddd070ea01e77e6b914d3d8a2bc`，當時為 **open、base `uat`**。以下「後端契約」是該 PR 原始碼與文件，不代表已合併、正式環境已部署或實機可用。本票只交付調查，不變更產品行為；下游 [#335](https://github.com/raychiutw/trip-planner.flutter/issues/335)／[#341](https://github.com/raychiutw/trip-planner.flutter/issues/341) 的功能與驗收不可因本票完成而視為完成。

## 兩種 OAuth 流程

| 流程 | 目前已核實的身分與入口 | 返回對象 |
| --- | --- | --- |
| T02 登入 provider | Tripline 自己的登入方式。Flutter 目前提供帳密登入及以 `TRIPLINE_OAUTH_CLIENT_ID` 編譯開啟的通用「用 OAuth 登入」按鈕；後者把 Tripline 當授權伺服器，Flutter 當 public client。後端 Google 登入入口是 `/api/oauth/login/google`。 | OAuth 授權碼返回 Flutter 註冊的 callback；目前 Flutter 實作是 loopback。provider 顯示名稱及正式可用組合仍須以發布 build 與服務設定核實。 |
| T08 第三方 client consent | 已登入 Tripline 的使用者，為某個 `client_id`、`scope`、`redirect_uri` 同意／拒絕授權。Flutter `/oauth/consent` 畫面顯示 client 名稱、scope 與 callback，向 `/api/oauth/consent` 送出 `allow`／`deny`。 | 經後端 allowlist 驗證後返回**該第三方 client** 的 `redirect_uri`，不一定返回 Flutter。 |

因此 T08 的 consent 不證明 T02 需要「使用 Apple 登入」；目前來源沒有要求新增 Apple 登入 provider。Apple App Site Association 是 iOS Universal Link 關聯，並非 Apple 身分登入。兩條流程共用 OAuth 名詞，身分角色與返回來源不同。

## 後端 PR 定義的環境契約

| 環境 | issuer | public client | exact redirect URI |
| --- | --- | --- | --- |
| 正式 | `https://trip-planner-dby.pages.dev/api/oauth` | `tripline-mobile` | `https://mobile-callback.trip-planner-dby.pages.dev/oauth/callback` |
| UAT | `https://uat.trip-planner-dby.pages.dev/api/oauth` | `tripline-mobile-uat` | `https://mobile-callback.trip-planner-dby.pages.dev/uat/oauth/callback` |
| 本機 | 本機 `/api/oauth` | `tripline-mobile-dev` | `http://127.0.0.1:8765` |

[後端契約文件](https://github.com/raychiutw/trip-planner/blob/576f594f041d4ddd070ea01e77e6b914d3d8a2bc/docs/api/mobile-oauth-account-delete.md)、[環境選擇](https://github.com/raychiutw/trip-planner/blob/576f594f041d4ddd070ea01e77e6b914d3d8a2bc/functions/api/_mobileOAuth.ts)、[migration](https://github.com/raychiutw/trip-planner/blob/576f594f041d4ddd070ea01e77e6b914d3d8a2bc/migrations/0096_mobile_oauth_callbacks.sql) 是此表的來源。環境選擇把 `ENVIRONMENT`、request origin、client ID、redirect URI 綁為一組；不接受跨環境配對。migration 對既有正式 client **追加** HTTPS URI，不移除原有 loopback allowlist；在正式環境，新的 authorize／consent handler 仍會拒絕 `tripline-mobile` 搭配 loopback。資料庫 migration 是否已套用、正式 client 實際狀態須另查部署與 D1 證據。

OAuth code flow 要求 `response_type=code`、PKCE `S256`、可驗證的 `state`、精確註冊的 redirect URI。允許的 scope 為 `openid profile email offline_access`，public client 不帶 secret。code 只能交換一次；交換時用同 issuer 的 `/token`、同 client ID 與 redirect URI。Flutter 不應把 `code`、`state`、`code_verifier`、token、client secret 或含這些值的完整 callback URL 顯示在畫面、記錄到 log／analytics 或當成一般返回位置。callback 若無相符待處理嘗試就拒絕；背景／冷啟動須保留該嘗試並防止重複兌換。[後端契約文件](https://github.com/raychiutw/trip-planner/blob/576f594f041d4ddd070ea01e77e6b914d3d8a2bc/docs/api/mobile-oauth-account-delete.md) 對上述要求有明文；Flutter HTTPS callback 接收與狀態持久化目前尚未實作。

## 允許、拒絕與失敗返回

- **允許**：後端 [authorize handler](https://github.com/raychiutw/trip-planner/blob/576f594f041d4ddd070ea01e77e6b914d3d8a2bc/functions/api/oauth/authorize.ts) 驗證 client／callback／scope，必要時導向 consent；同意後發單次 code，`302` 至註冊 callback，帶 `code` 與原 `state`。
- **拒絕**：後端 [consent handler](https://github.com/raychiutw/trip-planner/blob/576f594f041d4ddd070ea01e77e6b914d3d8a2bc/functions/api/oauth/consent.ts) 先核對 active client 的 exact redirect allowlist，再 `302` 至該 callback，帶 `error=access_denied` 及原 `state`。不符合環境配對或未註冊的 URI 回 `400`，不得轉送到輸入提供的網址。
- **失敗／中止**：已確認可安全導回 client 的 authorize 錯誤可能以 `error`、`error_description`、`state` 回 callback；無安全 redirect 的請求回 `400`。瀏覽器取消或 app 收不到 callback 時保持未登入／原畫面，提供重試；不憑 `code` 或返回 URL 本身推定成功。Flutter 現有 loopback 接收器只接收 state 相符的 request，錯誤拋例外、五分鐘逾時；尚無 HTTPS app link handler 或冷啟動 pending attempt 機制。
- **T08 現有畫面限制**：Flutter `OAuthConsentScreen` 提交後只顯示後端 `Location` 字串，沒有實際返回第三方來源；目前 allow `Location` 是帶有 `state`、`code_challenge` 等參數的 authorize URL，deny `Location` 帶 `error` 與 `state`，故不能把這個顯示當成安全完成。這是 #335／#341 實作與驗收需處理的差距，不在本調查票直接修改。

## Flutter 發布與 URI handler 現況

- [`oauth_config.dart`](../../lib/api/oauth/oauth_config.dart) 的 `clientId` 取自 `TRIPLINE_OAUTH_CLIENT_ID`，預設空值；非空才顯示 OAuth 登入。redirect 固定為 `http://127.0.0.1:<TRIPLINE_OAUTH_REDIRECT_PORT>`，預設 8765；[`oauth_login_service.dart`](../../lib/api/oauth/oauth_login_service.dart) 只以本機 `HttpServer` 收 callback。
- [mobile.yml](../../.github/workflows/mobile.yml) 的 `flutter build ipa`／`flutter build appbundle` 都沒有 `--dart-define=TRIPLINE_OAUTH_CLIENT_ID`。以該工作流**原樣建置**時 OAuth 按鈕關閉，沿用 cookie 登入；這是原始碼結論，並非已檢視商店內現有 binary。
- iOS [Release.entitlements](../../ios/Runner/Release.entitlements)／[DebugProfile.entitlements](../../ios/Runner/DebugProfile.entitlements) 未宣告 `applinks:mobile-callback.trip-planner-dby.pages.dev`；Android [AndroidManifest.xml](../../android/app/src/main/AndroidManifest.xml) 沒有 HTTPS `VIEW`／`BROWSABLE`／`autoVerify` intent filter；Flutter router 只有 `/oauth/consent`，沒有 `/oauth/callback` handler。故目前 release 原始碼不能接住新 HTTPS callback。
- 後端 PR 的 [AASA](https://github.com/raychiutw/trip-planner/blob/576f594f041d4ddd070ea01e77e6b914d3d8a2bc/public/.well-known/apple-app-site-association) 宣告 `8Z6WVFJ574.com.raychiu.tripline` 與正式／UAT 路徑；[assetlinks](https://github.com/raychiutw/trip-planner/blob/576f594f041d4ddd070ea01e77e6b914d3d8a2bc/public/.well-known/assetlinks.json) 宣告 `com.raychiu.tripline` 及 SHA-256 fingerprint。Android 指紋仍需與 Play Console 的 **app-signing** 憑證比對，不能以 upload 憑證代替。

## 驗證證據與未定事項

可重跑的唯讀查核（無登入、授權、token 或資料修改）：

```sh
git rev-parse HEAD
gh issue view 334 --repo raychiutw/trip-planner.flutter --json title,body,labels,url
gh pr view 1351 --repo raychiutw/trip-planner --json headRefOid,headRefName,baseRefName,state,url
gh api 'repos/raychiutw/trip-planner/contents/docs/api/mobile-oauth-account-delete.md?ref=576f594f041d4ddd070ea01e77e6b914d3d8a2bc' --jq .content | base64 -d
rg -n 'TRIPLINE_OAUTH|flutter build ipa|flutter build appbundle' lib/api/oauth .github/workflows/mobile.yml
rg -n 'applinks:|associated-domains|autoVerify|/oauth/callback' ios android lib
curl --silent --show-error --max-time 12 --dump-header - 'https://mobile-callback.trip-planner-dby.pages.dev/.well-known/apple-app-site-association'
curl --silent --show-error --max-time 12 --dump-header - 'https://mobile-callback.trip-planner-dby.pages.dev/.well-known/assetlinks.json'
curl --silent --show-error --max-time 12 --dump-header - 'https://trip-planner-dby.pages.dev/api/oauth/client-info?client_id=tripline-mobile'
curl --silent --show-error --max-time 12 --dump-header - 'https://uat.trip-planner-dby.pages.dev/api/oauth/client-info?client_id=tripline-mobile-uat'
```

本次兩個 association URL 都回 `HTTP/2 200`、`Content-Type: application/json`，沒有 HTTP redirect，body 分別含上述 AASA／assetlinks 資料；只能證明查核當下公開靜態檔可讀，不能證明 issuer 已部署 PR、D1 allowlist 已套用、OS 已認領網域或 app 能處理 callback。`curl` 的回應日期為 2026-09-25 18:05 UTC（台灣時間 2026-09-26 02:05）。另讀取正式 `GET /api/oauth/client-info?client_id=tripline-mobile` 得 `200`，名稱 **Tripline Mobile**；UAT 的 `tripline-mobile-uat` 得 `404 DATA_NOT_FOUND`（client 不存在或未啟用）。這是各環境當下的公開讀取結果，不能推出 redirect allowlist、migration 或完整 OAuth 交易已生效。未驗證正式/UAT OAuth transaction、Google provider 實際可用性、Play app-signing 指紋、Apple／Android 真機冷啟動與背景返回、商店 binary 的 build flags。下游必須以部署 SHA、設定與實機證據補齊；本票不可代替那些驗收。

### 後續查核：2026-09-26 02:22（台灣時間）

- `gh pr view 1351 --repo raychiutw/trip-planner --json state,mergedAt,mergeCommit,headRefOid,baseRefName,url` 顯示 PR 已於 2026-09-25 18:15:07 UTC **合併至 `uat`**，merge commit `7c59a998c7306fed7ea2155435bd966032040459`。上方「open」是較早快照，不代表目前狀態；合併 UAT 也不等於正式環境部署。
- 重新執行上方 UAT `client-info` GET 得 `HTTP/2 200`、`Content-Type: application/json`，`app_name` 為 **Tripline Mobile UAT**（回應日期 2026-09-25 18:22:05 UTC）。上方 `404` 是 18:06:43 UTC 的歷史結果；這次讀取證明 UAT 公開 client-info 在新時間點可用，不證明 authorize／consent／token 完整流程或裝置 callback 已驗收。
- 主代理已直接在 Play Console 的 app-signing 憑證核對 SHA-256 指紋為 `28:06:F8:E5:6F:D8:D5:1A:30:50:F5:40:0D:83:36:A5:11:78:FF:41:9A:9C:B2:1C:27:88:DC:21:E5:4B:39:B5`，與後端 `assetlinks.json` 相同，且不同於 upload 憑證。本分支沒有登入 Play Console 重查；這項證據由主代理直接查核提供。仍需裝置 OS association 與 Flutter URI handler 驗證，亦不能據此宣稱正式 OAuth 已上線。

### #341：同意流程由瀏覽器持有

後端 `POST /api/oauth/consent` 以 `getSessionUser` 讀取瀏覽器 cookie；`allow` 首次回應是導回同一 issuer 的 `/api/oauth/authorize`，由它再核發 code 並導向已註冊的第三方 callback；`deny` 只在驗證 exact redirect allowlist 後導向該 callback，帶 `error=access_denied` 與原 `state`。React `ConsentPage` 使用同一瀏覽器 session 的 HTML form 提交，讓瀏覽器完成後續 302。這兩條路徑的完成狀態屬於瀏覽器與原第三方 client，不是 Flutter 畫面的單次 POST 回應。

Flutter `/oauth/consent` 沒有 app 內呼叫端，也沒有能保留原瀏覽器 session 的入口或接收任意第三方 callback 的 handler。#341 因此移除無法完成交易的原生同意畫面與 POST，保留該路由作安全退路：若連結被 OS 交給 Flutter，只提示返回原瀏覽器重試或返回行程列表，不顯示 query／`Location`，也不開啟使用者提供的 URI。Flutter 退路不宣稱同意或拒絕完成；兩者仍在原瀏覽器流程完成。
