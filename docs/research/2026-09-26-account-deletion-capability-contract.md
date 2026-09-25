# #380：帳號刪除能力與 fresh-auth 契約

查核日期：2026-09-26。Flutter 基線 `99abd81fc04030fe8eaa34c61582ab610f1401b9`；後端以合併到 `uat` 的 `7c59a998c7306fed7ea2155435bd966032040459` 為原始碼依據。本票只調查 [#380](https://github.com/raychiutw/trip-planner.flutter/issues/380)，供 [#389](https://github.com/raychiutw/trip-planner.flutter/issues/389) 實作；沒有修改產品、登入或刪除任何帳號，也沒有執行 Flutter 測試。下文的「後端契約」不表示正式環境已部署或端到端驗收。

## 能力矩陣

帳號類型以 `GET /api/account` 的 `hasPassword` 判定：後端查詢同一 user 是否有 `provider='local'` 且非空的 `password_hash`。Google 可連結既有帳號，登入方式與 cookie／Bearer 憑證形式都不能代替這個判斷。[後端 account handler](https://github.com/raychiutw/trip-planner/blob/7c59a998c7306fed7ea2155435bd966032040459/functions/api/account/index.ts)

| 帳號／憑證 | 後端 `uat` SHA 已定義的刪除能力 | 目前 Flutter 基線 | 正式環境實況 |
| --- | --- | --- | --- |
| 有 local 密碼，包含另有 Google identity | Preview `hasPassword=true`；`DELETE /api/account` 必須帶目前 `{password}`，密碼錯誤在抹除前拒絕 | 帳號頁輸入密碼，走 cookie session；成功才清本機狀態 | 正式部署 SHA、實際帳號集合與操作驗收未知 |
| 無 local 密碼、有 Google identity，瀏覽器 cookie | Preview `hasPassword=false`、`reauthProvider='google'`；同一瀏覽器 session 的 Google fresh-auth 建立五分鐘、單次、同 user／用途的 proof，再以 `{confirm:'DELETE'}` 刪除 | 無密碼 guard 阻止送出刪除，轉到外部說明頁 | Google provider 實際可用性、正式部署與端到端驗收未知 |
| 無 local 密碼、有 Google identity，mobile Bearer | 環境配對的 mobile OAuth client 可建立 challenge；同 grant 的 Bearer 查狀態，Google fresh-auth 驗證後以 `{confirm:'DELETE',challengeId}` 刪除 | 發布工作流未設定 OAuth client ID，現有 repository 與畫面也沒有 challenge 流程；不能移除 guard 直接呼叫 | 正式部署、發布 binary、裝置 callback 與真實交易未知 |
| 無 local 密碼、也無 Google identity | Preview 的 `reauthProvider=null`；mobile challenge POST 明確拒絕。沒有已核實的重新驗證方式 | guard 保持阻擋 | 是否存在這種正式帳號未知，#389 不可臆測可自助刪除 |
| Apple／LINE／其他 provider | 本次未找到可用的帳號刪除 fresh-auth 契約 | 無對應流程 | 是否支援及帳號數量未知 |

後端 [actor 選擇](https://github.com/raychiutw/trip-planner/blob/7c59a998c7306fed7ea2155435bd966032040459/functions/api/account/_accountActor.ts) 對 cookie 使用 session，對 Bearer 僅接受當前環境的 mobile client、具 user 與 grant 的 token；兩者不得混用。Flutter [認證 repository](../../lib/api/auth_repository.dart) 現在只解析 preview 的三個欄位，刪除只送 `{password}` 或 `{confirm}`；[帳號頁](../../lib/features/account/account_screen.dart) 遇到 `hasPassword=false` 只開說明頁。[發布工作流](../../.github/workflows/mobile.yml) 沒有 `TRIPLINE_OAUTH_CLIENT_ID` 的 `dart-define`，因此以該工作流原樣建置會走 cookie 模式；這不是已安裝商店 binary 的證據。

## #389 可採用的安全契約

有密碼路徑沿用既有 preview、不可復原影響確認與當次密碼驗證。無密碼且有 Google identity 的網頁 cookie 路徑：同一瀏覽器 session 開啟 `GET /api/oauth/login/google?purpose=account-delete`；Google 驗證需是同一帳號，ID token 的 `auth_time` 在本次嘗試之後且五分鐘內。成功回 `/account?deleteReauth=done`，拒絕／失敗回 `deleteReauth=failed`；`DELETE /api/account` 帶 `{confirm:'DELETE'}` 時，後端消耗同 session／user／用途的單次 proof。過期、重播或不符回 403 `ACCOUNT_DELETE_REAUTH_REQUIRED`，不抹除資料。[後端契約文件](https://github.com/raychiutw/trip-planner/blob/7c59a998c7306fed7ea2155435bd966032040459/docs/api/mobile-oauth-account-delete.md)、[account handler](https://github.com/raychiutw/trip-planner/blob/7c59a998c7306fed7ea2155435bd966032040459/functions/api/account/index.ts)

Flutter 的 Bearer 路徑依相同後端契約：

1. `GET /api/account` 顯示擁有行程與受影響共編者數量，先確認使用者理解永久刪除。
2. 同 grant 的 Bearer 送 `POST /api/account/delete-reauth`，取得 `challengeId`、後端產生的 `authorizeUrl`、`expiresIn:300`；用系統瀏覽器開 URL，不自行拼 Google URL。
3. HTTPS app link 回傳 `challenge_id` 與 `status` 僅作返回訊號。先比對本機待處理 challenge，再以同 grant 的 Bearer 送 `GET /api/account/delete-reauth?challenge_id=...` 查伺服器狀態；`verified` 才能刪除。不同 user／grant／client 回 404。可用同路徑 `DELETE` 取消；拒絕、失敗、取消、過期或已使用都不能當成功，須另開新嘗試。
4. 明確輸入 `DELETE` 後，以同 grant Bearer 送 `DELETE /api/account`，body 為 `{confirm:'DELETE',challengeId}`。後端先保留一次性 challenge，再以單一 D1 batch 抹除帳號；失敗回滾並恢復仍未過期的 proof。只有成功回應後才清本機 cookie／token／快取並安全返回。

上述順序不可由「已登入」、Bearer token、callback URL、Google consent 畫面或 `DELETE` 字串代替 fresh-auth。後端 [challenge endpoint](https://github.com/raychiutw/trip-planner/blob/7c59a998c7306fed7ea2155435bd966032040459/functions/api/account/delete-reauth.ts)、[帳號刪除 handler](https://github.com/raychiutw/trip-planner/blob/7c59a998c7306fed7ea2155435bd966032040459/functions/api/account/index.ts) 與 [抹除 batch](https://github.com/raychiutw/trip-planner/blob/7c59a998c7306fed7ea2155435bd966032040459/functions/api/_erasure.ts) 是具體來源。後端契約已補上舊調查指出的 fresh-auth 與非交易抹除缺口；是否在正式環境運作仍待驗證。#389 須保留無密碼 guard，直到發布與裝置驗證足以證明整條路徑可用。

## 外部刪除說明頁的實際路徑

Flutter [外部連結](../../lib/app/external_links.dart) 以 `url_launcher` 開 `https://trip-planner-dby.pages.dev/privacy#delete-account`，不是 App 內申請表。後端 [PrivacyPage 原始碼](https://github.com/raychiutw/trip-planner/blob/7c59a998c7306fed7ea2155435bd966032040459/src/pages/PrivacyPage.tsx) 的錨點說明「帳號」頁自行刪除；無法登入或已移除 App 時，使用註冊信箱透過 `mailto:lean.lean@gmail.com`、主旨「刪除帳號申請」提出人工申請，頁面宣告七個工作天內完成並回信。這不是表單，也沒有申請編號；本次未寄信，無法驗證送達、人工核身或實際處理時間。頁面「app 內即可自行完成」的概括說法與 Flutter 無密碼 guard 有落差，#389 啟用前不可拿它當無密碼自助刪除已完成的證據。

匿名 `GET` 正式與 UAT `/privacy` 當次皆回 `200 text/html`；正式 `/api/account` 回 `401 application/json`，與需認證一致。SPA 的 HTML 回應沒有 PrivacyPage 內容，且網頁讀取工具無法呈現頁面；目前只能以已釘 SHA 的 source 證明錨點與 mailto 設計，不能聲稱線上畫面及郵件動線完成實測。URL fragment 由瀏覽器處理，不會送到伺服器。

## 部署界線與尚待驗證

[後端 PR #1351](https://github.com/raychiutw/trip-planner/pull/1351) 於 2026-09-25 18:15:07 UTC 合併到 **`uat`**，merge SHA `7c59a998c7306fed7ea2155435bd966032040459`。[Cloudflare check](https://github.com/raychiutw/trip-planner/runs/108194583724) 顯示該 SHA 的 preview 與 `uat.trip-planner-dby.pages.dev` 部署成功；[migration run](https://github.com/raychiutw/trip-planner/actions/runs/36172227242) 記錄 D1 `0096_mobile_oauth_callbacks.sql` 套用成功。後端維護者另確認 PR 尚未合併 `master`／production，沒有已驗證的正式 deployment SHA、fresh-auth 刪除 smoke 或核准上線日；正式密碼與 Google-only 刪除行為均未驗證。這些證據只支持 UAT，**沒有正式 alias 的部署 SHA 或正式 D1 migration 證據**。`GET /api/account` 未登入回 401，也不能讀出正式帳號組成、provider 設定或 fresh-auth 能力。

#389 在宣稱可用前仍需取得：正式部署 SHA 與 D1 狀態、正式 Google provider 能力、受控測試帳號的密碼／Google-only／混合身分交易證據，以及允許、拒絕、過期、重播、跨帳號／grant、失敗回滾的驗證。Mobile 路徑另需 HTTPS app link、iOS／Android OS association、背景與冷啟動、發布 build flags、同 grant token refresh 和真機驗收；無對應 provider 的帳號須先有後端重新驗證契約，否則保留人工申請或阻擋。#380 的調查完成不代表 #389 的產品功能完成。

**#380 狀態：research partial，等待外部正式環境證據。** 目前只能交付已釘版本的 UAT 能力契約及正式環境待驗項目，不能勾選「正式帳號種類、reauth／刪除能力與部署證據」已全部核實。

## 可重現的唯讀查核

```sh
git rev-parse HEAD
gh issue view 380 --repo raychiutw/trip-planner.flutter --json title,body,comments,url
gh pr view 1351 --repo raychiutw/trip-planner --json state,mergedAt,mergeCommit,baseRefName,url
gh api 'repos/raychiutw/trip-planner/contents/docs/api/mobile-oauth-account-delete.md?ref=7c59a998c7306fed7ea2155435bd966032040459' --jq .content | base64 -d
gh api 'repos/raychiutw/trip-planner/commits/7c59a998c7306fed7ea2155435bd966032040459/check-runs' --jq '.check_runs[] | [.name,.conclusion,.output.summary] | @tsv'
gh run view 36172227242 --repo raychiutw/trip-planner --log
curl --silent --show-error --max-time 12 --output /dev/null --write-out '%{http_code} %{content_type}\n' 'https://trip-planner-dby.pages.dev/privacy#delete-account'
curl --silent --show-error --max-time 12 --output /dev/null --write-out '%{http_code} %{content_type}\n' 'https://trip-planner-dby.pages.dev/api/account'
```

以上僅為原始碼、發布記錄與匿名 GET；未使用任何非測試帳號、未啟動 Google OAuth、未送出刪除或申請，也未執行 Flutter analyze／test。
