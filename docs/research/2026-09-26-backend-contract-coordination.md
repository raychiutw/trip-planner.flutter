# 後端契約與跨專案依賴核對

日期：2026-09-26。依使用者指示，直接聯絡 `trip-planner` 開發 agent，並交叉核對程式碼與 GitHub Issues。本次只補充查證紀錄，沒有變更後端或新增 Flutter 產品行為。

## 核對版本

- 後端本機 `master`／`origin/master`：`a26590a4cf4a00f6ac991cf783e7b263244aae60`，工作目錄乾淨。
- 後端開發 agent 回覆目前分支為 `feat/1307-reliability-uat`，commit `b749b0062ea5772d87a492500aaf19b61f6105ba`。
- 已用 GitHub 核實 [PR #1346](https://github.com/raychiutw/trip-planner/pull/1346) 的 head 與上述 commit 相同，base 為 `uat`，查證時仍開啟。這不是正式環境部署證據。

## 契約結果

| Flutter 追蹤 | 已核實現況 | 尚缺交付 |
| --- | --- | --- |
| [#380](https://github.com/raychiutw/trip-planner.flutter/issues/380)、[#389](https://github.com/raychiutw/trip-planner.flutter/issues/389) | `DELETE /api/account` 對有密碼帳號驗證密碼；無密碼帳號仍只檢查 `confirm: 'DELETE'`。本批後端分支沒有修改此 handler。 | 與目前帳號及刪除操作綁定、由 server 驗證的近期重新驗證契約，以及部署與測試證據。確認字串不能視為重新驗證。 |
| [#382](https://github.com/raychiutw/trip-planner.flutter/issues/382)、[#390](https://github.com/raychiutw/trip-planner.flutter/issues/390) | `ai-authorization` 的 GET／POST 仍回傳 `authorized`；POST 保存代理操作的 Consent grant，沒有讀取或保存資料告知版本。本批沒有修改此 handler 或 migration。 | 具版本的資料告知與同意主體、保存／回傳／驗證契約，以及正式接收者與部署證據。既有代理授權不能自動視為新版資料同意。 |
| [#334](https://github.com/raychiutw/trip-planner.flutter/issues/334)，下游 [#335](https://github.com/raychiutw/trip-planner.flutter/issues/335)、[#341](https://github.com/raychiutw/trip-planner.flutter/issues/341) | 本批 OAuth consent 在寫入 grant 前新增 `validateAuthorizeRequest`，但未變更 mobile callback migration；開發 agent 沒有提供新的正式 callback 契約或部署證據。 | 正式 active client／redirect allowlist、mobile callback 及返回來源的可驗證契約。沿用前次研究的 source 與正式環境界線。 |

一手程式碼：固定於上述後端 head 的 [account handler](https://github.com/raychiutw/trip-planner/blob/b749b0062ea5772d87a492500aaf19b61f6105ba/functions/api/account/index.ts)、[AI authorization handler](https://github.com/raychiutw/trip-planner/blob/b749b0062ea5772d87a492500aaf19b61f6105ba/functions/api/account/ai-authorization.ts)、[OAuth consent handler](https://github.com/raychiutw/trip-planner/blob/b749b0062ea5772d87a492500aaf19b61f6105ba/functions/api/oauth/consent.ts)。已讀取實際內容，並以 `git diff a26590a..b749b00` 核實前兩個 handler 與 `migrations/` 沒有變更。

## 既有後端票的範圍

- [#1334 帳號結果](https://github.com/raychiutw/trip-planner/issues/1334) 涵蓋 profile、統計、刪除預覽、既有 reauth 與錯誤結果。後端 agent 明確確認它沒有新增無密碼 fresh-auth。
- [#1323 OAuth 同意](https://github.com/raychiutw/trip-planner/issues/1323) 涵蓋 client identity、scopes、允許／拒絕及安全 redirect，並非具版本的 AI 資料同意。
- 兩票的 body 與 comments 均已核對，不能建立「完成這兩票即解除上述 Flutter blocker」的依賴。
- 本次 GitHub Issues 查詢 `fresh-auth`、`consentVersion`、`無密碼` 未找到專門承接票。後端 agent 另查 `passwordless` 與 open callback，也未找到專門交付上述能力的票。這是本次檢索結果，不代表所有歷史命名都已窮盡。

## 驗證界線

後續協調：後端 agent 已回覆收到使用者明確指示，三項缺口將由後端方整理 spec、開票並開發；Flutter 方不重複開票或修改後端，繼續其他工作。待對方同步票號、正式契約與部署證據後，再更新上述依賴。本次尚未取得新票號，不能將此承接承諾視為 API 已完成。

後端 agent 確認本批只有 Cloudflare preview，沒有可提供的正式部署證據。本次另以瀏覽器讀取正式公開 `client-info` 時遇到 `net::ERR_BLOCKED_BY_CLIENT`，沒有取得 JSON；不能據此推論 endpoint 不存在或 client 已停用。

沒有執行登入、授權、刪除、AI 工單或資料庫 mutation，也沒有讀取或傳送 secrets。本文件不宣稱 Flutter 真機驗收、master 整合或商店上傳完成。以上票保留未完成狀態，其餘沒有這些依賴的 Flutter 工作繼續進行。
